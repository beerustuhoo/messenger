import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/socket_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';

enum AppStatus { loading, unauthenticated, authenticated }

class _OutboxItem {
  final String chatId;
  final String type;
  final String? text;
  final List<int>? bytes;
  final String? filename;

  const _OutboxItem({
    required this.chatId,
    required this.type,
    this.text,
    this.bytes,
    this.filename,
  });
}

class AppState extends ChangeNotifier {
  final api = ApiClient();
  final storage = StorageService();
  final socket = SocketService();

  AppStatus status = AppStatus.loading;
  UserModel? user;
  String? errorMessage;
  String? fieldError;
  String? pendingVerificationToken;
  List<ChatModel> chats = [];
  List<ChatModel> archivedChats = [];
  List<InviteModel> pendingInvites = [];
  List<GroupInviteModel> pendingGroupInvites = [];
  final List<String> openChatIds = [];
  List<MessageModel> searchResults = [];
  String? searchQuery;
  String? bannerError;
  final Map<String, List<MessageModel>> messagesByChat = {};
  final Map<String, bool> typingUsers = {};
  final Map<String, _OutboxItem> _outbox = {};
  bool isOnline = true;

  AppState() {
    api.onTokenRefresh = _refreshAccessToken;
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    socket.on('message:new', (data) {
      final msg = MessageModel.fromJson(Map<String, dynamic>.from(data as Map));
      messagesByChat.putIfAbsent(msg.chatId, () => []);
      if (msg.isMine) {
        final stale = messagesByChat[msg.chatId]!
            .where((m) => m.isLocal && m.status != 'failed')
            .map((m) => m.id)
            .toList();
        for (final id in stale) {
          _outbox.remove(id);
          messagesByChat[msg.chatId]!.removeWhere((m) => m.id == id);
        }
      }
      if (!messagesByChat[msg.chatId]!.any((m) => m.id == msg.id)) {
        messagesByChat[msg.chatId]!.add(msg);
      }
      if (!msg.isMine) {
        api.post('/messages/${msg.id}/delivered');
      }
      loadChats();
      notifyListeners();
    });

    socket.on('message:updated', (data) {
      final msg = MessageModel.fromJson(Map<String, dynamic>.from(data as Map));
      _updateMessageInList(msg);
      notifyListeners();
    });

    socket.on('message:deleted', (data) {
      final id = (data as Map)['id'] as String;
      for (final list in messagesByChat.values) {
        final idx = list.indexWhere((m) => m.id == id);
        if (idx >= 0) {
          list[idx] = list[idx].copyWith(deleted: true, content: null);
        }
      }
      notifyListeners();
    });

    socket.on('message:status', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      for (final list in messagesByChat.values) {
        final idx = list.indexWhere((m) => m.id == map['id']);
        if (idx >= 0) {
          list[idx] = list[idx].copyWith(status: map['status'] as String);
        }
      }
      notifyListeners();
    });

