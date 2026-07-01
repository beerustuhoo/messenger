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
  final String type;
  final String? name;
  final DateTime updatedAt;
  final bool archived;
  final bool muted;
  final UserSummary otherUser;
  final List<UserSummary> members;
  final LastMessagePreview? lastMessage;

  ChatModel({
    required this.id,
    this.type = 'direct',
    this.name,
    required this.updatedAt,
    required this.otherUser,
    this.members = const [],
    this.archived = false,
    this.muted = false,
    this.lastMessage,
  });

  bool get isGroup => type == 'group';

  String get displayTitle =>
      isGroup ? (name?.trim().isNotEmpty == true ? name!.trim() : 'Group chat') : otherUser.username;

  factory ChatModel.fromJson(Map<String, dynamic> j) {
    final members = (j['members'] as List<dynamic>?)
            ?.map((m) => UserSummary.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList() ??
        [];
    final other = j['otherUser'] != null
        ? UserSummary.fromJson(j['otherUser'] as Map<String, dynamic>)
        : (members.isNotEmpty
            ? members.first
            : UserSummary(id: '', username: j['name'] as String? ?? 'Chat'));
    return ChatModel(
      id: j['id'] as String,
      type: j['type'] as String? ?? 'direct',
      name: j['name'] as String?,
      updatedAt: DateTime.parse(j['updatedAt'] as String),
      archived: j['archived'] as bool? ?? false,
      muted: j['muted'] as bool? ?? false,
      otherUser: other,
      members: members,
      lastMessage: j['lastMessage'] != null
          ? LastMessagePreview.fromJson(j['lastMessage'] as Map<String, dynamic>)
          : null,
    );
  }
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
  final String? senderUsername;
  final String type;
  final String? content;
  final String? mediaUrl;
  final String? mediaMime;
  final String status;
  final bool edited;
  final bool deleted;
  final DateTime createdAt;
  final bool isMine;
  final String? pollId;
  final PollModel? poll;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.senderUsername,
    required this.type,
    this.content,
    this.mediaUrl,
    this.mediaMime,
    required this.status,
    this.edited = false,
    this.deleted = false,
    required this.createdAt,
    required this.isMine,
    this.pollId,
    this.poll,
  });

  factory MessageModel.fromJson(Map<String, dynamic> j) => MessageModel(
        id: j['id'] as String,
        chatId: j['chatId'] as String,
        senderId: j['senderId'] as String,
        senderUsername: j['senderUsername'] as String?,
        type: j['type'] as String,
        content: j['content'] as String?,
        mediaUrl: j['mediaUrl'] as String?,
        mediaMime: j['mediaMime'] as String?,
        status: j['status'] as String? ?? 'sent',
        edited: j['edited'] as bool? ?? false,
        deleted: j['deleted'] as bool? ?? false,
        createdAt: DateTime.parse(j['createdAt'] as String),
        isMine: j['isMine'] as bool? ?? false,
        pollId: j['pollId'] as String?,
        poll: j['poll'] != null ? PollModel.fromJson(j['poll'] as Map<String, dynamic>) : null,
      );

  MessageModel copyWith({
    String? content,
    String? status,
    bool? edited,
    bool? deleted,
    PollModel? poll,
  }) =>
      MessageModel(
        id: id,
        chatId: chatId,
        senderId: senderId,
        senderUsername: senderUsername,
        type: type,
        content: content ?? this.content,
        mediaUrl: mediaUrl,
        mediaMime: mediaMime,
        status: status ?? this.status,
        edited: edited ?? this.edited,
        deleted: deleted ?? this.deleted,
        createdAt: createdAt,
        isMine: isMine,
        pollId: pollId,
        poll: poll ?? this.poll,
      );

  bool get isLocal => id.startsWith('local_');
}

class InviteModel {
  final String id;
  final UserSummary fromUser;
  final DateTime createdAt;
  final String? chatId;
  final String? chatName;

  InviteModel({
    required this.id,
    required this.fromUser,
    required this.createdAt,
    this.chatId,
    this.chatName,
  });

  bool get isGroupInvite => chatId != null;

  factory InviteModel.fromJson(Map<String, dynamic> j) => InviteModel(
        id: j['id'] as String,
        fromUser: UserSummary.fromJson(j['fromUser'] as Map<String, dynamic>),
        createdAt: DateTime.parse(j['createdAt'] as String),
        chatId: j['chatId'] as String?,
        chatName: j['chatName'] as String?,
      );
}

class GroupInviteModel {
  final String id;
  final String chatId;
  final String chatName;
  final UserSummary fromUser;
  final DateTime createdAt;

  GroupInviteModel({
    required this.id,
    required this.chatId,
    required this.chatName,
    required this.fromUser,
    required this.createdAt,
  });

  factory GroupInviteModel.fromJson(Map<String, dynamic> j) => GroupInviteModel(
        id: j['id'] as String,
        chatId: j['chatId'] as String,
        chatName: j['chatName'] as String? ?? 'Group',
        fromUser: UserSummary.fromJson(j['fromUser'] as Map<String, dynamic>),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class PollOptionModel {
  final String id;
  final String text;
  final int votes;
  final List<UserSummary> voters;

  PollOptionModel({
    required this.id,
    required this.text,
    required this.votes,
    this.voters = const [],
  });

  factory PollOptionModel.fromJson(Map<String, dynamic> j) => PollOptionModel(
        id: j['id'] as String,
        text: j['text'] as String,
        votes: j['votes'] as int? ?? 0,
        voters: (j['voters'] as List<dynamic>?)
                ?.map((v) => UserSummary.fromJson(Map<String, dynamic>.from(v as Map)))
                .toList() ??
            [],
      );
}

class PollModel {
  final String id;
  final String messageId;
  final String chatId;
  final String question;
  final bool anonymous;
  final bool multipleChoice;
  final List<PollOptionModel> options;
  final List<String> myVotes;
  final int totalVotes;

  PollModel({
    required this.id,
    required this.messageId,
    required this.chatId,
    required this.question,
    required this.anonymous,
    required this.multipleChoice,
    required this.options,
    this.myVotes = const [],
    this.totalVotes = 0,
  });

  factory PollModel.fromJson(Map<String, dynamic> j) => PollModel(
        id: j['id'] as String,
        messageId: j['messageId'] as String,
        chatId: j['chatId'] as String,
        question: j['question'] as String,
        anonymous: j['anonymous'] as bool? ?? false,
        multipleChoice: j['multipleChoice'] as bool? ?? false,
        options: (j['options'] as List<dynamic>?)
                ?.map((o) => PollOptionModel.fromJson(Map<String, dynamic>.from(o as Map)))
                .toList() ??
            [],
        myVotes: (j['myVotes'] as List<dynamic>?)?.cast<String>() ?? [],
        totalVotes: j['totalVotes'] as int? ?? 0,
      );
}
