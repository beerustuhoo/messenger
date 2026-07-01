class UserModel {
  final String id;
  final String username;
  final String? email;
  final bool emailVerified;
  final String about;
  final String? avatarUrl;

  UserModel({
    required this.id,
    required this.username,
    this.email,
    this.emailVerified = false,
    this.about = '',
    this.avatarUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        id: j['id'] as String,
        username: j['username'] as String,
        email: j['email'] as String?,
        emailVerified: j['emailVerified'] as bool? ?? false,
        about: j['about'] as String? ?? '',
        avatarUrl: j['avatarUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'emailVerified': emailVerified,
        'about': about,
        'avatarUrl': avatarUrl,
      };
}

class ChatModel {
  final String id;
  final DateTime updatedAt;
  final bool archived;
  final bool muted;
  final UserSummary otherUser;
  final LastMessagePreview? lastMessage;

  ChatModel({
    required this.id,
    required this.updatedAt,
    required this.otherUser,
    this.archived = false,
    this.muted = false,
    this.lastMessage,
  });

  factory ChatModel.fromJson(Map<String, dynamic> j) => ChatModel(
        id: j['id'] as String,
        updatedAt: DateTime.parse(j['updatedAt'] as String),
        archived: j['archived'] as bool? ?? false,
        muted: j['muted'] as bool? ?? false,
        otherUser: UserSummary.fromJson(j['otherUser'] as Map<String, dynamic>),
        lastMessage: j['lastMessage'] != null
            ? LastMessagePreview.fromJson(j['lastMessage'] as Map<String, dynamic>)
            : null,
      );
}

class UserSummary {
  final String id;
  final String username;
  final String? avatarUrl;

  UserSummary({required this.id, required this.username, this.avatarUrl});

  factory UserSummary.fromJson(Map<String, dynamic> j) => UserSummary(
        id: j['id'] as String,
        username: j['username'] as String,
        avatarUrl: j['avatarUrl'] as String?,
      );
}

class LastMessagePreview {
  final String? preview;
  final String type;
  final DateTime createdAt;
  final bool isMine;

  LastMessagePreview({
    this.preview,
    required this.type,
    required this.createdAt,
    required this.isMine,
  });

  factory LastMessagePreview.fromJson(Map<String, dynamic> j) =>
      LastMessagePreview(
        preview: j['preview'] as String?,
        type: j['type'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        isMine: j['isMine'] as bool? ?? false,
      );
}

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String type;
  final String? content;
  final String? mediaUrl;
  final String? mediaMime;
  final String status;
  final bool edited;
  final bool deleted;
  final DateTime createdAt;
  final bool isMine;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.type,
    this.content,
    this.mediaUrl,
    this.mediaMime,
    required this.status,
    this.edited = false,
    this.deleted = false,
    required this.createdAt,
    required this.isMine,
  });

  factory MessageModel.fromJson(Map<String, dynamic> j) => MessageModel(
        id: j['id'] as String,
        chatId: j['chatId'] as String,
        senderId: j['senderId'] as String,
        type: j['type'] as String,
        content: j['content'] as String?,
        mediaUrl: j['mediaUrl'] as String?,
        mediaMime: j['mediaMime'] as String?,
        status: j['status'] as String? ?? 'sent',
        edited: j['edited'] as bool? ?? false,
        deleted: j['deleted'] as bool? ?? false,
        createdAt: DateTime.parse(j['createdAt'] as String),
        isMine: j['isMine'] as bool? ?? false,
      );

  MessageModel copyWith({String? content, String? status, bool? edited, bool? deleted}) =>
      MessageModel(
        id: id,
        chatId: chatId,
        senderId: senderId,
        type: type,
        content: content ?? this.content,
        mediaUrl: mediaUrl,
        mediaMime: mediaMime,
        status: status ?? this.status,
        edited: edited ?? this.edited,
        deleted: deleted ?? this.deleted,
        createdAt: createdAt,
        isMine: isMine,
      );

  bool get isLocal => id.startsWith('local_');
}

class InviteModel {
  final String id;
  final UserSummary fromUser;
  final DateTime createdAt;

  InviteModel({required this.id, required this.fromUser, required this.createdAt});

  factory InviteModel.fromJson(Map<String, dynamic> j) => InviteModel(
        id: j['id'] as String,
        fromUser: UserSummary.fromJson(j['fromUser'] as Map<String, dynamic>),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}