    socket.on('typing:start', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      typingUsers['${map['chatId']}:${map['userId']}'] = true;
      notifyListeners();
    });

    socket.on('typing:stop', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      typingUsers.remove('${map['chatId']}:${map['userId']}');
      notifyListeners();
    });

    socket.on('invite:received', (_) {
      loadInvites();
      loadGroupInvites();
      NotificationService.show(
        id: 2,
        title: 'New invitation',
        body: 'You received a chat invitation',
      );
    });

    socket.on('group-invite:received', (_) {
      loadGroupInvites();
      NotificationService.show(
        id: 3,
        title: 'Group invitation',
        body: 'You were invited to a group chat',
      );
    });

    socket.on('poll:updated', (data) {
      final poll = PollModel.fromJson(Map<String, dynamic>.from(data as Map));
      final list = messagesByChat[poll.chatId];
      if (list == null) return;
      final idx = list.indexWhere((m) => m.pollId == poll.id || m.id == poll.messageId);
      if (idx >= 0) {
        list[idx] = list[idx].copyWith(poll: poll);
        notifyListeners();
      }
    });

    socket.on('chat:created', (_) => loadChats());

    socket.on('notification', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      if (map['muted'] == true) return;
      final chatId = map['chatId'] as String?;
      NotificationService.show(
        id: chatId?.hashCode ?? 1,
        title: 'New message',
        body: map['preview'] as String? ?? 'You have a new message',
      );
    });
  }

  Future<void> _onAuthenticated() async {
    await NotificationService.ensurePermission();
  }

  Future<void> onServerUrlChanged() async {
    final token = api.accessToken;
    if (token != null && status == AppStatus.authenticated) {
      socket.disconnect();
      socket.connect(token);
    }
    notifyListeners();
  }

  void _updateMessageInList(MessageModel msg) {
    final list = messagesByChat[msg.chatId];
    if (list == null) return;
    final idx = list.indexWhere((m) => m.id == msg.id);
    if (idx >= 0) list[idx] = msg;
  }

  bool isTypingInChat(String chatId) {
    return typingUsers.keys.any((k) => k.startsWith('$chatId:') && typingUsers[k] == true);
  }

  Future<void> init() async {
    final (access, refresh) = await storage.loadTokens();
    if (access == null || refresh == null) {
      status = AppStatus.unauthenticated;
      notifyListeners();
      return;
    }

    api.setTokens(access: access, refresh: refresh);
    if (await _restoreSession()) {
      status = AppStatus.authenticated;
      socket.connect(api.accessToken ?? access);
      pendingVerificationToken = await storage.loadPendingVerificationToken();
      if (user != null && !user!.emailVerified && pendingVerificationToken == null) {
        await _fetchVerificationToken();
      }
      await _onAuthenticated();
      notifyListeners();
      _loadInitialDataSafely();
      return;
    }

    await _clearSession();
    status = AppStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> _restoreSession() async {
    try {
      final data = await api.get('/auth/me');
      user = UserModel.fromJson(data as Map<String, dynamic>);
      await storage.saveCachedUser(user!);
      return true;
    } on ApiException catch (e) {
      if (e.statusCode != 401) return _restoreFromCache();
      final refreshed = await _performTokenRefresh();
      if (refreshed == null) return false;
      try {
        final data = await api.get('/auth/me');
        user = UserModel.fromJson(data as Map<String, dynamic>);
        await storage.saveCachedUser(user!);
        return true;
      } catch (_) {
        return _restoreFromCache();
      }
    } catch (_) {
      final refreshed = await _performTokenRefresh();
      if (refreshed != null) {
        try {
          final data = await api.get('/auth/me');
          user = UserModel.fromJson(data as Map<String, dynamic>);
          await storage.saveCachedUser(user!);
          return true;
        } catch (_) {}
      }
      return _restoreFromCache();
    }
  }

  Future<bool> _restoreFromCache() async {
    final cached = await storage.loadCachedUser();
    if (cached == null) return false;
    user = cached;
    return true;
  }

  void _loadInitialDataSafely() {
    Future(() async {
      try {
        await Future.wait([loadChats(), loadInvites(), loadGroupInvites()]);
      } catch (_) {}
    });
  }

  Future<String?> _performTokenRefresh() async {
    try {
      final (_, refresh) = await storage.loadTokens();
      if (refresh == null) return null;
      final data = await api.post('/auth/refresh', {'refreshToken': refresh});
      final access = data['accessToken'] as String;
      final newRefresh = data['refreshToken'] as String;
      api.setTokens(access: access, refresh: newRefresh);
      await storage.saveTokens(access, newRefresh);
      if (data['user'] != null) {
        user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
        await storage.saveCachedUser(user!);
      }
      socket.connect(access);
      return access;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _refreshAccessToken() async {
    final access = await _performTokenRefresh();
    if (access == null) {
      await _clearSession();
      status = AppStatus.unauthenticated;
      notifyListeners();
    }
    return access;
  }

  Future<void> _setPendingVerificationToken(String? token) async {
    pendingVerificationToken = token;
    await storage.savePendingVerificationToken(token);
    notifyListeners();
  }

  Future<void> _fetchVerificationToken() async {
    try {
      final data = await api.get('/auth/verification-token');
      if (data is Map<String, dynamic> && data['verificationToken'] != null) {
        await _setPendingVerificationToken(data['verificationToken'] as String);
      }
    } catch (_) {}
  }

  Future<void> _clearSession() async {
    await storage.clearTokens();
    await storage.clearCachedUser();
    await _setPendingVerificationToken(null);
    api.setTokens();
    socket.disconnect();
    user = null;
    chats = [];
    archivedChats = [];
    pendingInvites = [];
    messagesByChat.clear();
    _outbox.clear();
  }

  void clearError() {
    errorMessage = null;
    fieldError = null;
    notifyListeners();
  }

  void setError(String msg) {
    errorMessage = msg;
    notifyListeners();
  }

  Future<bool> register(String email, String password, String username) async {
    try {
      clearError();
      final data = await api.post('/auth/register', {
        'email': email,
        'password': password,
        'username': username,
      });
      await _handleAuthResponse(_expectMap(data, 'register'));
      return true;
    } on ApiException catch (e) {
      fieldError = e.field;
      setError(e.message);
      return false;
    } catch (e) {
      setError('Registration failed: $e');
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      clearError();
      final data = await api.post('/auth/login', {'email': email, 'password': password});
      await _handleAuthResponse(_expectMap(data, 'login'));
      return true;
    } on ApiException catch (e) {
      setError(e.message);
      return false;
    } catch (e) {
      setError('Login failed: $e');
      return false;
    }
  }

  Map<String, dynamic> _expectMap(dynamic data, String action) {
    if (data is Map<String, dynamic>) return data;
    throw ApiException(
      'Invalid server response during $action. On Render, use https://YOUR-SERVICE.onrender.com (not http://).',
    );
  }

  Future<void> _handleAuthResponse(Map<String, dynamic> data) async {
    final access = data['accessToken'] as String?;
    final refresh = data['refreshToken'] as String?;
    if (access == null || refresh == null) {
      throw ApiException('Server did not return session tokens');
    }
    api.setTokens(access: access, refresh: refresh);
    await storage.saveTokens(access, refresh);
    final userJson = data['user'];
    if (userJson is! Map<String, dynamic>) {
      throw ApiException('Server did not return user profile');
    }
    user = UserModel.fromJson(userJson);
    await storage.saveCachedUser(user!);
    if (data['verificationToken'] != null) {
      await _setPendingVerificationToken(data['verificationToken'] as String);
    }
    socket.connect(access);
    status = AppStatus.authenticated;
    notifyListeners();
    try {
      await loadProfile();
    } catch (_) {}
    if (user != null && !user!.emailVerified && pendingVerificationToken == null) {
      await _fetchVerificationToken();
    }
    await _onAuthenticated();
    _loadInitialDataSafely();
  }

  Future<void> logout() async {
    try {
      final (_, refresh) = await storage.loadTokens();
      await api.post('/auth/logout', refresh != null ? {'refreshToken': refresh} : {});
    } catch (_) {}
    await _clearSession();
    status = AppStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> loadProfile() async {
    final data = await api.get('/auth/me');
    user = UserModel.fromJson(data as Map<String, dynamic>);
    await storage.saveCachedUser(user!);
    notifyListeners();
  }

  Future<void> loadChats() async {
    final active = await api.get('/chats') as List;
    final archived = await api.get('/chats?archived=true') as List;
    chats = active.map((e) => ChatModel.fromJson(e as Map<String, dynamic>)).toList();
    archivedChats =
        archived.map((e) => ChatModel.fromJson(e as Map<String, dynamic>)).toList();
    notifyListeners();
  }

  Future<void> loadInvites() async {
    final data = await api.get('/invites/pending') as List;
    pendingInvites =
        data.map((e) => InviteModel.fromJson(e as Map<String, dynamic>)).toList();
    notifyListeners();
  }

  Future<List<UserSummary>> searchUsers(String q) async {
    final data = await api.get('/users/search?q=${Uri.encodeComponent(q)}') as List;
    return data.map((e) => UserSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> sendInvite(String toUserId) async {
    await api.post('/invites/send', {'toUserId': toUserId});
    setError('Invitation sent!');
  }

  Future<void> respondInvite(String id, bool accept) async {
    await api.post('/invites/$id/respond', {'accept': accept});
    await Future.wait([loadInvites(), loadChats()]);
  }

  Future<void> loadMessages(String chatId) async {
    final pending = (messagesByChat[chatId] ?? [])
        .where((m) => m.isLocal && (m.status == 'failed' || m.status == 'sending'))
        .toList();
    final data = await api.get('/messages/$chatId') as List;
    messagesByChat[chatId] =
        data.map((e) => MessageModel.fromJson(e as Map<String, dynamic>)).toList();
    for (final m in pending) {
      if (_outbox.containsKey(m.id)) {
        messagesByChat[chatId]!.add(m);
      }
    }
    messagesByChat[chatId]!.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    socket.joinChat(chatId);
    for (final m in messagesByChat[chatId]!) {
      if (m.isLocal) continue;
      if (!m.isMine && m.status == 'sent') {
        api.post('/messages/${m.id}/delivered');
      }
    }
    notifyListeners();
  }

  String _newLocalId() => 'local_${DateTime.now().microsecondsSinceEpoch}';

  MessageModel _optimisticMessage({
    required String id,
    required String chatId,
    required String type,
    String? content,
    String status = 'sending',
  }) {
    return MessageModel(
      id: id,
      chatId: chatId,
      senderId: user!.id,
      type: type,
      content: content,
      status: status,
      createdAt: DateTime.now(),
      isMine: true,
    );
  }

  void _addOptimistic(MessageModel msg, _OutboxItem item) {
    messagesByChat.putIfAbsent(msg.chatId, () => []).add(msg);
    _outbox[msg.id] = item;
    notifyListeners();
  }

  void _replaceLocalMessage(String chatId, String localId, MessageModel serverMsg) {
    final list = messagesByChat[chatId];
    if (list == null) return;
    final idx = list.indexWhere((m) => m.id == localId);
    if (idx >= 0) {
      list[idx] = serverMsg;
    } else {
      list.add(serverMsg);
    }
    _outbox.remove(localId);
  }

  void _markMessageFailed(String chatId, String localId) {
    final list = messagesByChat[chatId];
    if (list == null) return;
    final idx = list.indexWhere((m) => m.id == localId);
    if (idx >= 0) {
      list[idx] = list[idx].copyWith(status: 'failed');
      notifyListeners();
    }
  }

  void _setMessageSending(String chatId, String localId) {
    final list = messagesByChat[chatId];
    if (list == null) return;
    final idx = list.indexWhere((m) => m.id == localId);
    if (idx >= 0) {
      list[idx] = list[idx].copyWith(status: 'sending');
      notifyListeners();
    }
  }

  Future<void> sendText(String chatId, String text) async {
    final localId = _newLocalId();
    _addOptimistic(
      _optimisticMessage(id: localId, chatId: chatId, type: 'text', content: text),
      _OutboxItem(chatId: chatId, type: 'text', text: text),
    );
    try {
      final data = await api.post('/messages/$chatId/text', {'content': text});
      final msg = MessageModel.fromJson(data as Map<String, dynamic>);
      _replaceLocalMessage(chatId, localId, msg);
      await loadChats();
      notifyListeners();
    } catch (_) {
      _markMessageFailed(chatId, localId);
      rethrow;
    }
  }

  Future<void> sendMedia(String chatId, List<int> bytes, String filename, String type,
      {String? caption}) async {
    final localId = _newLocalId();
    final label = switch (type) {
      'image' => 'Photo',
      'video' => 'Video',
      'audio' => 'Voice message',
      _ => 'Attachment',
    };
    _addOptimistic(
      _optimisticMessage(id: localId, chatId: chatId, type: type, content: label),
      _OutboxItem(chatId: chatId, type: type, bytes: bytes, filename: filename),
    );
    try {
      final uri = Uri.parse('${AppConfig.apiUrl}/messages/$chatId/media');
      final request = http.MultipartRequest('POST', uri);
      final (access, _) = await storage.loadTokens();
      if (access != null) request.headers['Authorization'] = 'Bearer $access';
      request.fields['type'] = type;
      if (caption != null) request.fields['caption'] = caption;
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
      final response = await request.send();
      final body = await http.Response.fromStream(response);
      if (response.statusCode >= 400) {
        throw ApiException(jsonDecode(body.body)['error'] ?? 'Upload failed');
      }
      final msg = MessageModel.fromJson(jsonDecode(body.body) as Map<String, dynamic>);
      _replaceLocalMessage(chatId, localId, msg);
      await loadChats();
      notifyListeners();
    } catch (_) {
      _markMessageFailed(chatId, localId);
      rethrow;
    }
  }

  Future<void> retryMessage(String localId) async {
    final item = _outbox[localId];
    if (item == null) throw ApiException('Cannot retry this message');
    _setMessageSending(item.chatId, localId);
    try {
      switch (item.type) {
        case 'text':
          final data =
              await api.post('/messages/${item.chatId}/text', {'content': item.text});
          _replaceLocalMessage(
            item.chatId,
            localId,
            MessageModel.fromJson(data as Map<String, dynamic>),
          );
        default:
          if (item.bytes == null || item.filename == null) {
            throw ApiException('Missing media data for retry');
          }
          final uri = Uri.parse('${AppConfig.apiUrl}/messages/${item.chatId}/media');
          final request = http.MultipartRequest('POST', uri);
          final (access, _) = await storage.loadTokens();
          if (access != null) request.headers['Authorization'] = 'Bearer $access';
          request.fields['type'] = item.type;
          request.files.add(
            http.MultipartFile.fromBytes('file', item.bytes!, filename: item.filename!),
          );
          final response = await request.send();
          final body = await http.Response.fromStream(response);
          if (response.statusCode >= 400) {
            throw ApiException(jsonDecode(body.body)['error'] ?? 'Upload failed');
          }
          _replaceLocalMessage(
            item.chatId,
            localId,
            MessageModel.fromJson(jsonDecode(body.body) as Map<String, dynamic>),
          );
      }
      await loadChats();
      notifyListeners();
    } catch (_) {
      _markMessageFailed(item.chatId, localId);
      rethrow;
    }
  }

  void removeLocalMessage(String localId) {
    final item = _outbox.remove(localId);
    if (item == null) return;
    final list = messagesByChat[item.chatId];
    list?.removeWhere((m) => m.id == localId);
    notifyListeners();
  }

  Future<void> editMessage(String messageId, String content) async {
    final data = await api.patch('/messages/$messageId', {'content': content});
    _updateMessageInList(MessageModel.fromJson(data as Map<String, dynamic>));
    notifyListeners();
  }

  Future<void> deleteMessage(String messageId) async {
    if (messageId.startsWith('local_')) {
      removeLocalMessage(messageId);
      return;
    }
    await api.delete('/messages/$messageId');
    for (final list in messagesByChat.values) {
      final idx = list.indexWhere((m) => m.id == messageId);
      if (idx >= 0) list[idx] = list[idx].copyWith(deleted: true, content: null);
    }
    notifyListeners();
  }

  Future<void> markRead(String messageId) async {
    await api.post('/messages/$messageId/read');
  }

  Future<void> archiveChat(String chatId, bool archived) async {
    await api.post('/chats/$chatId/archive', {'archived': archived});
    await loadChats();
  }

  Future<void> muteChat(String chatId, bool muted) async {
    await api.post('/chats/$chatId/mute', {'muted': muted});
    await loadChats();
  }

  void openChat(String chatId) {
    if (openChatIds.contains(chatId)) return;
    if (openChatIds.length >= 2) openChatIds.removeAt(0);
    openChatIds.add(chatId);
    loadMessages(chatId);
    notifyListeners();
  }

  void closeChat(String chatId) {
    openChatIds.remove(chatId);
    notifyListeners();
  }

  Future<void> createGroup(String name, List<String> memberIds) async {
    await api.post('/chats/groups', {'name': name, 'memberIds': memberIds});
    await loadChats();
  }

  Future<void> loadGroupInvites() async {
    try {
      final data = await api.get('/group-invites/pending') as List;
      pendingGroupInvites =
          data.map((e) => GroupInviteModel.fromJson(e as Map<String, dynamic>)).toList();
      notifyListeners();
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> sendGroupInvite(String chatId, String toUserId) async {
    await api.post('/group-invites/send', {'chatId': chatId, 'toUserId': toUserId});
  }

  Future<void> respondGroupInvite(String id, bool accept) async {
    await api.post('/group-invites/$id/respond', {'accept': accept});
    await loadGroupInvites();
    await loadChats();
  }

  Future<void> searchMessages(String q, {String? chatId}) async {
    searchQuery = q;
    if (q.trim().length < 2) {
      searchResults = [];
      notifyListeners();
      return;
    }
    var path = '/messages/search?q=${Uri.encodeComponent(q.trim())}';
    if (chatId != null) path += '&chatId=$chatId';
    final data = await api.get(path) as List;
    searchResults = data.map((e) => MessageModel.fromJson(e as Map<String, dynamic>)).toList();
    notifyListeners();
  }

  void clearSearch() {
    searchQuery = null;
    searchResults = [];
    notifyListeners();
  }

  Future<void> createPoll(
    String chatId, {
    required String question,
    required List<String> options,
    bool anonymous = false,
    bool multipleChoice = false,
  }) async {
    final data = await api.post('/messages/$chatId/poll', {
      'question': question,
      'options': options,
      'anonymous': anonymous,
      'multipleChoice': multipleChoice,
    });
    final msg = MessageModel.fromJson(data as Map<String, dynamic>);
    messagesByChat.putIfAbsent(chatId, () => []).add(msg);
    await loadChats();
    notifyListeners();
  }

  Future<void> votePoll(String pollId, String optionId) async {
    final data = await api.post('/polls/$pollId/vote', {'optionId': optionId});
    _applyPollUpdate(PollModel.fromJson(data as Map<String, dynamic>));
  }

  Future<void> retractPollVote(String pollId, {String? optionId}) async {
    final path = optionId != null ? '/polls/$pollId/vote?optionId=$optionId' : '/polls/$pollId/vote';
    final data = await api.delete(path);
    _applyPollUpdate(PollModel.fromJson(data as Map<String, dynamic>));
  }

  void _applyPollUpdate(PollModel poll) {
    final list = messagesByChat[poll.chatId];
    if (list == null) return;
    final idx = list.indexWhere((m) => m.pollId == poll.id);
    if (idx >= 0) list[idx] = list[idx].copyWith(poll: poll);
    notifyListeners();
  }

  void showBannerError(String message) {
    bannerError = message;
    notifyListeners();
  }

  void clearBannerError() {
    bannerError = null;
    notifyListeners();
  }

  void _handleError(Object e) {
    final msg = e is ApiException ? e.message : 'Something went wrong. Please try again.';
    showBannerError(msg);
  }

  ChatModel? chatById(String id) {
    for (final c in [...chats, ...archivedChats]) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> updateProfile({String? username, String? about}) async {
    final data = await api.put('/users/profile', {
      if (username != null) 'username': username,
      if (about != null) 'about': about,
    });
    user = UserModel.fromJson(data as Map<String, dynamic>);
    notifyListeners();
  }

  Future<void> uploadAvatar(List<int> bytes, String filename) async {
    final response = await api.uploadMultipart('/users/avatar', 'avatar', bytes, filename);
    if (response.statusCode >= 400) throw ApiException('Avatar upload failed');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    user = UserModel(
      id: user!.id,
      username: user!.username,
      email: user!.email,
      emailVerified: user!.emailVerified,
      about: user!.about,
      avatarUrl: data['avatarUrl'] as String?,
    );
    notifyListeners();
  }

  String _cleanToken(String token) {
    return token.trim().replaceAll(RegExp(r'\s+'), '').replaceAll('=3D', '');
  }

  Future<void> verifyEmail(String token) async {
    final cleaned = _cleanToken(token);
    if (cleaned.isEmpty) throw ApiException('Please enter the verification token');
    await api.post('/auth/verify-email', {'token': cleaned});
    await _setPendingVerificationToken(null);
    await loadProfile();
  }

  Future<void> verifyEmailNow() async {
    var token = pendingVerificationToken;
    if (token == null || token.isEmpty) {
      await _fetchVerificationToken();
      token = pendingVerificationToken;
    }
    if (token == null || token.isEmpty) {
      throw ApiException('No verification code available. Tap Resend to get a new one.');
    }
    await verifyEmail(token);
  }

  Future<void> resendVerification() async {
    final data = await api.post('/auth/resend-verification', {}) as Map<String, dynamic>;
    if (data['verificationToken'] != null) {
      await _setPendingVerificationToken(data['verificationToken'] as String);
    }
  }

  Future<void> forgotPassword(String email) async {
    await api.post('/auth/forgot-password', {'email': email});
  }

  Future<void> resetPassword(String token, String password) async {
    await api.post('/auth/reset-password', {'token': token, 'password': password});
  }
}
