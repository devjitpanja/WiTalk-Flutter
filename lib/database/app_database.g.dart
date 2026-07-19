// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
mixin _$ChatDaoMixin on DatabaseAccessor<AppDatabase> {
  $ConversationsTable get conversations => attachedDatabase.conversations;
  $MessagesTable get messages => attachedDatabase.messages;
  $PendingActionsTable get pendingActions => attachedDatabase.pendingActions;
  $SyncStatesTable get syncStates => attachedDatabase.syncStates;
  ChatDaoManager get managers => ChatDaoManager(this);
}

class ChatDaoManager {
  final _$ChatDaoMixin _db;
  ChatDaoManager(this._db);
  $$ConversationsTableTableManager get conversations =>
      $$ConversationsTableTableManager(_db.attachedDatabase, _db.conversations);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db.attachedDatabase, _db.messages);
  $$PendingActionsTableTableManager get pendingActions =>
      $$PendingActionsTableTableManager(
        _db.attachedDatabase,
        _db.pendingActions,
      );
  $$SyncStatesTableTableManager get syncStates =>
      $$SyncStatesTableTableManager(_db.attachedDatabase, _db.syncStates);
}

class $ConversationsTable extends Conversations
    with TableInfo<$ConversationsTable, Conversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('private'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _profilePicMeta = const VerificationMeta(
    'profilePic',
  );
  @override
  late final GeneratedColumn<String> profilePic = GeneratedColumn<String>(
    'profile_pic',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastMessageMeta = const VerificationMeta(
    'lastMessage',
  );
  @override
  late final GeneratedColumn<String> lastMessage = GeneratedColumn<String>(
    'last_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastMessageTypeMeta = const VerificationMeta(
    'lastMessageType',
  );
  @override
  late final GeneratedColumn<String> lastMessageType = GeneratedColumn<String>(
    'last_message_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastMessageSenderIdMeta =
      const VerificationMeta('lastMessageSenderId');
  @override
  late final GeneratedColumn<String> lastMessageSenderId =
      GeneratedColumn<String>(
        'last_message_sender_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastMessageTimeMeta = const VerificationMeta(
    'lastMessageTime',
  );
  @override
  late final GeneratedColumn<String> lastMessageTime = GeneratedColumn<String>(
    'last_message_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastMessageIsReadMeta = const VerificationMeta(
    'lastMessageIsRead',
  );
  @override
  late final GeneratedColumn<bool> lastMessageIsRead = GeneratedColumn<bool>(
    'last_message_is_read',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("last_message_is_read" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastMessageStatusMeta = const VerificationMeta(
    'lastMessageStatus',
  );
  @override
  late final GeneratedColumn<String> lastMessageStatus =
      GeneratedColumn<String>(
        'last_message_status',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _unreadCountMeta = const VerificationMeta(
    'unreadCount',
  );
  @override
  late final GeneratedColumn<int> unreadCount = GeneratedColumn<int>(
    'unread_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isMutedMeta = const VerificationMeta(
    'isMuted',
  );
  @override
  late final GeneratedColumn<bool> isMuted = GeneratedColumn<bool>(
    'is_muted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_muted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _otherUserIdMeta = const VerificationMeta(
    'otherUserId',
  );
  @override
  late final GeneratedColumn<String> otherUserId = GeneratedColumn<String>(
    'other_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _otherUserUsernameMeta = const VerificationMeta(
    'otherUserUsername',
  );
  @override
  late final GeneratedColumn<String> otherUserUsername =
      GeneratedColumn<String>(
        'other_user_username',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _otherUserIsVerifiedMeta =
      const VerificationMeta('otherUserIsVerified');
  @override
  late final GeneratedColumn<bool> otherUserIsVerified = GeneratedColumn<bool>(
    'other_user_is_verified',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("other_user_is_verified" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _otherUserVerificationBadgeMeta =
      const VerificationMeta('otherUserVerificationBadge');
  @override
  late final GeneratedColumn<String> otherUserVerificationBadge =
      GeneratedColumn<String>(
        'other_user_verification_badge',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _initiatorIdMeta = const VerificationMeta(
    'initiatorId',
  );
  @override
  late final GeneratedColumn<String> initiatorId = GeneratedColumn<String>(
    'initiator_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iBlockedThemMeta = const VerificationMeta(
    'iBlockedThem',
  );
  @override
  late final GeneratedColumn<bool> iBlockedThem = GeneratedColumn<bool>(
    'i_blocked_them',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("i_blocked_them" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _theyBlockedMeMeta = const VerificationMeta(
    'theyBlockedMe',
  );
  @override
  late final GeneratedColumn<bool> theyBlockedMe = GeneratedColumn<bool>(
    'they_blocked_me',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("they_blocked_me" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sentMessageCountMeta = const VerificationMeta(
    'sentMessageCount',
  );
  @override
  late final GeneratedColumn<int> sentMessageCount = GeneratedColumn<int>(
    'sent_message_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastReactionEmojiMeta = const VerificationMeta(
    'lastReactionEmoji',
  );
  @override
  late final GeneratedColumn<String> lastReactionEmoji =
      GeneratedColumn<String>(
        'last_reaction_emoji',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastReactionAtMeta = const VerificationMeta(
    'lastReactionAt',
  );
  @override
  late final GeneratedColumn<String> lastReactionAt = GeneratedColumn<String>(
    'last_reaction_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastReactionUserIdMeta =
      const VerificationMeta('lastReactionUserId');
  @override
  late final GeneratedColumn<String> lastReactionUserId =
      GeneratedColumn<String>(
        'last_reaction_user_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastReactionMessageContentMeta =
      const VerificationMeta('lastReactionMessageContent');
  @override
  late final GeneratedColumn<String> lastReactionMessageContent =
      GeneratedColumn<String>(
        'last_reaction_message_content',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('synced'),
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<String> lastSyncedAt = GeneratedColumn<String>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    name,
    profilePic,
    lastMessage,
    lastMessageType,
    lastMessageSenderId,
    lastMessageTime,
    lastMessageIsRead,
    lastMessageStatus,
    unreadCount,
    updatedAt,
    isMuted,
    status,
    otherUserId,
    otherUserUsername,
    otherUserIsVerified,
    otherUserVerificationBadge,
    initiatorId,
    iBlockedThem,
    theyBlockedMe,
    sentMessageCount,
    lastReactionEmoji,
    lastReactionAt,
    lastReactionUserId,
    lastReactionMessageContent,
    syncStatus,
    lastSyncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Conversation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('profile_pic')) {
      context.handle(
        _profilePicMeta,
        profilePic.isAcceptableOrUnknown(data['profile_pic']!, _profilePicMeta),
      );
    }
    if (data.containsKey('last_message')) {
      context.handle(
        _lastMessageMeta,
        lastMessage.isAcceptableOrUnknown(
          data['last_message']!,
          _lastMessageMeta,
        ),
      );
    }
    if (data.containsKey('last_message_type')) {
      context.handle(
        _lastMessageTypeMeta,
        lastMessageType.isAcceptableOrUnknown(
          data['last_message_type']!,
          _lastMessageTypeMeta,
        ),
      );
    }
    if (data.containsKey('last_message_sender_id')) {
      context.handle(
        _lastMessageSenderIdMeta,
        lastMessageSenderId.isAcceptableOrUnknown(
          data['last_message_sender_id']!,
          _lastMessageSenderIdMeta,
        ),
      );
    }
    if (data.containsKey('last_message_time')) {
      context.handle(
        _lastMessageTimeMeta,
        lastMessageTime.isAcceptableOrUnknown(
          data['last_message_time']!,
          _lastMessageTimeMeta,
        ),
      );
    }
    if (data.containsKey('last_message_is_read')) {
      context.handle(
        _lastMessageIsReadMeta,
        lastMessageIsRead.isAcceptableOrUnknown(
          data['last_message_is_read']!,
          _lastMessageIsReadMeta,
        ),
      );
    }
    if (data.containsKey('last_message_status')) {
      context.handle(
        _lastMessageStatusMeta,
        lastMessageStatus.isAcceptableOrUnknown(
          data['last_message_status']!,
          _lastMessageStatusMeta,
        ),
      );
    }
    if (data.containsKey('unread_count')) {
      context.handle(
        _unreadCountMeta,
        unreadCount.isAcceptableOrUnknown(
          data['unread_count']!,
          _unreadCountMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('is_muted')) {
      context.handle(
        _isMutedMeta,
        isMuted.isAcceptableOrUnknown(data['is_muted']!, _isMutedMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('other_user_id')) {
      context.handle(
        _otherUserIdMeta,
        otherUserId.isAcceptableOrUnknown(
          data['other_user_id']!,
          _otherUserIdMeta,
        ),
      );
    }
    if (data.containsKey('other_user_username')) {
      context.handle(
        _otherUserUsernameMeta,
        otherUserUsername.isAcceptableOrUnknown(
          data['other_user_username']!,
          _otherUserUsernameMeta,
        ),
      );
    }
    if (data.containsKey('other_user_is_verified')) {
      context.handle(
        _otherUserIsVerifiedMeta,
        otherUserIsVerified.isAcceptableOrUnknown(
          data['other_user_is_verified']!,
          _otherUserIsVerifiedMeta,
        ),
      );
    }
    if (data.containsKey('other_user_verification_badge')) {
      context.handle(
        _otherUserVerificationBadgeMeta,
        otherUserVerificationBadge.isAcceptableOrUnknown(
          data['other_user_verification_badge']!,
          _otherUserVerificationBadgeMeta,
        ),
      );
    }
    if (data.containsKey('initiator_id')) {
      context.handle(
        _initiatorIdMeta,
        initiatorId.isAcceptableOrUnknown(
          data['initiator_id']!,
          _initiatorIdMeta,
        ),
      );
    }
    if (data.containsKey('i_blocked_them')) {
      context.handle(
        _iBlockedThemMeta,
        iBlockedThem.isAcceptableOrUnknown(
          data['i_blocked_them']!,
          _iBlockedThemMeta,
        ),
      );
    }
    if (data.containsKey('they_blocked_me')) {
      context.handle(
        _theyBlockedMeMeta,
        theyBlockedMe.isAcceptableOrUnknown(
          data['they_blocked_me']!,
          _theyBlockedMeMeta,
        ),
      );
    }
    if (data.containsKey('sent_message_count')) {
      context.handle(
        _sentMessageCountMeta,
        sentMessageCount.isAcceptableOrUnknown(
          data['sent_message_count']!,
          _sentMessageCountMeta,
        ),
      );
    }
    if (data.containsKey('last_reaction_emoji')) {
      context.handle(
        _lastReactionEmojiMeta,
        lastReactionEmoji.isAcceptableOrUnknown(
          data['last_reaction_emoji']!,
          _lastReactionEmojiMeta,
        ),
      );
    }
    if (data.containsKey('last_reaction_at')) {
      context.handle(
        _lastReactionAtMeta,
        lastReactionAt.isAcceptableOrUnknown(
          data['last_reaction_at']!,
          _lastReactionAtMeta,
        ),
      );
    }
    if (data.containsKey('last_reaction_user_id')) {
      context.handle(
        _lastReactionUserIdMeta,
        lastReactionUserId.isAcceptableOrUnknown(
          data['last_reaction_user_id']!,
          _lastReactionUserIdMeta,
        ),
      );
    }
    if (data.containsKey('last_reaction_message_content')) {
      context.handle(
        _lastReactionMessageContentMeta,
        lastReactionMessageContent.isAcceptableOrUnknown(
          data['last_reaction_message_content']!,
          _lastReactionMessageContentMeta,
        ),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Conversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Conversation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      profilePic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_pic'],
      ),
      lastMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_message'],
      ),
      lastMessageType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_message_type'],
      ),
      lastMessageSenderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_message_sender_id'],
      ),
      lastMessageTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_message_time'],
      ),
      lastMessageIsRead: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}last_message_is_read'],
      )!,
      lastMessageStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_message_status'],
      ),
      unreadCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unread_count'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      isMuted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_muted'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      otherUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}other_user_id'],
      ),
      otherUserUsername: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}other_user_username'],
      ),
      otherUserIsVerified: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}other_user_is_verified'],
      )!,
      otherUserVerificationBadge: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}other_user_verification_badge'],
      ),
      initiatorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}initiator_id'],
      ),
      iBlockedThem: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}i_blocked_them'],
      )!,
      theyBlockedMe: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}they_blocked_me'],
      )!,
      sentMessageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sent_message_count'],
      )!,
      lastReactionEmoji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_reaction_emoji'],
      ),
      lastReactionAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_reaction_at'],
      ),
      lastReactionUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_reaction_user_id'],
      ),
      lastReactionMessageContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_reaction_message_content'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_synced_at'],
      ),
    );
  }

  @override
  $ConversationsTable createAlias(String alias) {
    return $ConversationsTable(attachedDatabase, alias);
  }
}

class Conversation extends DataClass implements Insertable<Conversation> {
  final String id;
  final String type;
  final String name;
  final String? profilePic;
  final String? lastMessage;
  final String? lastMessageType;
  final String? lastMessageSenderId;
  final String? lastMessageTime;
  final bool lastMessageIsRead;
  final String? lastMessageStatus;
  final int unreadCount;
  final int updatedAt;
  final bool isMuted;
  final String status;
  final String? otherUserId;
  final String? otherUserUsername;
  final bool otherUserIsVerified;
  final String? otherUserVerificationBadge;
  final String? initiatorId;
  final bool iBlockedThem;
  final bool theyBlockedMe;
  final int sentMessageCount;
  final String? lastReactionEmoji;
  final String? lastReactionAt;
  final String? lastReactionUserId;
  final String? lastReactionMessageContent;
  final String syncStatus;
  final String? lastSyncedAt;
  const Conversation({
    required this.id,
    required this.type,
    required this.name,
    this.profilePic,
    this.lastMessage,
    this.lastMessageType,
    this.lastMessageSenderId,
    this.lastMessageTime,
    required this.lastMessageIsRead,
    this.lastMessageStatus,
    required this.unreadCount,
    required this.updatedAt,
    required this.isMuted,
    required this.status,
    this.otherUserId,
    this.otherUserUsername,
    required this.otherUserIsVerified,
    this.otherUserVerificationBadge,
    this.initiatorId,
    required this.iBlockedThem,
    required this.theyBlockedMe,
    required this.sentMessageCount,
    this.lastReactionEmoji,
    this.lastReactionAt,
    this.lastReactionUserId,
    this.lastReactionMessageContent,
    required this.syncStatus,
    this.lastSyncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || profilePic != null) {
      map['profile_pic'] = Variable<String>(profilePic);
    }
    if (!nullToAbsent || lastMessage != null) {
      map['last_message'] = Variable<String>(lastMessage);
    }
    if (!nullToAbsent || lastMessageType != null) {
      map['last_message_type'] = Variable<String>(lastMessageType);
    }
    if (!nullToAbsent || lastMessageSenderId != null) {
      map['last_message_sender_id'] = Variable<String>(lastMessageSenderId);
    }
    if (!nullToAbsent || lastMessageTime != null) {
      map['last_message_time'] = Variable<String>(lastMessageTime);
    }
    map['last_message_is_read'] = Variable<bool>(lastMessageIsRead);
    if (!nullToAbsent || lastMessageStatus != null) {
      map['last_message_status'] = Variable<String>(lastMessageStatus);
    }
    map['unread_count'] = Variable<int>(unreadCount);
    map['updated_at'] = Variable<int>(updatedAt);
    map['is_muted'] = Variable<bool>(isMuted);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || otherUserId != null) {
      map['other_user_id'] = Variable<String>(otherUserId);
    }
    if (!nullToAbsent || otherUserUsername != null) {
      map['other_user_username'] = Variable<String>(otherUserUsername);
    }
    map['other_user_is_verified'] = Variable<bool>(otherUserIsVerified);
    if (!nullToAbsent || otherUserVerificationBadge != null) {
      map['other_user_verification_badge'] = Variable<String>(
        otherUserVerificationBadge,
      );
    }
    if (!nullToAbsent || initiatorId != null) {
      map['initiator_id'] = Variable<String>(initiatorId);
    }
    map['i_blocked_them'] = Variable<bool>(iBlockedThem);
    map['they_blocked_me'] = Variable<bool>(theyBlockedMe);
    map['sent_message_count'] = Variable<int>(sentMessageCount);
    if (!nullToAbsent || lastReactionEmoji != null) {
      map['last_reaction_emoji'] = Variable<String>(lastReactionEmoji);
    }
    if (!nullToAbsent || lastReactionAt != null) {
      map['last_reaction_at'] = Variable<String>(lastReactionAt);
    }
    if (!nullToAbsent || lastReactionUserId != null) {
      map['last_reaction_user_id'] = Variable<String>(lastReactionUserId);
    }
    if (!nullToAbsent || lastReactionMessageContent != null) {
      map['last_reaction_message_content'] = Variable<String>(
        lastReactionMessageContent,
      );
    }
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<String>(lastSyncedAt);
    }
    return map;
  }

  ConversationsCompanion toCompanion(bool nullToAbsent) {
    return ConversationsCompanion(
      id: Value(id),
      type: Value(type),
      name: Value(name),
      profilePic: profilePic == null && nullToAbsent
          ? const Value.absent()
          : Value(profilePic),
      lastMessage: lastMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessage),
      lastMessageType: lastMessageType == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageType),
      lastMessageSenderId: lastMessageSenderId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageSenderId),
      lastMessageTime: lastMessageTime == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageTime),
      lastMessageIsRead: Value(lastMessageIsRead),
      lastMessageStatus: lastMessageStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageStatus),
      unreadCount: Value(unreadCount),
      updatedAt: Value(updatedAt),
      isMuted: Value(isMuted),
      status: Value(status),
      otherUserId: otherUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(otherUserId),
      otherUserUsername: otherUserUsername == null && nullToAbsent
          ? const Value.absent()
          : Value(otherUserUsername),
      otherUserIsVerified: Value(otherUserIsVerified),
      otherUserVerificationBadge:
          otherUserVerificationBadge == null && nullToAbsent
          ? const Value.absent()
          : Value(otherUserVerificationBadge),
      initiatorId: initiatorId == null && nullToAbsent
          ? const Value.absent()
          : Value(initiatorId),
      iBlockedThem: Value(iBlockedThem),
      theyBlockedMe: Value(theyBlockedMe),
      sentMessageCount: Value(sentMessageCount),
      lastReactionEmoji: lastReactionEmoji == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReactionEmoji),
      lastReactionAt: lastReactionAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReactionAt),
      lastReactionUserId: lastReactionUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReactionUserId),
      lastReactionMessageContent:
          lastReactionMessageContent == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReactionMessageContent),
      syncStatus: Value(syncStatus),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
    );
  }

  factory Conversation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Conversation(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      name: serializer.fromJson<String>(json['name']),
      profilePic: serializer.fromJson<String?>(json['profilePic']),
      lastMessage: serializer.fromJson<String?>(json['lastMessage']),
      lastMessageType: serializer.fromJson<String?>(json['lastMessageType']),
      lastMessageSenderId: serializer.fromJson<String?>(
        json['lastMessageSenderId'],
      ),
      lastMessageTime: serializer.fromJson<String?>(json['lastMessageTime']),
      lastMessageIsRead: serializer.fromJson<bool>(json['lastMessageIsRead']),
      lastMessageStatus: serializer.fromJson<String?>(
        json['lastMessageStatus'],
      ),
      unreadCount: serializer.fromJson<int>(json['unreadCount']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      isMuted: serializer.fromJson<bool>(json['isMuted']),
      status: serializer.fromJson<String>(json['status']),
      otherUserId: serializer.fromJson<String?>(json['otherUserId']),
      otherUserUsername: serializer.fromJson<String?>(
        json['otherUserUsername'],
      ),
      otherUserIsVerified: serializer.fromJson<bool>(
        json['otherUserIsVerified'],
      ),
      otherUserVerificationBadge: serializer.fromJson<String?>(
        json['otherUserVerificationBadge'],
      ),
      initiatorId: serializer.fromJson<String?>(json['initiatorId']),
      iBlockedThem: serializer.fromJson<bool>(json['iBlockedThem']),
      theyBlockedMe: serializer.fromJson<bool>(json['theyBlockedMe']),
      sentMessageCount: serializer.fromJson<int>(json['sentMessageCount']),
      lastReactionEmoji: serializer.fromJson<String?>(
        json['lastReactionEmoji'],
      ),
      lastReactionAt: serializer.fromJson<String?>(json['lastReactionAt']),
      lastReactionUserId: serializer.fromJson<String?>(
        json['lastReactionUserId'],
      ),
      lastReactionMessageContent: serializer.fromJson<String?>(
        json['lastReactionMessageContent'],
      ),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      lastSyncedAt: serializer.fromJson<String?>(json['lastSyncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'name': serializer.toJson<String>(name),
      'profilePic': serializer.toJson<String?>(profilePic),
      'lastMessage': serializer.toJson<String?>(lastMessage),
      'lastMessageType': serializer.toJson<String?>(lastMessageType),
      'lastMessageSenderId': serializer.toJson<String?>(lastMessageSenderId),
      'lastMessageTime': serializer.toJson<String?>(lastMessageTime),
      'lastMessageIsRead': serializer.toJson<bool>(lastMessageIsRead),
      'lastMessageStatus': serializer.toJson<String?>(lastMessageStatus),
      'unreadCount': serializer.toJson<int>(unreadCount),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'isMuted': serializer.toJson<bool>(isMuted),
      'status': serializer.toJson<String>(status),
      'otherUserId': serializer.toJson<String?>(otherUserId),
      'otherUserUsername': serializer.toJson<String?>(otherUserUsername),
      'otherUserIsVerified': serializer.toJson<bool>(otherUserIsVerified),
      'otherUserVerificationBadge': serializer.toJson<String?>(
        otherUserVerificationBadge,
      ),
      'initiatorId': serializer.toJson<String?>(initiatorId),
      'iBlockedThem': serializer.toJson<bool>(iBlockedThem),
      'theyBlockedMe': serializer.toJson<bool>(theyBlockedMe),
      'sentMessageCount': serializer.toJson<int>(sentMessageCount),
      'lastReactionEmoji': serializer.toJson<String?>(lastReactionEmoji),
      'lastReactionAt': serializer.toJson<String?>(lastReactionAt),
      'lastReactionUserId': serializer.toJson<String?>(lastReactionUserId),
      'lastReactionMessageContent': serializer.toJson<String?>(
        lastReactionMessageContent,
      ),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'lastSyncedAt': serializer.toJson<String?>(lastSyncedAt),
    };
  }

  Conversation copyWith({
    String? id,
    String? type,
    String? name,
    Value<String?> profilePic = const Value.absent(),
    Value<String?> lastMessage = const Value.absent(),
    Value<String?> lastMessageType = const Value.absent(),
    Value<String?> lastMessageSenderId = const Value.absent(),
    Value<String?> lastMessageTime = const Value.absent(),
    bool? lastMessageIsRead,
    Value<String?> lastMessageStatus = const Value.absent(),
    int? unreadCount,
    int? updatedAt,
    bool? isMuted,
    String? status,
    Value<String?> otherUserId = const Value.absent(),
    Value<String?> otherUserUsername = const Value.absent(),
    bool? otherUserIsVerified,
    Value<String?> otherUserVerificationBadge = const Value.absent(),
    Value<String?> initiatorId = const Value.absent(),
    bool? iBlockedThem,
    bool? theyBlockedMe,
    int? sentMessageCount,
    Value<String?> lastReactionEmoji = const Value.absent(),
    Value<String?> lastReactionAt = const Value.absent(),
    Value<String?> lastReactionUserId = const Value.absent(),
    Value<String?> lastReactionMessageContent = const Value.absent(),
    String? syncStatus,
    Value<String?> lastSyncedAt = const Value.absent(),
  }) => Conversation(
    id: id ?? this.id,
    type: type ?? this.type,
    name: name ?? this.name,
    profilePic: profilePic.present ? profilePic.value : this.profilePic,
    lastMessage: lastMessage.present ? lastMessage.value : this.lastMessage,
    lastMessageType: lastMessageType.present
        ? lastMessageType.value
        : this.lastMessageType,
    lastMessageSenderId: lastMessageSenderId.present
        ? lastMessageSenderId.value
        : this.lastMessageSenderId,
    lastMessageTime: lastMessageTime.present
        ? lastMessageTime.value
        : this.lastMessageTime,
    lastMessageIsRead: lastMessageIsRead ?? this.lastMessageIsRead,
    lastMessageStatus: lastMessageStatus.present
        ? lastMessageStatus.value
        : this.lastMessageStatus,
    unreadCount: unreadCount ?? this.unreadCount,
    updatedAt: updatedAt ?? this.updatedAt,
    isMuted: isMuted ?? this.isMuted,
    status: status ?? this.status,
    otherUserId: otherUserId.present ? otherUserId.value : this.otherUserId,
    otherUserUsername: otherUserUsername.present
        ? otherUserUsername.value
        : this.otherUserUsername,
    otherUserIsVerified: otherUserIsVerified ?? this.otherUserIsVerified,
    otherUserVerificationBadge: otherUserVerificationBadge.present
        ? otherUserVerificationBadge.value
        : this.otherUserVerificationBadge,
    initiatorId: initiatorId.present ? initiatorId.value : this.initiatorId,
    iBlockedThem: iBlockedThem ?? this.iBlockedThem,
    theyBlockedMe: theyBlockedMe ?? this.theyBlockedMe,
    sentMessageCount: sentMessageCount ?? this.sentMessageCount,
    lastReactionEmoji: lastReactionEmoji.present
        ? lastReactionEmoji.value
        : this.lastReactionEmoji,
    lastReactionAt: lastReactionAt.present
        ? lastReactionAt.value
        : this.lastReactionAt,
    lastReactionUserId: lastReactionUserId.present
        ? lastReactionUserId.value
        : this.lastReactionUserId,
    lastReactionMessageContent: lastReactionMessageContent.present
        ? lastReactionMessageContent.value
        : this.lastReactionMessageContent,
    syncStatus: syncStatus ?? this.syncStatus,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
  );
  Conversation copyWithCompanion(ConversationsCompanion data) {
    return Conversation(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      name: data.name.present ? data.name.value : this.name,
      profilePic: data.profilePic.present
          ? data.profilePic.value
          : this.profilePic,
      lastMessage: data.lastMessage.present
          ? data.lastMessage.value
          : this.lastMessage,
      lastMessageType: data.lastMessageType.present
          ? data.lastMessageType.value
          : this.lastMessageType,
      lastMessageSenderId: data.lastMessageSenderId.present
          ? data.lastMessageSenderId.value
          : this.lastMessageSenderId,
      lastMessageTime: data.lastMessageTime.present
          ? data.lastMessageTime.value
          : this.lastMessageTime,
      lastMessageIsRead: data.lastMessageIsRead.present
          ? data.lastMessageIsRead.value
          : this.lastMessageIsRead,
      lastMessageStatus: data.lastMessageStatus.present
          ? data.lastMessageStatus.value
          : this.lastMessageStatus,
      unreadCount: data.unreadCount.present
          ? data.unreadCount.value
          : this.unreadCount,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isMuted: data.isMuted.present ? data.isMuted.value : this.isMuted,
      status: data.status.present ? data.status.value : this.status,
      otherUserId: data.otherUserId.present
          ? data.otherUserId.value
          : this.otherUserId,
      otherUserUsername: data.otherUserUsername.present
          ? data.otherUserUsername.value
          : this.otherUserUsername,
      otherUserIsVerified: data.otherUserIsVerified.present
          ? data.otherUserIsVerified.value
          : this.otherUserIsVerified,
      otherUserVerificationBadge: data.otherUserVerificationBadge.present
          ? data.otherUserVerificationBadge.value
          : this.otherUserVerificationBadge,
      initiatorId: data.initiatorId.present
          ? data.initiatorId.value
          : this.initiatorId,
      iBlockedThem: data.iBlockedThem.present
          ? data.iBlockedThem.value
          : this.iBlockedThem,
      theyBlockedMe: data.theyBlockedMe.present
          ? data.theyBlockedMe.value
          : this.theyBlockedMe,
      sentMessageCount: data.sentMessageCount.present
          ? data.sentMessageCount.value
          : this.sentMessageCount,
      lastReactionEmoji: data.lastReactionEmoji.present
          ? data.lastReactionEmoji.value
          : this.lastReactionEmoji,
      lastReactionAt: data.lastReactionAt.present
          ? data.lastReactionAt.value
          : this.lastReactionAt,
      lastReactionUserId: data.lastReactionUserId.present
          ? data.lastReactionUserId.value
          : this.lastReactionUserId,
      lastReactionMessageContent: data.lastReactionMessageContent.present
          ? data.lastReactionMessageContent.value
          : this.lastReactionMessageContent,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Conversation(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('profilePic: $profilePic, ')
          ..write('lastMessage: $lastMessage, ')
          ..write('lastMessageType: $lastMessageType, ')
          ..write('lastMessageSenderId: $lastMessageSenderId, ')
          ..write('lastMessageTime: $lastMessageTime, ')
          ..write('lastMessageIsRead: $lastMessageIsRead, ')
          ..write('lastMessageStatus: $lastMessageStatus, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isMuted: $isMuted, ')
          ..write('status: $status, ')
          ..write('otherUserId: $otherUserId, ')
          ..write('otherUserUsername: $otherUserUsername, ')
          ..write('otherUserIsVerified: $otherUserIsVerified, ')
          ..write('otherUserVerificationBadge: $otherUserVerificationBadge, ')
          ..write('initiatorId: $initiatorId, ')
          ..write('iBlockedThem: $iBlockedThem, ')
          ..write('theyBlockedMe: $theyBlockedMe, ')
          ..write('sentMessageCount: $sentMessageCount, ')
          ..write('lastReactionEmoji: $lastReactionEmoji, ')
          ..write('lastReactionAt: $lastReactionAt, ')
          ..write('lastReactionUserId: $lastReactionUserId, ')
          ..write('lastReactionMessageContent: $lastReactionMessageContent, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    type,
    name,
    profilePic,
    lastMessage,
    lastMessageType,
    lastMessageSenderId,
    lastMessageTime,
    lastMessageIsRead,
    lastMessageStatus,
    unreadCount,
    updatedAt,
    isMuted,
    status,
    otherUserId,
    otherUserUsername,
    otherUserIsVerified,
    otherUserVerificationBadge,
    initiatorId,
    iBlockedThem,
    theyBlockedMe,
    sentMessageCount,
    lastReactionEmoji,
    lastReactionAt,
    lastReactionUserId,
    lastReactionMessageContent,
    syncStatus,
    lastSyncedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Conversation &&
          other.id == this.id &&
          other.type == this.type &&
          other.name == this.name &&
          other.profilePic == this.profilePic &&
          other.lastMessage == this.lastMessage &&
          other.lastMessageType == this.lastMessageType &&
          other.lastMessageSenderId == this.lastMessageSenderId &&
          other.lastMessageTime == this.lastMessageTime &&
          other.lastMessageIsRead == this.lastMessageIsRead &&
          other.lastMessageStatus == this.lastMessageStatus &&
          other.unreadCount == this.unreadCount &&
          other.updatedAt == this.updatedAt &&
          other.isMuted == this.isMuted &&
          other.status == this.status &&
          other.otherUserId == this.otherUserId &&
          other.otherUserUsername == this.otherUserUsername &&
          other.otherUserIsVerified == this.otherUserIsVerified &&
          other.otherUserVerificationBadge == this.otherUserVerificationBadge &&
          other.initiatorId == this.initiatorId &&
          other.iBlockedThem == this.iBlockedThem &&
          other.theyBlockedMe == this.theyBlockedMe &&
          other.sentMessageCount == this.sentMessageCount &&
          other.lastReactionEmoji == this.lastReactionEmoji &&
          other.lastReactionAt == this.lastReactionAt &&
          other.lastReactionUserId == this.lastReactionUserId &&
          other.lastReactionMessageContent == this.lastReactionMessageContent &&
          other.syncStatus == this.syncStatus &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class ConversationsCompanion extends UpdateCompanion<Conversation> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> name;
  final Value<String?> profilePic;
  final Value<String?> lastMessage;
  final Value<String?> lastMessageType;
  final Value<String?> lastMessageSenderId;
  final Value<String?> lastMessageTime;
  final Value<bool> lastMessageIsRead;
  final Value<String?> lastMessageStatus;
  final Value<int> unreadCount;
  final Value<int> updatedAt;
  final Value<bool> isMuted;
  final Value<String> status;
  final Value<String?> otherUserId;
  final Value<String?> otherUserUsername;
  final Value<bool> otherUserIsVerified;
  final Value<String?> otherUserVerificationBadge;
  final Value<String?> initiatorId;
  final Value<bool> iBlockedThem;
  final Value<bool> theyBlockedMe;
  final Value<int> sentMessageCount;
  final Value<String?> lastReactionEmoji;
  final Value<String?> lastReactionAt;
  final Value<String?> lastReactionUserId;
  final Value<String?> lastReactionMessageContent;
  final Value<String> syncStatus;
  final Value<String?> lastSyncedAt;
  final Value<int> rowid;
  const ConversationsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.name = const Value.absent(),
    this.profilePic = const Value.absent(),
    this.lastMessage = const Value.absent(),
    this.lastMessageType = const Value.absent(),
    this.lastMessageSenderId = const Value.absent(),
    this.lastMessageTime = const Value.absent(),
    this.lastMessageIsRead = const Value.absent(),
    this.lastMessageStatus = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isMuted = const Value.absent(),
    this.status = const Value.absent(),
    this.otherUserId = const Value.absent(),
    this.otherUserUsername = const Value.absent(),
    this.otherUserIsVerified = const Value.absent(),
    this.otherUserVerificationBadge = const Value.absent(),
    this.initiatorId = const Value.absent(),
    this.iBlockedThem = const Value.absent(),
    this.theyBlockedMe = const Value.absent(),
    this.sentMessageCount = const Value.absent(),
    this.lastReactionEmoji = const Value.absent(),
    this.lastReactionAt = const Value.absent(),
    this.lastReactionUserId = const Value.absent(),
    this.lastReactionMessageContent = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationsCompanion.insert({
    required String id,
    this.type = const Value.absent(),
    this.name = const Value.absent(),
    this.profilePic = const Value.absent(),
    this.lastMessage = const Value.absent(),
    this.lastMessageType = const Value.absent(),
    this.lastMessageSenderId = const Value.absent(),
    this.lastMessageTime = const Value.absent(),
    this.lastMessageIsRead = const Value.absent(),
    this.lastMessageStatus = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isMuted = const Value.absent(),
    this.status = const Value.absent(),
    this.otherUserId = const Value.absent(),
    this.otherUserUsername = const Value.absent(),
    this.otherUserIsVerified = const Value.absent(),
    this.otherUserVerificationBadge = const Value.absent(),
    this.initiatorId = const Value.absent(),
    this.iBlockedThem = const Value.absent(),
    this.theyBlockedMe = const Value.absent(),
    this.sentMessageCount = const Value.absent(),
    this.lastReactionEmoji = const Value.absent(),
    this.lastReactionAt = const Value.absent(),
    this.lastReactionUserId = const Value.absent(),
    this.lastReactionMessageContent = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<Conversation> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? name,
    Expression<String>? profilePic,
    Expression<String>? lastMessage,
    Expression<String>? lastMessageType,
    Expression<String>? lastMessageSenderId,
    Expression<String>? lastMessageTime,
    Expression<bool>? lastMessageIsRead,
    Expression<String>? lastMessageStatus,
    Expression<int>? unreadCount,
    Expression<int>? updatedAt,
    Expression<bool>? isMuted,
    Expression<String>? status,
    Expression<String>? otherUserId,
    Expression<String>? otherUserUsername,
    Expression<bool>? otherUserIsVerified,
    Expression<String>? otherUserVerificationBadge,
    Expression<String>? initiatorId,
    Expression<bool>? iBlockedThem,
    Expression<bool>? theyBlockedMe,
    Expression<int>? sentMessageCount,
    Expression<String>? lastReactionEmoji,
    Expression<String>? lastReactionAt,
    Expression<String>? lastReactionUserId,
    Expression<String>? lastReactionMessageContent,
    Expression<String>? syncStatus,
    Expression<String>? lastSyncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (name != null) 'name': name,
      if (profilePic != null) 'profile_pic': profilePic,
      if (lastMessage != null) 'last_message': lastMessage,
      if (lastMessageType != null) 'last_message_type': lastMessageType,
      if (lastMessageSenderId != null)
        'last_message_sender_id': lastMessageSenderId,
      if (lastMessageTime != null) 'last_message_time': lastMessageTime,
      if (lastMessageIsRead != null) 'last_message_is_read': lastMessageIsRead,
      if (lastMessageStatus != null) 'last_message_status': lastMessageStatus,
      if (unreadCount != null) 'unread_count': unreadCount,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isMuted != null) 'is_muted': isMuted,
      if (status != null) 'status': status,
      if (otherUserId != null) 'other_user_id': otherUserId,
      if (otherUserUsername != null) 'other_user_username': otherUserUsername,
      if (otherUserIsVerified != null)
        'other_user_is_verified': otherUserIsVerified,
      if (otherUserVerificationBadge != null)
        'other_user_verification_badge': otherUserVerificationBadge,
      if (initiatorId != null) 'initiator_id': initiatorId,
      if (iBlockedThem != null) 'i_blocked_them': iBlockedThem,
      if (theyBlockedMe != null) 'they_blocked_me': theyBlockedMe,
      if (sentMessageCount != null) 'sent_message_count': sentMessageCount,
      if (lastReactionEmoji != null) 'last_reaction_emoji': lastReactionEmoji,
      if (lastReactionAt != null) 'last_reaction_at': lastReactionAt,
      if (lastReactionUserId != null)
        'last_reaction_user_id': lastReactionUserId,
      if (lastReactionMessageContent != null)
        'last_reaction_message_content': lastReactionMessageContent,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationsCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String>? name,
    Value<String?>? profilePic,
    Value<String?>? lastMessage,
    Value<String?>? lastMessageType,
    Value<String?>? lastMessageSenderId,
    Value<String?>? lastMessageTime,
    Value<bool>? lastMessageIsRead,
    Value<String?>? lastMessageStatus,
    Value<int>? unreadCount,
    Value<int>? updatedAt,
    Value<bool>? isMuted,
    Value<String>? status,
    Value<String?>? otherUserId,
    Value<String?>? otherUserUsername,
    Value<bool>? otherUserIsVerified,
    Value<String?>? otherUserVerificationBadge,
    Value<String?>? initiatorId,
    Value<bool>? iBlockedThem,
    Value<bool>? theyBlockedMe,
    Value<int>? sentMessageCount,
    Value<String?>? lastReactionEmoji,
    Value<String?>? lastReactionAt,
    Value<String?>? lastReactionUserId,
    Value<String?>? lastReactionMessageContent,
    Value<String>? syncStatus,
    Value<String?>? lastSyncedAt,
    Value<int>? rowid,
  }) {
    return ConversationsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      profilePic: profilePic ?? this.profilePic,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageIsRead: lastMessageIsRead ?? this.lastMessageIsRead,
      lastMessageStatus: lastMessageStatus ?? this.lastMessageStatus,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
      isMuted: isMuted ?? this.isMuted,
      status: status ?? this.status,
      otherUserId: otherUserId ?? this.otherUserId,
      otherUserUsername: otherUserUsername ?? this.otherUserUsername,
      otherUserIsVerified: otherUserIsVerified ?? this.otherUserIsVerified,
      otherUserVerificationBadge:
          otherUserVerificationBadge ?? this.otherUserVerificationBadge,
      initiatorId: initiatorId ?? this.initiatorId,
      iBlockedThem: iBlockedThem ?? this.iBlockedThem,
      theyBlockedMe: theyBlockedMe ?? this.theyBlockedMe,
      sentMessageCount: sentMessageCount ?? this.sentMessageCount,
      lastReactionEmoji: lastReactionEmoji ?? this.lastReactionEmoji,
      lastReactionAt: lastReactionAt ?? this.lastReactionAt,
      lastReactionUserId: lastReactionUserId ?? this.lastReactionUserId,
      lastReactionMessageContent:
          lastReactionMessageContent ?? this.lastReactionMessageContent,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (profilePic.present) {
      map['profile_pic'] = Variable<String>(profilePic.value);
    }
    if (lastMessage.present) {
      map['last_message'] = Variable<String>(lastMessage.value);
    }
    if (lastMessageType.present) {
      map['last_message_type'] = Variable<String>(lastMessageType.value);
    }
    if (lastMessageSenderId.present) {
      map['last_message_sender_id'] = Variable<String>(
        lastMessageSenderId.value,
      );
    }
    if (lastMessageTime.present) {
      map['last_message_time'] = Variable<String>(lastMessageTime.value);
    }
    if (lastMessageIsRead.present) {
      map['last_message_is_read'] = Variable<bool>(lastMessageIsRead.value);
    }
    if (lastMessageStatus.present) {
      map['last_message_status'] = Variable<String>(lastMessageStatus.value);
    }
    if (unreadCount.present) {
      map['unread_count'] = Variable<int>(unreadCount.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (isMuted.present) {
      map['is_muted'] = Variable<bool>(isMuted.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (otherUserId.present) {
      map['other_user_id'] = Variable<String>(otherUserId.value);
    }
    if (otherUserUsername.present) {
      map['other_user_username'] = Variable<String>(otherUserUsername.value);
    }
    if (otherUserIsVerified.present) {
      map['other_user_is_verified'] = Variable<bool>(otherUserIsVerified.value);
    }
    if (otherUserVerificationBadge.present) {
      map['other_user_verification_badge'] = Variable<String>(
        otherUserVerificationBadge.value,
      );
    }
    if (initiatorId.present) {
      map['initiator_id'] = Variable<String>(initiatorId.value);
    }
    if (iBlockedThem.present) {
      map['i_blocked_them'] = Variable<bool>(iBlockedThem.value);
    }
    if (theyBlockedMe.present) {
      map['they_blocked_me'] = Variable<bool>(theyBlockedMe.value);
    }
    if (sentMessageCount.present) {
      map['sent_message_count'] = Variable<int>(sentMessageCount.value);
    }
    if (lastReactionEmoji.present) {
      map['last_reaction_emoji'] = Variable<String>(lastReactionEmoji.value);
    }
    if (lastReactionAt.present) {
      map['last_reaction_at'] = Variable<String>(lastReactionAt.value);
    }
    if (lastReactionUserId.present) {
      map['last_reaction_user_id'] = Variable<String>(lastReactionUserId.value);
    }
    if (lastReactionMessageContent.present) {
      map['last_reaction_message_content'] = Variable<String>(
        lastReactionMessageContent.value,
      );
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<String>(lastSyncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('profilePic: $profilePic, ')
          ..write('lastMessage: $lastMessage, ')
          ..write('lastMessageType: $lastMessageType, ')
          ..write('lastMessageSenderId: $lastMessageSenderId, ')
          ..write('lastMessageTime: $lastMessageTime, ')
          ..write('lastMessageIsRead: $lastMessageIsRead, ')
          ..write('lastMessageStatus: $lastMessageStatus, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isMuted: $isMuted, ')
          ..write('status: $status, ')
          ..write('otherUserId: $otherUserId, ')
          ..write('otherUserUsername: $otherUserUsername, ')
          ..write('otherUserIsVerified: $otherUserIsVerified, ')
          ..write('otherUserVerificationBadge: $otherUserVerificationBadge, ')
          ..write('initiatorId: $initiatorId, ')
          ..write('iBlockedThem: $iBlockedThem, ')
          ..write('theyBlockedMe: $theyBlockedMe, ')
          ..write('sentMessageCount: $sentMessageCount, ')
          ..write('lastReactionEmoji: $lastReactionEmoji, ')
          ..write('lastReactionAt: $lastReactionAt, ')
          ..write('lastReactionUserId: $lastReactionUserId, ')
          ..write('lastReactionMessageContent: $lastReactionMessageContent, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderIdMeta = const VerificationMeta(
    'senderId',
  );
  @override
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
    'sender_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receiverIdMeta = const VerificationMeta(
    'receiverId',
  );
  @override
  late final GeneratedColumn<String> receiverId = GeneratedColumn<String>(
    'receiver_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _senderNameMeta = const VerificationMeta(
    'senderName',
  );
  @override
  late final GeneratedColumn<String> senderName = GeneratedColumn<String>(
    'sender_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _senderPicMeta = const VerificationMeta(
    'senderPic',
  );
  @override
  late final GeneratedColumn<String> senderPic = GeneratedColumn<String>(
    'sender_pic',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _senderUsernameMeta = const VerificationMeta(
    'senderUsername',
  );
  @override
  late final GeneratedColumn<String> senderUsername = GeneratedColumn<String>(
    'sender_username',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _senderIsVerifiedMeta = const VerificationMeta(
    'senderIsVerified',
  );
  @override
  late final GeneratedColumn<bool> senderIsVerified = GeneratedColumn<bool>(
    'sender_is_verified',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sender_is_verified" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _senderVerificationBadgeMeta =
      const VerificationMeta('senderVerificationBadge');
  @override
  late final GeneratedColumn<String> senderVerificationBadge =
      GeneratedColumn<String>(
        'sender_verification_badge',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _messageTypeMeta = const VerificationMeta(
    'messageType',
  );
  @override
  late final GeneratedColumn<String> messageType = GeneratedColumn<String>(
    'message_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('text'),
  );
  static const VerificationMeta _mediaUrlMeta = const VerificationMeta(
    'mediaUrl',
  );
  @override
  late final GeneratedColumn<String> mediaUrl = GeneratedColumn<String>(
    'media_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaDataMeta = const VerificationMeta(
    'mediaData',
  );
  @override
  late final GeneratedColumn<String> mediaData = GeneratedColumn<String>(
    'media_data',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkPreviewMeta = const VerificationMeta(
    'linkPreview',
  );
  @override
  late final GeneratedColumn<String> linkPreview = GeneratedColumn<String>(
    'link_preview',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reactionsMeta = const VerificationMeta(
    'reactions',
  );
  @override
  late final GeneratedColumn<String> reactions = GeneratedColumn<String>(
    'reactions',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _replyToIdMeta = const VerificationMeta(
    'replyToId',
  );
  @override
  late final GeneratedColumn<String> replyToId = GeneratedColumn<String>(
    'reply_to_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _replyToMeta = const VerificationMeta(
    'replyTo',
  );
  @override
  late final GeneratedColumn<String> replyTo = GeneratedColumn<String>(
    'reply_to',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isReadMeta = const VerificationMeta('isRead');
  @override
  late final GeneratedColumn<bool> isRead = GeneratedColumn<bool>(
    'is_read',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_read" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _readAtMeta = const VerificationMeta('readAt');
  @override
  late final GeneratedColumn<String> readAt = GeneratedColumn<String>(
    'read_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deletedForSenderMeta = const VerificationMeta(
    'deletedForSender',
  );
  @override
  late final GeneratedColumn<bool> deletedForSender = GeneratedColumn<bool>(
    'deleted_for_sender',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted_for_sender" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deletedForReceiverMeta =
      const VerificationMeta('deletedForReceiver');
  @override
  late final GeneratedColumn<bool> deletedForReceiver = GeneratedColumn<bool>(
    'deleted_for_receiver',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted_for_receiver" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isEditedMeta = const VerificationMeta(
    'isEdited',
  );
  @override
  late final GeneratedColumn<bool> isEdited = GeneratedColumn<bool>(
    'is_edited',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_edited" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _editedAtMeta = const VerificationMeta(
    'editedAt',
  );
  @override
  late final GeneratedColumn<String> editedAt = GeneratedColumn<String>(
    'edited_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending_sync'),
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _tempIdMeta = const VerificationMeta('tempId');
  @override
  late final GeneratedColumn<String> tempId = GeneratedColumn<String>(
    'temp_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isSystemMeta = const VerificationMeta(
    'isSystem',
  );
  @override
  late final GeneratedColumn<bool> isSystem = GeneratedColumn<bool>(
    'is_system',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_system" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pollDataMeta = const VerificationMeta(
    'pollData',
  );
  @override
  late final GeneratedColumn<String> pollData = GeneratedColumn<String>(
    'poll_data',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isForwardedMeta = const VerificationMeta(
    'isForwarded',
  );
  @override
  late final GeneratedColumn<bool> isForwarded = GeneratedColumn<bool>(
    'is_forwarded',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_forwarded" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _forwardedFromMeta = const VerificationMeta(
    'forwardedFrom',
  );
  @override
  late final GeneratedColumn<String> forwardedFrom = GeneratedColumn<String>(
    'forwarded_from',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _translatedContentMeta = const VerificationMeta(
    'translatedContent',
  );
  @override
  late final GeneratedColumn<String> translatedContent =
      GeneratedColumn<String>(
        'translated_content',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _translatedLanguageMeta =
      const VerificationMeta('translatedLanguage');
  @override
  late final GeneratedColumn<String> translatedLanguage =
      GeneratedColumn<String>(
        'translated_language',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    senderId,
    receiverId,
    senderName,
    senderPic,
    senderUsername,
    senderIsVerified,
    senderVerificationBadge,
    content,
    messageType,
    mediaUrl,
    mediaData,
    metadata,
    linkPreview,
    reactions,
    replyToId,
    replyTo,
    isRead,
    readAt,
    status,
    isDeleted,
    deletedForSender,
    deletedForReceiver,
    deletedAt,
    isEdited,
    editedAt,
    createdAt,
    updatedAt,
    syncStatus,
    retryCount,
    tempId,
    isSystem,
    groupId,
    pollData,
    isForwarded,
    forwardedFrom,
    isPinned,
    translatedContent,
    translatedLanguage,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<Message> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('sender_id')) {
      context.handle(
        _senderIdMeta,
        senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_senderIdMeta);
    }
    if (data.containsKey('receiver_id')) {
      context.handle(
        _receiverIdMeta,
        receiverId.isAcceptableOrUnknown(data['receiver_id']!, _receiverIdMeta),
      );
    }
    if (data.containsKey('sender_name')) {
      context.handle(
        _senderNameMeta,
        senderName.isAcceptableOrUnknown(data['sender_name']!, _senderNameMeta),
      );
    }
    if (data.containsKey('sender_pic')) {
      context.handle(
        _senderPicMeta,
        senderPic.isAcceptableOrUnknown(data['sender_pic']!, _senderPicMeta),
      );
    }
    if (data.containsKey('sender_username')) {
      context.handle(
        _senderUsernameMeta,
        senderUsername.isAcceptableOrUnknown(
          data['sender_username']!,
          _senderUsernameMeta,
        ),
      );
    }
    if (data.containsKey('sender_is_verified')) {
      context.handle(
        _senderIsVerifiedMeta,
        senderIsVerified.isAcceptableOrUnknown(
          data['sender_is_verified']!,
          _senderIsVerifiedMeta,
        ),
      );
    }
    if (data.containsKey('sender_verification_badge')) {
      context.handle(
        _senderVerificationBadgeMeta,
        senderVerificationBadge.isAcceptableOrUnknown(
          data['sender_verification_badge']!,
          _senderVerificationBadgeMeta,
        ),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('message_type')) {
      context.handle(
        _messageTypeMeta,
        messageType.isAcceptableOrUnknown(
          data['message_type']!,
          _messageTypeMeta,
        ),
      );
    }
    if (data.containsKey('media_url')) {
      context.handle(
        _mediaUrlMeta,
        mediaUrl.isAcceptableOrUnknown(data['media_url']!, _mediaUrlMeta),
      );
    }
    if (data.containsKey('media_data')) {
      context.handle(
        _mediaDataMeta,
        mediaData.isAcceptableOrUnknown(data['media_data']!, _mediaDataMeta),
      );
    }
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
      );
    }
    if (data.containsKey('link_preview')) {
      context.handle(
        _linkPreviewMeta,
        linkPreview.isAcceptableOrUnknown(
          data['link_preview']!,
          _linkPreviewMeta,
        ),
      );
    }
    if (data.containsKey('reactions')) {
      context.handle(
        _reactionsMeta,
        reactions.isAcceptableOrUnknown(data['reactions']!, _reactionsMeta),
      );
    }
    if (data.containsKey('reply_to_id')) {
      context.handle(
        _replyToIdMeta,
        replyToId.isAcceptableOrUnknown(data['reply_to_id']!, _replyToIdMeta),
      );
    }
    if (data.containsKey('reply_to')) {
      context.handle(
        _replyToMeta,
        replyTo.isAcceptableOrUnknown(data['reply_to']!, _replyToMeta),
      );
    }
    if (data.containsKey('is_read')) {
      context.handle(
        _isReadMeta,
        isRead.isAcceptableOrUnknown(data['is_read']!, _isReadMeta),
      );
    }
    if (data.containsKey('read_at')) {
      context.handle(
        _readAtMeta,
        readAt.isAcceptableOrUnknown(data['read_at']!, _readAtMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('deleted_for_sender')) {
      context.handle(
        _deletedForSenderMeta,
        deletedForSender.isAcceptableOrUnknown(
          data['deleted_for_sender']!,
          _deletedForSenderMeta,
        ),
      );
    }
    if (data.containsKey('deleted_for_receiver')) {
      context.handle(
        _deletedForReceiverMeta,
        deletedForReceiver.isAcceptableOrUnknown(
          data['deleted_for_receiver']!,
          _deletedForReceiverMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('is_edited')) {
      context.handle(
        _isEditedMeta,
        isEdited.isAcceptableOrUnknown(data['is_edited']!, _isEditedMeta),
      );
    }
    if (data.containsKey('edited_at')) {
      context.handle(
        _editedAtMeta,
        editedAt.isAcceptableOrUnknown(data['edited_at']!, _editedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('temp_id')) {
      context.handle(
        _tempIdMeta,
        tempId.isAcceptableOrUnknown(data['temp_id']!, _tempIdMeta),
      );
    }
    if (data.containsKey('is_system')) {
      context.handle(
        _isSystemMeta,
        isSystem.isAcceptableOrUnknown(data['is_system']!, _isSystemMeta),
      );
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('poll_data')) {
      context.handle(
        _pollDataMeta,
        pollData.isAcceptableOrUnknown(data['poll_data']!, _pollDataMeta),
      );
    }
    if (data.containsKey('is_forwarded')) {
      context.handle(
        _isForwardedMeta,
        isForwarded.isAcceptableOrUnknown(
          data['is_forwarded']!,
          _isForwardedMeta,
        ),
      );
    }
    if (data.containsKey('forwarded_from')) {
      context.handle(
        _forwardedFromMeta,
        forwardedFrom.isAcceptableOrUnknown(
          data['forwarded_from']!,
          _forwardedFromMeta,
        ),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('translated_content')) {
      context.handle(
        _translatedContentMeta,
        translatedContent.isAcceptableOrUnknown(
          data['translated_content']!,
          _translatedContentMeta,
        ),
      );
    }
    if (data.containsKey('translated_language')) {
      context.handle(
        _translatedLanguageMeta,
        translatedLanguage.isAcceptableOrUnknown(
          data['translated_language']!,
          _translatedLanguageMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      senderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_id'],
      )!,
      receiverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receiver_id'],
      ),
      senderName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_name'],
      )!,
      senderPic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_pic'],
      ),
      senderUsername: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_username'],
      ),
      senderIsVerified: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sender_is_verified'],
      )!,
      senderVerificationBadge: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_verification_badge'],
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      messageType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_type'],
      )!,
      mediaUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_url'],
      ),
      mediaData: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_data'],
      ),
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      ),
      linkPreview: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}link_preview'],
      ),
      reactions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reactions'],
      ),
      replyToId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply_to_id'],
      ),
      replyTo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply_to'],
      ),
      isRead: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_read'],
      )!,
      readAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}read_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      deletedForSender: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted_for_sender'],
      )!,
      deletedForReceiver: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted_for_receiver'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      isEdited: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_edited'],
      )!,
      editedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}edited_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      tempId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}temp_id'],
      ),
      isSystem: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_system'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      ),
      pollData: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poll_data'],
      ),
      isForwarded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_forwarded'],
      )!,
      forwardedFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}forwarded_from'],
      ),
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      translatedContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translated_content'],
      ),
      translatedLanguage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translated_language'],
      ),
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class Message extends DataClass implements Insertable<Message> {
  final String id;
  final String conversationId;
  final String senderId;
  final String? receiverId;
  final String senderName;
  final String? senderPic;
  final String? senderUsername;
  final bool senderIsVerified;
  final String? senderVerificationBadge;
  final String content;
  final String messageType;
  final String? mediaUrl;
  final String? mediaData;
  final String? metadata;
  final String? linkPreview;
  final String? reactions;
  final String? replyToId;
  final String? replyTo;
  final bool isRead;
  final String? readAt;
  final String status;
  final bool isDeleted;
  final bool deletedForSender;
  final bool deletedForReceiver;
  final String? deletedAt;
  final bool isEdited;
  final String? editedAt;
  final int createdAt;
  final int updatedAt;
  final String syncStatus;
  final int retryCount;
  final String? tempId;
  final bool isSystem;
  final String? groupId;
  final String? pollData;
  final bool isForwarded;
  final String? forwardedFrom;
  final bool isPinned;
  final String? translatedContent;
  final String? translatedLanguage;
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.receiverId,
    required this.senderName,
    this.senderPic,
    this.senderUsername,
    required this.senderIsVerified,
    this.senderVerificationBadge,
    required this.content,
    required this.messageType,
    this.mediaUrl,
    this.mediaData,
    this.metadata,
    this.linkPreview,
    this.reactions,
    this.replyToId,
    this.replyTo,
    required this.isRead,
    this.readAt,
    required this.status,
    required this.isDeleted,
    required this.deletedForSender,
    required this.deletedForReceiver,
    this.deletedAt,
    required this.isEdited,
    this.editedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
    required this.retryCount,
    this.tempId,
    required this.isSystem,
    this.groupId,
    this.pollData,
    required this.isForwarded,
    this.forwardedFrom,
    required this.isPinned,
    this.translatedContent,
    this.translatedLanguage,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['sender_id'] = Variable<String>(senderId);
    if (!nullToAbsent || receiverId != null) {
      map['receiver_id'] = Variable<String>(receiverId);
    }
    map['sender_name'] = Variable<String>(senderName);
    if (!nullToAbsent || senderPic != null) {
      map['sender_pic'] = Variable<String>(senderPic);
    }
    if (!nullToAbsent || senderUsername != null) {
      map['sender_username'] = Variable<String>(senderUsername);
    }
    map['sender_is_verified'] = Variable<bool>(senderIsVerified);
    if (!nullToAbsent || senderVerificationBadge != null) {
      map['sender_verification_badge'] = Variable<String>(
        senderVerificationBadge,
      );
    }
    map['content'] = Variable<String>(content);
    map['message_type'] = Variable<String>(messageType);
    if (!nullToAbsent || mediaUrl != null) {
      map['media_url'] = Variable<String>(mediaUrl);
    }
    if (!nullToAbsent || mediaData != null) {
      map['media_data'] = Variable<String>(mediaData);
    }
    if (!nullToAbsent || metadata != null) {
      map['metadata'] = Variable<String>(metadata);
    }
    if (!nullToAbsent || linkPreview != null) {
      map['link_preview'] = Variable<String>(linkPreview);
    }
    if (!nullToAbsent || reactions != null) {
      map['reactions'] = Variable<String>(reactions);
    }
    if (!nullToAbsent || replyToId != null) {
      map['reply_to_id'] = Variable<String>(replyToId);
    }
    if (!nullToAbsent || replyTo != null) {
      map['reply_to'] = Variable<String>(replyTo);
    }
    map['is_read'] = Variable<bool>(isRead);
    if (!nullToAbsent || readAt != null) {
      map['read_at'] = Variable<String>(readAt);
    }
    map['status'] = Variable<String>(status);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['deleted_for_sender'] = Variable<bool>(deletedForSender);
    map['deleted_for_receiver'] = Variable<bool>(deletedForReceiver);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    map['is_edited'] = Variable<bool>(isEdited);
    if (!nullToAbsent || editedAt != null) {
      map['edited_at'] = Variable<String>(editedAt);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['sync_status'] = Variable<String>(syncStatus);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || tempId != null) {
      map['temp_id'] = Variable<String>(tempId);
    }
    map['is_system'] = Variable<bool>(isSystem);
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<String>(groupId);
    }
    if (!nullToAbsent || pollData != null) {
      map['poll_data'] = Variable<String>(pollData);
    }
    map['is_forwarded'] = Variable<bool>(isForwarded);
    if (!nullToAbsent || forwardedFrom != null) {
      map['forwarded_from'] = Variable<String>(forwardedFrom);
    }
    map['is_pinned'] = Variable<bool>(isPinned);
    if (!nullToAbsent || translatedContent != null) {
      map['translated_content'] = Variable<String>(translatedContent);
    }
    if (!nullToAbsent || translatedLanguage != null) {
      map['translated_language'] = Variable<String>(translatedLanguage);
    }
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      senderId: Value(senderId),
      receiverId: receiverId == null && nullToAbsent
          ? const Value.absent()
          : Value(receiverId),
      senderName: Value(senderName),
      senderPic: senderPic == null && nullToAbsent
          ? const Value.absent()
          : Value(senderPic),
      senderUsername: senderUsername == null && nullToAbsent
          ? const Value.absent()
          : Value(senderUsername),
      senderIsVerified: Value(senderIsVerified),
      senderVerificationBadge: senderVerificationBadge == null && nullToAbsent
          ? const Value.absent()
          : Value(senderVerificationBadge),
      content: Value(content),
      messageType: Value(messageType),
      mediaUrl: mediaUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaUrl),
      mediaData: mediaData == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaData),
      metadata: metadata == null && nullToAbsent
          ? const Value.absent()
          : Value(metadata),
      linkPreview: linkPreview == null && nullToAbsent
          ? const Value.absent()
          : Value(linkPreview),
      reactions: reactions == null && nullToAbsent
          ? const Value.absent()
          : Value(reactions),
      replyToId: replyToId == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToId),
      replyTo: replyTo == null && nullToAbsent
          ? const Value.absent()
          : Value(replyTo),
      isRead: Value(isRead),
      readAt: readAt == null && nullToAbsent
          ? const Value.absent()
          : Value(readAt),
      status: Value(status),
      isDeleted: Value(isDeleted),
      deletedForSender: Value(deletedForSender),
      deletedForReceiver: Value(deletedForReceiver),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      isEdited: Value(isEdited),
      editedAt: editedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(editedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      syncStatus: Value(syncStatus),
      retryCount: Value(retryCount),
      tempId: tempId == null && nullToAbsent
          ? const Value.absent()
          : Value(tempId),
      isSystem: Value(isSystem),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      pollData: pollData == null && nullToAbsent
          ? const Value.absent()
          : Value(pollData),
      isForwarded: Value(isForwarded),
      forwardedFrom: forwardedFrom == null && nullToAbsent
          ? const Value.absent()
          : Value(forwardedFrom),
      isPinned: Value(isPinned),
      translatedContent: translatedContent == null && nullToAbsent
          ? const Value.absent()
          : Value(translatedContent),
      translatedLanguage: translatedLanguage == null && nullToAbsent
          ? const Value.absent()
          : Value(translatedLanguage),
    );
  }

  factory Message.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      senderId: serializer.fromJson<String>(json['senderId']),
      receiverId: serializer.fromJson<String?>(json['receiverId']),
      senderName: serializer.fromJson<String>(json['senderName']),
      senderPic: serializer.fromJson<String?>(json['senderPic']),
      senderUsername: serializer.fromJson<String?>(json['senderUsername']),
      senderIsVerified: serializer.fromJson<bool>(json['senderIsVerified']),
      senderVerificationBadge: serializer.fromJson<String?>(
        json['senderVerificationBadge'],
      ),
      content: serializer.fromJson<String>(json['content']),
      messageType: serializer.fromJson<String>(json['messageType']),
      mediaUrl: serializer.fromJson<String?>(json['mediaUrl']),
      mediaData: serializer.fromJson<String?>(json['mediaData']),
      metadata: serializer.fromJson<String?>(json['metadata']),
      linkPreview: serializer.fromJson<String?>(json['linkPreview']),
      reactions: serializer.fromJson<String?>(json['reactions']),
      replyToId: serializer.fromJson<String?>(json['replyToId']),
      replyTo: serializer.fromJson<String?>(json['replyTo']),
      isRead: serializer.fromJson<bool>(json['isRead']),
      readAt: serializer.fromJson<String?>(json['readAt']),
      status: serializer.fromJson<String>(json['status']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedForSender: serializer.fromJson<bool>(json['deletedForSender']),
      deletedForReceiver: serializer.fromJson<bool>(json['deletedForReceiver']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      isEdited: serializer.fromJson<bool>(json['isEdited']),
      editedAt: serializer.fromJson<String?>(json['editedAt']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      tempId: serializer.fromJson<String?>(json['tempId']),
      isSystem: serializer.fromJson<bool>(json['isSystem']),
      groupId: serializer.fromJson<String?>(json['groupId']),
      pollData: serializer.fromJson<String?>(json['pollData']),
      isForwarded: serializer.fromJson<bool>(json['isForwarded']),
      forwardedFrom: serializer.fromJson<String?>(json['forwardedFrom']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      translatedContent: serializer.fromJson<String?>(
        json['translatedContent'],
      ),
      translatedLanguage: serializer.fromJson<String?>(
        json['translatedLanguage'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'senderId': serializer.toJson<String>(senderId),
      'receiverId': serializer.toJson<String?>(receiverId),
      'senderName': serializer.toJson<String>(senderName),
      'senderPic': serializer.toJson<String?>(senderPic),
      'senderUsername': serializer.toJson<String?>(senderUsername),
      'senderIsVerified': serializer.toJson<bool>(senderIsVerified),
      'senderVerificationBadge': serializer.toJson<String?>(
        senderVerificationBadge,
      ),
      'content': serializer.toJson<String>(content),
      'messageType': serializer.toJson<String>(messageType),
      'mediaUrl': serializer.toJson<String?>(mediaUrl),
      'mediaData': serializer.toJson<String?>(mediaData),
      'metadata': serializer.toJson<String?>(metadata),
      'linkPreview': serializer.toJson<String?>(linkPreview),
      'reactions': serializer.toJson<String?>(reactions),
      'replyToId': serializer.toJson<String?>(replyToId),
      'replyTo': serializer.toJson<String?>(replyTo),
      'isRead': serializer.toJson<bool>(isRead),
      'readAt': serializer.toJson<String?>(readAt),
      'status': serializer.toJson<String>(status),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedForSender': serializer.toJson<bool>(deletedForSender),
      'deletedForReceiver': serializer.toJson<bool>(deletedForReceiver),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'isEdited': serializer.toJson<bool>(isEdited),
      'editedAt': serializer.toJson<String?>(editedAt),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'retryCount': serializer.toJson<int>(retryCount),
      'tempId': serializer.toJson<String?>(tempId),
      'isSystem': serializer.toJson<bool>(isSystem),
      'groupId': serializer.toJson<String?>(groupId),
      'pollData': serializer.toJson<String?>(pollData),
      'isForwarded': serializer.toJson<bool>(isForwarded),
      'forwardedFrom': serializer.toJson<String?>(forwardedFrom),
      'isPinned': serializer.toJson<bool>(isPinned),
      'translatedContent': serializer.toJson<String?>(translatedContent),
      'translatedLanguage': serializer.toJson<String?>(translatedLanguage),
    };
  }

  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    Value<String?> receiverId = const Value.absent(),
    String? senderName,
    Value<String?> senderPic = const Value.absent(),
    Value<String?> senderUsername = const Value.absent(),
    bool? senderIsVerified,
    Value<String?> senderVerificationBadge = const Value.absent(),
    String? content,
    String? messageType,
    Value<String?> mediaUrl = const Value.absent(),
    Value<String?> mediaData = const Value.absent(),
    Value<String?> metadata = const Value.absent(),
    Value<String?> linkPreview = const Value.absent(),
    Value<String?> reactions = const Value.absent(),
    Value<String?> replyToId = const Value.absent(),
    Value<String?> replyTo = const Value.absent(),
    bool? isRead,
    Value<String?> readAt = const Value.absent(),
    String? status,
    bool? isDeleted,
    bool? deletedForSender,
    bool? deletedForReceiver,
    Value<String?> deletedAt = const Value.absent(),
    bool? isEdited,
    Value<String?> editedAt = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    String? syncStatus,
    int? retryCount,
    Value<String?> tempId = const Value.absent(),
    bool? isSystem,
    Value<String?> groupId = const Value.absent(),
    Value<String?> pollData = const Value.absent(),
    bool? isForwarded,
    Value<String?> forwardedFrom = const Value.absent(),
    bool? isPinned,
    Value<String?> translatedContent = const Value.absent(),
    Value<String?> translatedLanguage = const Value.absent(),
  }) => Message(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    senderId: senderId ?? this.senderId,
    receiverId: receiverId.present ? receiverId.value : this.receiverId,
    senderName: senderName ?? this.senderName,
    senderPic: senderPic.present ? senderPic.value : this.senderPic,
    senderUsername: senderUsername.present
        ? senderUsername.value
        : this.senderUsername,
    senderIsVerified: senderIsVerified ?? this.senderIsVerified,
    senderVerificationBadge: senderVerificationBadge.present
        ? senderVerificationBadge.value
        : this.senderVerificationBadge,
    content: content ?? this.content,
    messageType: messageType ?? this.messageType,
    mediaUrl: mediaUrl.present ? mediaUrl.value : this.mediaUrl,
    mediaData: mediaData.present ? mediaData.value : this.mediaData,
    metadata: metadata.present ? metadata.value : this.metadata,
    linkPreview: linkPreview.present ? linkPreview.value : this.linkPreview,
    reactions: reactions.present ? reactions.value : this.reactions,
    replyToId: replyToId.present ? replyToId.value : this.replyToId,
    replyTo: replyTo.present ? replyTo.value : this.replyTo,
    isRead: isRead ?? this.isRead,
    readAt: readAt.present ? readAt.value : this.readAt,
    status: status ?? this.status,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedForSender: deletedForSender ?? this.deletedForSender,
    deletedForReceiver: deletedForReceiver ?? this.deletedForReceiver,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    isEdited: isEdited ?? this.isEdited,
    editedAt: editedAt.present ? editedAt.value : this.editedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
    retryCount: retryCount ?? this.retryCount,
    tempId: tempId.present ? tempId.value : this.tempId,
    isSystem: isSystem ?? this.isSystem,
    groupId: groupId.present ? groupId.value : this.groupId,
    pollData: pollData.present ? pollData.value : this.pollData,
    isForwarded: isForwarded ?? this.isForwarded,
    forwardedFrom: forwardedFrom.present
        ? forwardedFrom.value
        : this.forwardedFrom,
    isPinned: isPinned ?? this.isPinned,
    translatedContent: translatedContent.present
        ? translatedContent.value
        : this.translatedContent,
    translatedLanguage: translatedLanguage.present
        ? translatedLanguage.value
        : this.translatedLanguage,
  );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      receiverId: data.receiverId.present
          ? data.receiverId.value
          : this.receiverId,
      senderName: data.senderName.present
          ? data.senderName.value
          : this.senderName,
      senderPic: data.senderPic.present ? data.senderPic.value : this.senderPic,
      senderUsername: data.senderUsername.present
          ? data.senderUsername.value
          : this.senderUsername,
      senderIsVerified: data.senderIsVerified.present
          ? data.senderIsVerified.value
          : this.senderIsVerified,
      senderVerificationBadge: data.senderVerificationBadge.present
          ? data.senderVerificationBadge.value
          : this.senderVerificationBadge,
      content: data.content.present ? data.content.value : this.content,
      messageType: data.messageType.present
          ? data.messageType.value
          : this.messageType,
      mediaUrl: data.mediaUrl.present ? data.mediaUrl.value : this.mediaUrl,
      mediaData: data.mediaData.present ? data.mediaData.value : this.mediaData,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
      linkPreview: data.linkPreview.present
          ? data.linkPreview.value
          : this.linkPreview,
      reactions: data.reactions.present ? data.reactions.value : this.reactions,
      replyToId: data.replyToId.present ? data.replyToId.value : this.replyToId,
      replyTo: data.replyTo.present ? data.replyTo.value : this.replyTo,
      isRead: data.isRead.present ? data.isRead.value : this.isRead,
      readAt: data.readAt.present ? data.readAt.value : this.readAt,
      status: data.status.present ? data.status.value : this.status,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedForSender: data.deletedForSender.present
          ? data.deletedForSender.value
          : this.deletedForSender,
      deletedForReceiver: data.deletedForReceiver.present
          ? data.deletedForReceiver.value
          : this.deletedForReceiver,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      isEdited: data.isEdited.present ? data.isEdited.value : this.isEdited,
      editedAt: data.editedAt.present ? data.editedAt.value : this.editedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      tempId: data.tempId.present ? data.tempId.value : this.tempId,
      isSystem: data.isSystem.present ? data.isSystem.value : this.isSystem,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      pollData: data.pollData.present ? data.pollData.value : this.pollData,
      isForwarded: data.isForwarded.present
          ? data.isForwarded.value
          : this.isForwarded,
      forwardedFrom: data.forwardedFrom.present
          ? data.forwardedFrom.value
          : this.forwardedFrom,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      translatedContent: data.translatedContent.present
          ? data.translatedContent.value
          : this.translatedContent,
      translatedLanguage: data.translatedLanguage.present
          ? data.translatedLanguage.value
          : this.translatedLanguage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderId: $senderId, ')
          ..write('receiverId: $receiverId, ')
          ..write('senderName: $senderName, ')
          ..write('senderPic: $senderPic, ')
          ..write('senderUsername: $senderUsername, ')
          ..write('senderIsVerified: $senderIsVerified, ')
          ..write('senderVerificationBadge: $senderVerificationBadge, ')
          ..write('content: $content, ')
          ..write('messageType: $messageType, ')
          ..write('mediaUrl: $mediaUrl, ')
          ..write('mediaData: $mediaData, ')
          ..write('metadata: $metadata, ')
          ..write('linkPreview: $linkPreview, ')
          ..write('reactions: $reactions, ')
          ..write('replyToId: $replyToId, ')
          ..write('replyTo: $replyTo, ')
          ..write('isRead: $isRead, ')
          ..write('readAt: $readAt, ')
          ..write('status: $status, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedForSender: $deletedForSender, ')
          ..write('deletedForReceiver: $deletedForReceiver, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('isEdited: $isEdited, ')
          ..write('editedAt: $editedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('retryCount: $retryCount, ')
          ..write('tempId: $tempId, ')
          ..write('isSystem: $isSystem, ')
          ..write('groupId: $groupId, ')
          ..write('pollData: $pollData, ')
          ..write('isForwarded: $isForwarded, ')
          ..write('forwardedFrom: $forwardedFrom, ')
          ..write('isPinned: $isPinned, ')
          ..write('translatedContent: $translatedContent, ')
          ..write('translatedLanguage: $translatedLanguage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    conversationId,
    senderId,
    receiverId,
    senderName,
    senderPic,
    senderUsername,
    senderIsVerified,
    senderVerificationBadge,
    content,
    messageType,
    mediaUrl,
    mediaData,
    metadata,
    linkPreview,
    reactions,
    replyToId,
    replyTo,
    isRead,
    readAt,
    status,
    isDeleted,
    deletedForSender,
    deletedForReceiver,
    deletedAt,
    isEdited,
    editedAt,
    createdAt,
    updatedAt,
    syncStatus,
    retryCount,
    tempId,
    isSystem,
    groupId,
    pollData,
    isForwarded,
    forwardedFrom,
    isPinned,
    translatedContent,
    translatedLanguage,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.senderId == this.senderId &&
          other.receiverId == this.receiverId &&
          other.senderName == this.senderName &&
          other.senderPic == this.senderPic &&
          other.senderUsername == this.senderUsername &&
          other.senderIsVerified == this.senderIsVerified &&
          other.senderVerificationBadge == this.senderVerificationBadge &&
          other.content == this.content &&
          other.messageType == this.messageType &&
          other.mediaUrl == this.mediaUrl &&
          other.mediaData == this.mediaData &&
          other.metadata == this.metadata &&
          other.linkPreview == this.linkPreview &&
          other.reactions == this.reactions &&
          other.replyToId == this.replyToId &&
          other.replyTo == this.replyTo &&
          other.isRead == this.isRead &&
          other.readAt == this.readAt &&
          other.status == this.status &&
          other.isDeleted == this.isDeleted &&
          other.deletedForSender == this.deletedForSender &&
          other.deletedForReceiver == this.deletedForReceiver &&
          other.deletedAt == this.deletedAt &&
          other.isEdited == this.isEdited &&
          other.editedAt == this.editedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.syncStatus == this.syncStatus &&
          other.retryCount == this.retryCount &&
          other.tempId == this.tempId &&
          other.isSystem == this.isSystem &&
          other.groupId == this.groupId &&
          other.pollData == this.pollData &&
          other.isForwarded == this.isForwarded &&
          other.forwardedFrom == this.forwardedFrom &&
          other.isPinned == this.isPinned &&
          other.translatedContent == this.translatedContent &&
          other.translatedLanguage == this.translatedLanguage);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> senderId;
  final Value<String?> receiverId;
  final Value<String> senderName;
  final Value<String?> senderPic;
  final Value<String?> senderUsername;
  final Value<bool> senderIsVerified;
  final Value<String?> senderVerificationBadge;
  final Value<String> content;
  final Value<String> messageType;
  final Value<String?> mediaUrl;
  final Value<String?> mediaData;
  final Value<String?> metadata;
  final Value<String?> linkPreview;
  final Value<String?> reactions;
  final Value<String?> replyToId;
  final Value<String?> replyTo;
  final Value<bool> isRead;
  final Value<String?> readAt;
  final Value<String> status;
  final Value<bool> isDeleted;
  final Value<bool> deletedForSender;
  final Value<bool> deletedForReceiver;
  final Value<String?> deletedAt;
  final Value<bool> isEdited;
  final Value<String?> editedAt;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String> syncStatus;
  final Value<int> retryCount;
  final Value<String?> tempId;
  final Value<bool> isSystem;
  final Value<String?> groupId;
  final Value<String?> pollData;
  final Value<bool> isForwarded;
  final Value<String?> forwardedFrom;
  final Value<bool> isPinned;
  final Value<String?> translatedContent;
  final Value<String?> translatedLanguage;
  final Value<int> rowid;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.senderId = const Value.absent(),
    this.receiverId = const Value.absent(),
    this.senderName = const Value.absent(),
    this.senderPic = const Value.absent(),
    this.senderUsername = const Value.absent(),
    this.senderIsVerified = const Value.absent(),
    this.senderVerificationBadge = const Value.absent(),
    this.content = const Value.absent(),
    this.messageType = const Value.absent(),
    this.mediaUrl = const Value.absent(),
    this.mediaData = const Value.absent(),
    this.metadata = const Value.absent(),
    this.linkPreview = const Value.absent(),
    this.reactions = const Value.absent(),
    this.replyToId = const Value.absent(),
    this.replyTo = const Value.absent(),
    this.isRead = const Value.absent(),
    this.readAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedForSender = const Value.absent(),
    this.deletedForReceiver = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.isEdited = const Value.absent(),
    this.editedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.tempId = const Value.absent(),
    this.isSystem = const Value.absent(),
    this.groupId = const Value.absent(),
    this.pollData = const Value.absent(),
    this.isForwarded = const Value.absent(),
    this.forwardedFrom = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.translatedContent = const Value.absent(),
    this.translatedLanguage = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String id,
    required String conversationId,
    required String senderId,
    this.receiverId = const Value.absent(),
    this.senderName = const Value.absent(),
    this.senderPic = const Value.absent(),
    this.senderUsername = const Value.absent(),
    this.senderIsVerified = const Value.absent(),
    this.senderVerificationBadge = const Value.absent(),
    this.content = const Value.absent(),
    this.messageType = const Value.absent(),
    this.mediaUrl = const Value.absent(),
    this.mediaData = const Value.absent(),
    this.metadata = const Value.absent(),
    this.linkPreview = const Value.absent(),
    this.reactions = const Value.absent(),
    this.replyToId = const Value.absent(),
    this.replyTo = const Value.absent(),
    this.isRead = const Value.absent(),
    this.readAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedForSender = const Value.absent(),
    this.deletedForReceiver = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.isEdited = const Value.absent(),
    this.editedAt = const Value.absent(),
    required int createdAt,
    this.updatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.tempId = const Value.absent(),
    this.isSystem = const Value.absent(),
    this.groupId = const Value.absent(),
    this.pollData = const Value.absent(),
    this.isForwarded = const Value.absent(),
    this.forwardedFrom = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.translatedContent = const Value.absent(),
    this.translatedLanguage = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       senderId = Value(senderId),
       createdAt = Value(createdAt);
  static Insertable<Message> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? senderId,
    Expression<String>? receiverId,
    Expression<String>? senderName,
    Expression<String>? senderPic,
    Expression<String>? senderUsername,
    Expression<bool>? senderIsVerified,
    Expression<String>? senderVerificationBadge,
    Expression<String>? content,
    Expression<String>? messageType,
    Expression<String>? mediaUrl,
    Expression<String>? mediaData,
    Expression<String>? metadata,
    Expression<String>? linkPreview,
    Expression<String>? reactions,
    Expression<String>? replyToId,
    Expression<String>? replyTo,
    Expression<bool>? isRead,
    Expression<String>? readAt,
    Expression<String>? status,
    Expression<bool>? isDeleted,
    Expression<bool>? deletedForSender,
    Expression<bool>? deletedForReceiver,
    Expression<String>? deletedAt,
    Expression<bool>? isEdited,
    Expression<String>? editedAt,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? syncStatus,
    Expression<int>? retryCount,
    Expression<String>? tempId,
    Expression<bool>? isSystem,
    Expression<String>? groupId,
    Expression<String>? pollData,
    Expression<bool>? isForwarded,
    Expression<String>? forwardedFrom,
    Expression<bool>? isPinned,
    Expression<String>? translatedContent,
    Expression<String>? translatedLanguage,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (senderId != null) 'sender_id': senderId,
      if (receiverId != null) 'receiver_id': receiverId,
      if (senderName != null) 'sender_name': senderName,
      if (senderPic != null) 'sender_pic': senderPic,
      if (senderUsername != null) 'sender_username': senderUsername,
      if (senderIsVerified != null) 'sender_is_verified': senderIsVerified,
      if (senderVerificationBadge != null)
        'sender_verification_badge': senderVerificationBadge,
      if (content != null) 'content': content,
      if (messageType != null) 'message_type': messageType,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (mediaData != null) 'media_data': mediaData,
      if (metadata != null) 'metadata': metadata,
      if (linkPreview != null) 'link_preview': linkPreview,
      if (reactions != null) 'reactions': reactions,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (replyTo != null) 'reply_to': replyTo,
      if (isRead != null) 'is_read': isRead,
      if (readAt != null) 'read_at': readAt,
      if (status != null) 'status': status,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedForSender != null) 'deleted_for_sender': deletedForSender,
      if (deletedForReceiver != null)
        'deleted_for_receiver': deletedForReceiver,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (isEdited != null) 'is_edited': isEdited,
      if (editedAt != null) 'edited_at': editedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (retryCount != null) 'retry_count': retryCount,
      if (tempId != null) 'temp_id': tempId,
      if (isSystem != null) 'is_system': isSystem,
      if (groupId != null) 'group_id': groupId,
      if (pollData != null) 'poll_data': pollData,
      if (isForwarded != null) 'is_forwarded': isForwarded,
      if (forwardedFrom != null) 'forwarded_from': forwardedFrom,
      if (isPinned != null) 'is_pinned': isPinned,
      if (translatedContent != null) 'translated_content': translatedContent,
      if (translatedLanguage != null) 'translated_language': translatedLanguage,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<String>? senderId,
    Value<String?>? receiverId,
    Value<String>? senderName,
    Value<String?>? senderPic,
    Value<String?>? senderUsername,
    Value<bool>? senderIsVerified,
    Value<String?>? senderVerificationBadge,
    Value<String>? content,
    Value<String>? messageType,
    Value<String?>? mediaUrl,
    Value<String?>? mediaData,
    Value<String?>? metadata,
    Value<String?>? linkPreview,
    Value<String?>? reactions,
    Value<String?>? replyToId,
    Value<String?>? replyTo,
    Value<bool>? isRead,
    Value<String?>? readAt,
    Value<String>? status,
    Value<bool>? isDeleted,
    Value<bool>? deletedForSender,
    Value<bool>? deletedForReceiver,
    Value<String?>? deletedAt,
    Value<bool>? isEdited,
    Value<String?>? editedAt,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String>? syncStatus,
    Value<int>? retryCount,
    Value<String?>? tempId,
    Value<bool>? isSystem,
    Value<String?>? groupId,
    Value<String?>? pollData,
    Value<bool>? isForwarded,
    Value<String?>? forwardedFrom,
    Value<bool>? isPinned,
    Value<String?>? translatedContent,
    Value<String?>? translatedLanguage,
    Value<int>? rowid,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      senderName: senderName ?? this.senderName,
      senderPic: senderPic ?? this.senderPic,
      senderUsername: senderUsername ?? this.senderUsername,
      senderIsVerified: senderIsVerified ?? this.senderIsVerified,
      senderVerificationBadge:
          senderVerificationBadge ?? this.senderVerificationBadge,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaData: mediaData ?? this.mediaData,
      metadata: metadata ?? this.metadata,
      linkPreview: linkPreview ?? this.linkPreview,
      reactions: reactions ?? this.reactions,
      replyToId: replyToId ?? this.replyToId,
      replyTo: replyTo ?? this.replyTo,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      status: status ?? this.status,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedForSender: deletedForSender ?? this.deletedForSender,
      deletedForReceiver: deletedForReceiver ?? this.deletedForReceiver,
      deletedAt: deletedAt ?? this.deletedAt,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      retryCount: retryCount ?? this.retryCount,
      tempId: tempId ?? this.tempId,
      isSystem: isSystem ?? this.isSystem,
      groupId: groupId ?? this.groupId,
      pollData: pollData ?? this.pollData,
      isForwarded: isForwarded ?? this.isForwarded,
      forwardedFrom: forwardedFrom ?? this.forwardedFrom,
      isPinned: isPinned ?? this.isPinned,
      translatedContent: translatedContent ?? this.translatedContent,
      translatedLanguage: translatedLanguage ?? this.translatedLanguage,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<String>(senderId.value);
    }
    if (receiverId.present) {
      map['receiver_id'] = Variable<String>(receiverId.value);
    }
    if (senderName.present) {
      map['sender_name'] = Variable<String>(senderName.value);
    }
    if (senderPic.present) {
      map['sender_pic'] = Variable<String>(senderPic.value);
    }
    if (senderUsername.present) {
      map['sender_username'] = Variable<String>(senderUsername.value);
    }
    if (senderIsVerified.present) {
      map['sender_is_verified'] = Variable<bool>(senderIsVerified.value);
    }
    if (senderVerificationBadge.present) {
      map['sender_verification_badge'] = Variable<String>(
        senderVerificationBadge.value,
      );
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (messageType.present) {
      map['message_type'] = Variable<String>(messageType.value);
    }
    if (mediaUrl.present) {
      map['media_url'] = Variable<String>(mediaUrl.value);
    }
    if (mediaData.present) {
      map['media_data'] = Variable<String>(mediaData.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (linkPreview.present) {
      map['link_preview'] = Variable<String>(linkPreview.value);
    }
    if (reactions.present) {
      map['reactions'] = Variable<String>(reactions.value);
    }
    if (replyToId.present) {
      map['reply_to_id'] = Variable<String>(replyToId.value);
    }
    if (replyTo.present) {
      map['reply_to'] = Variable<String>(replyTo.value);
    }
    if (isRead.present) {
      map['is_read'] = Variable<bool>(isRead.value);
    }
    if (readAt.present) {
      map['read_at'] = Variable<String>(readAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedForSender.present) {
      map['deleted_for_sender'] = Variable<bool>(deletedForSender.value);
    }
    if (deletedForReceiver.present) {
      map['deleted_for_receiver'] = Variable<bool>(deletedForReceiver.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (isEdited.present) {
      map['is_edited'] = Variable<bool>(isEdited.value);
    }
    if (editedAt.present) {
      map['edited_at'] = Variable<String>(editedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (tempId.present) {
      map['temp_id'] = Variable<String>(tempId.value);
    }
    if (isSystem.present) {
      map['is_system'] = Variable<bool>(isSystem.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (pollData.present) {
      map['poll_data'] = Variable<String>(pollData.value);
    }
    if (isForwarded.present) {
      map['is_forwarded'] = Variable<bool>(isForwarded.value);
    }
    if (forwardedFrom.present) {
      map['forwarded_from'] = Variable<String>(forwardedFrom.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (translatedContent.present) {
      map['translated_content'] = Variable<String>(translatedContent.value);
    }
    if (translatedLanguage.present) {
      map['translated_language'] = Variable<String>(translatedLanguage.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderId: $senderId, ')
          ..write('receiverId: $receiverId, ')
          ..write('senderName: $senderName, ')
          ..write('senderPic: $senderPic, ')
          ..write('senderUsername: $senderUsername, ')
          ..write('senderIsVerified: $senderIsVerified, ')
          ..write('senderVerificationBadge: $senderVerificationBadge, ')
          ..write('content: $content, ')
          ..write('messageType: $messageType, ')
          ..write('mediaUrl: $mediaUrl, ')
          ..write('mediaData: $mediaData, ')
          ..write('metadata: $metadata, ')
          ..write('linkPreview: $linkPreview, ')
          ..write('reactions: $reactions, ')
          ..write('replyToId: $replyToId, ')
          ..write('replyTo: $replyTo, ')
          ..write('isRead: $isRead, ')
          ..write('readAt: $readAt, ')
          ..write('status: $status, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedForSender: $deletedForSender, ')
          ..write('deletedForReceiver: $deletedForReceiver, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('isEdited: $isEdited, ')
          ..write('editedAt: $editedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('retryCount: $retryCount, ')
          ..write('tempId: $tempId, ')
          ..write('isSystem: $isSystem, ')
          ..write('groupId: $groupId, ')
          ..write('pollData: $pollData, ')
          ..write('isForwarded: $isForwarded, ')
          ..write('forwardedFrom: $forwardedFrom, ')
          ..write('isPinned: $isPinned, ')
          ..write('translatedContent: $translatedContent, ')
          ..write('translatedLanguage: $translatedLanguage, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingActionsTable extends PendingActions
    with TableInfo<$PendingActionsTable, PendingAction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingActionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _actionTypeMeta = const VerificationMeta(
    'actionType',
  );
  @override
  late final GeneratedColumn<String> actionType = GeneratedColumn<String>(
    'action_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    actionType,
    payload,
    retryCount,
    createdAt,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_actions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingAction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('action_type')) {
      context.handle(
        _actionTypeMeta,
        actionType.isAcceptableOrUnknown(data['action_type']!, _actionTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_actionTypeMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingAction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingAction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      actionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action_type'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $PendingActionsTable createAlias(String alias) {
    return $PendingActionsTable(attachedDatabase, alias);
  }
}

class PendingAction extends DataClass implements Insertable<PendingAction> {
  final int id;
  final String actionType;
  final String payload;
  final int retryCount;
  final int createdAt;
  final String? lastError;
  const PendingAction({
    required this.id,
    required this.actionType,
    required this.payload,
    required this.retryCount,
    required this.createdAt,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['action_type'] = Variable<String>(actionType);
    map['payload'] = Variable<String>(payload);
    map['retry_count'] = Variable<int>(retryCount);
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  PendingActionsCompanion toCompanion(bool nullToAbsent) {
    return PendingActionsCompanion(
      id: Value(id),
      actionType: Value(actionType),
      payload: Value(payload),
      retryCount: Value(retryCount),
      createdAt: Value(createdAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory PendingAction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingAction(
      id: serializer.fromJson<int>(json['id']),
      actionType: serializer.fromJson<String>(json['actionType']),
      payload: serializer.fromJson<String>(json['payload']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'actionType': serializer.toJson<String>(actionType),
      'payload': serializer.toJson<String>(payload),
      'retryCount': serializer.toJson<int>(retryCount),
      'createdAt': serializer.toJson<int>(createdAt),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  PendingAction copyWith({
    int? id,
    String? actionType,
    String? payload,
    int? retryCount,
    int? createdAt,
    Value<String?> lastError = const Value.absent(),
  }) => PendingAction(
    id: id ?? this.id,
    actionType: actionType ?? this.actionType,
    payload: payload ?? this.payload,
    retryCount: retryCount ?? this.retryCount,
    createdAt: createdAt ?? this.createdAt,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  PendingAction copyWithCompanion(PendingActionsCompanion data) {
    return PendingAction(
      id: data.id.present ? data.id.value : this.id,
      actionType: data.actionType.present
          ? data.actionType.value
          : this.actionType,
      payload: data.payload.present ? data.payload.value : this.payload,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingAction(')
          ..write('id: $id, ')
          ..write('actionType: $actionType, ')
          ..write('payload: $payload, ')
          ..write('retryCount: $retryCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, actionType, payload, retryCount, createdAt, lastError);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingAction &&
          other.id == this.id &&
          other.actionType == this.actionType &&
          other.payload == this.payload &&
          other.retryCount == this.retryCount &&
          other.createdAt == this.createdAt &&
          other.lastError == this.lastError);
}

class PendingActionsCompanion extends UpdateCompanion<PendingAction> {
  final Value<int> id;
  final Value<String> actionType;
  final Value<String> payload;
  final Value<int> retryCount;
  final Value<int> createdAt;
  final Value<String?> lastError;
  const PendingActionsCompanion({
    this.id = const Value.absent(),
    this.actionType = const Value.absent(),
    this.payload = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  PendingActionsCompanion.insert({
    this.id = const Value.absent(),
    required String actionType,
    required String payload,
    this.retryCount = const Value.absent(),
    required int createdAt,
    this.lastError = const Value.absent(),
  }) : actionType = Value(actionType),
       payload = Value(payload),
       createdAt = Value(createdAt);
  static Insertable<PendingAction> custom({
    Expression<int>? id,
    Expression<String>? actionType,
    Expression<String>? payload,
    Expression<int>? retryCount,
    Expression<int>? createdAt,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (actionType != null) 'action_type': actionType,
      if (payload != null) 'payload': payload,
      if (retryCount != null) 'retry_count': retryCount,
      if (createdAt != null) 'created_at': createdAt,
      if (lastError != null) 'last_error': lastError,
    });
  }

  PendingActionsCompanion copyWith({
    Value<int>? id,
    Value<String>? actionType,
    Value<String>? payload,
    Value<int>? retryCount,
    Value<int>? createdAt,
    Value<String?>? lastError,
  }) {
    return PendingActionsCompanion(
      id: id ?? this.id,
      actionType: actionType ?? this.actionType,
      payload: payload ?? this.payload,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt ?? this.createdAt,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (actionType.present) {
      map['action_type'] = Variable<String>(actionType.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingActionsCompanion(')
          ..write('id: $id, ')
          ..write('actionType: $actionType, ')
          ..write('payload: $payload, ')
          ..write('retryCount: $retryCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

class $SyncStatesTable extends SyncStates
    with TableInfo<$SyncStatesTable, SyncState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncState(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SyncStatesTable createAlias(String alias) {
    return $SyncStatesTable(attachedDatabase, alias);
  }
}

class SyncState extends DataClass implements Insertable<SyncState> {
  final String key;
  final String value;
  const SyncState({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncStatesCompanion toCompanion(bool nullToAbsent) {
    return SyncStatesCompanion(key: Value(key), value: Value(value));
  }

  factory SyncState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncState(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SyncState copyWith({String? key, String? value}) =>
      SyncState(key: key ?? this.key, value: value ?? this.value);
  SyncState copyWithCompanion(SyncStatesCompanion data) {
    return SyncState(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncState(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncState &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncStatesCompanion extends UpdateCompanion<SyncState> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncStatesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStatesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SyncState> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStatesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncStatesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStatesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ConversationsTable conversations = $ConversationsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $PendingActionsTable pendingActions = $PendingActionsTable(this);
  late final $SyncStatesTable syncStates = $SyncStatesTable(this);
  late final ChatDao chatDao = ChatDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    conversations,
    messages,
    pendingActions,
    syncStates,
  ];
}

typedef $$ConversationsTableCreateCompanionBuilder =
    ConversationsCompanion Function({
      required String id,
      Value<String> type,
      Value<String> name,
      Value<String?> profilePic,
      Value<String?> lastMessage,
      Value<String?> lastMessageType,
      Value<String?> lastMessageSenderId,
      Value<String?> lastMessageTime,
      Value<bool> lastMessageIsRead,
      Value<String?> lastMessageStatus,
      Value<int> unreadCount,
      Value<int> updatedAt,
      Value<bool> isMuted,
      Value<String> status,
      Value<String?> otherUserId,
      Value<String?> otherUserUsername,
      Value<bool> otherUserIsVerified,
      Value<String?> otherUserVerificationBadge,
      Value<String?> initiatorId,
      Value<bool> iBlockedThem,
      Value<bool> theyBlockedMe,
      Value<int> sentMessageCount,
      Value<String?> lastReactionEmoji,
      Value<String?> lastReactionAt,
      Value<String?> lastReactionUserId,
      Value<String?> lastReactionMessageContent,
      Value<String> syncStatus,
      Value<String?> lastSyncedAt,
      Value<int> rowid,
    });
typedef $$ConversationsTableUpdateCompanionBuilder =
    ConversationsCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<String> name,
      Value<String?> profilePic,
      Value<String?> lastMessage,
      Value<String?> lastMessageType,
      Value<String?> lastMessageSenderId,
      Value<String?> lastMessageTime,
      Value<bool> lastMessageIsRead,
      Value<String?> lastMessageStatus,
      Value<int> unreadCount,
      Value<int> updatedAt,
      Value<bool> isMuted,
      Value<String> status,
      Value<String?> otherUserId,
      Value<String?> otherUserUsername,
      Value<bool> otherUserIsVerified,
      Value<String?> otherUserVerificationBadge,
      Value<String?> initiatorId,
      Value<bool> iBlockedThem,
      Value<bool> theyBlockedMe,
      Value<int> sentMessageCount,
      Value<String?> lastReactionEmoji,
      Value<String?> lastReactionAt,
      Value<String?> lastReactionUserId,
      Value<String?> lastReactionMessageContent,
      Value<String> syncStatus,
      Value<String?> lastSyncedAt,
      Value<int> rowid,
    });

class $$ConversationsTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profilePic => $composableBuilder(
    column: $table.profilePic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMessage => $composableBuilder(
    column: $table.lastMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMessageType => $composableBuilder(
    column: $table.lastMessageType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMessageSenderId => $composableBuilder(
    column: $table.lastMessageSenderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMessageTime => $composableBuilder(
    column: $table.lastMessageTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get lastMessageIsRead => $composableBuilder(
    column: $table.lastMessageIsRead,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMessageStatus => $composableBuilder(
    column: $table.lastMessageStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMuted => $composableBuilder(
    column: $table.isMuted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get otherUserId => $composableBuilder(
    column: $table.otherUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get otherUserUsername => $composableBuilder(
    column: $table.otherUserUsername,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get otherUserIsVerified => $composableBuilder(
    column: $table.otherUserIsVerified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get otherUserVerificationBadge => $composableBuilder(
    column: $table.otherUserVerificationBadge,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get initiatorId => $composableBuilder(
    column: $table.initiatorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get iBlockedThem => $composableBuilder(
    column: $table.iBlockedThem,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get theyBlockedMe => $composableBuilder(
    column: $table.theyBlockedMe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sentMessageCount => $composableBuilder(
    column: $table.sentMessageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastReactionEmoji => $composableBuilder(
    column: $table.lastReactionEmoji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastReactionAt => $composableBuilder(
    column: $table.lastReactionAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastReactionUserId => $composableBuilder(
    column: $table.lastReactionUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastReactionMessageContent => $composableBuilder(
    column: $table.lastReactionMessageContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConversationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profilePic => $composableBuilder(
    column: $table.profilePic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessage => $composableBuilder(
    column: $table.lastMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessageType => $composableBuilder(
    column: $table.lastMessageType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessageSenderId => $composableBuilder(
    column: $table.lastMessageSenderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessageTime => $composableBuilder(
    column: $table.lastMessageTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get lastMessageIsRead => $composableBuilder(
    column: $table.lastMessageIsRead,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessageStatus => $composableBuilder(
    column: $table.lastMessageStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMuted => $composableBuilder(
    column: $table.isMuted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get otherUserId => $composableBuilder(
    column: $table.otherUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get otherUserUsername => $composableBuilder(
    column: $table.otherUserUsername,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get otherUserIsVerified => $composableBuilder(
    column: $table.otherUserIsVerified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get otherUserVerificationBadge => $composableBuilder(
    column: $table.otherUserVerificationBadge,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get initiatorId => $composableBuilder(
    column: $table.initiatorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get iBlockedThem => $composableBuilder(
    column: $table.iBlockedThem,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get theyBlockedMe => $composableBuilder(
    column: $table.theyBlockedMe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sentMessageCount => $composableBuilder(
    column: $table.sentMessageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastReactionEmoji => $composableBuilder(
    column: $table.lastReactionEmoji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastReactionAt => $composableBuilder(
    column: $table.lastReactionAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastReactionUserId => $composableBuilder(
    column: $table.lastReactionUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastReactionMessageContent => $composableBuilder(
    column: $table.lastReactionMessageContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConversationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get profilePic => $composableBuilder(
    column: $table.profilePic,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastMessage => $composableBuilder(
    column: $table.lastMessage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastMessageType => $composableBuilder(
    column: $table.lastMessageType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastMessageSenderId => $composableBuilder(
    column: $table.lastMessageSenderId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastMessageTime => $composableBuilder(
    column: $table.lastMessageTime,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get lastMessageIsRead => $composableBuilder(
    column: $table.lastMessageIsRead,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastMessageStatus => $composableBuilder(
    column: $table.lastMessageStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isMuted =>
      $composableBuilder(column: $table.isMuted, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get otherUserId => $composableBuilder(
    column: $table.otherUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get otherUserUsername => $composableBuilder(
    column: $table.otherUserUsername,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get otherUserIsVerified => $composableBuilder(
    column: $table.otherUserIsVerified,
    builder: (column) => column,
  );

  GeneratedColumn<String> get otherUserVerificationBadge => $composableBuilder(
    column: $table.otherUserVerificationBadge,
    builder: (column) => column,
  );

  GeneratedColumn<String> get initiatorId => $composableBuilder(
    column: $table.initiatorId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get iBlockedThem => $composableBuilder(
    column: $table.iBlockedThem,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get theyBlockedMe => $composableBuilder(
    column: $table.theyBlockedMe,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sentMessageCount => $composableBuilder(
    column: $table.sentMessageCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastReactionEmoji => $composableBuilder(
    column: $table.lastReactionEmoji,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastReactionAt => $composableBuilder(
    column: $table.lastReactionAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastReactionUserId => $composableBuilder(
    column: $table.lastReactionUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastReactionMessageContent => $composableBuilder(
    column: $table.lastReactionMessageContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );
}

class $$ConversationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConversationsTable,
          Conversation,
          $$ConversationsTableFilterComposer,
          $$ConversationsTableOrderingComposer,
          $$ConversationsTableAnnotationComposer,
          $$ConversationsTableCreateCompanionBuilder,
          $$ConversationsTableUpdateCompanionBuilder,
          (
            Conversation,
            BaseReferences<_$AppDatabase, $ConversationsTable, Conversation>,
          ),
          Conversation,
          PrefetchHooks Function()
        > {
  $$ConversationsTableTableManager(_$AppDatabase db, $ConversationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> profilePic = const Value.absent(),
                Value<String?> lastMessage = const Value.absent(),
                Value<String?> lastMessageType = const Value.absent(),
                Value<String?> lastMessageSenderId = const Value.absent(),
                Value<String?> lastMessageTime = const Value.absent(),
                Value<bool> lastMessageIsRead = const Value.absent(),
                Value<String?> lastMessageStatus = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<bool> isMuted = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> otherUserId = const Value.absent(),
                Value<String?> otherUserUsername = const Value.absent(),
                Value<bool> otherUserIsVerified = const Value.absent(),
                Value<String?> otherUserVerificationBadge =
                    const Value.absent(),
                Value<String?> initiatorId = const Value.absent(),
                Value<bool> iBlockedThem = const Value.absent(),
                Value<bool> theyBlockedMe = const Value.absent(),
                Value<int> sentMessageCount = const Value.absent(),
                Value<String?> lastReactionEmoji = const Value.absent(),
                Value<String?> lastReactionAt = const Value.absent(),
                Value<String?> lastReactionUserId = const Value.absent(),
                Value<String?> lastReactionMessageContent =
                    const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<String?> lastSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion(
                id: id,
                type: type,
                name: name,
                profilePic: profilePic,
                lastMessage: lastMessage,
                lastMessageType: lastMessageType,
                lastMessageSenderId: lastMessageSenderId,
                lastMessageTime: lastMessageTime,
                lastMessageIsRead: lastMessageIsRead,
                lastMessageStatus: lastMessageStatus,
                unreadCount: unreadCount,
                updatedAt: updatedAt,
                isMuted: isMuted,
                status: status,
                otherUserId: otherUserId,
                otherUserUsername: otherUserUsername,
                otherUserIsVerified: otherUserIsVerified,
                otherUserVerificationBadge: otherUserVerificationBadge,
                initiatorId: initiatorId,
                iBlockedThem: iBlockedThem,
                theyBlockedMe: theyBlockedMe,
                sentMessageCount: sentMessageCount,
                lastReactionEmoji: lastReactionEmoji,
                lastReactionAt: lastReactionAt,
                lastReactionUserId: lastReactionUserId,
                lastReactionMessageContent: lastReactionMessageContent,
                syncStatus: syncStatus,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> type = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> profilePic = const Value.absent(),
                Value<String?> lastMessage = const Value.absent(),
                Value<String?> lastMessageType = const Value.absent(),
                Value<String?> lastMessageSenderId = const Value.absent(),
                Value<String?> lastMessageTime = const Value.absent(),
                Value<bool> lastMessageIsRead = const Value.absent(),
                Value<String?> lastMessageStatus = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<bool> isMuted = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> otherUserId = const Value.absent(),
                Value<String?> otherUserUsername = const Value.absent(),
                Value<bool> otherUserIsVerified = const Value.absent(),
                Value<String?> otherUserVerificationBadge =
                    const Value.absent(),
                Value<String?> initiatorId = const Value.absent(),
                Value<bool> iBlockedThem = const Value.absent(),
                Value<bool> theyBlockedMe = const Value.absent(),
                Value<int> sentMessageCount = const Value.absent(),
                Value<String?> lastReactionEmoji = const Value.absent(),
                Value<String?> lastReactionAt = const Value.absent(),
                Value<String?> lastReactionUserId = const Value.absent(),
                Value<String?> lastReactionMessageContent =
                    const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<String?> lastSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion.insert(
                id: id,
                type: type,
                name: name,
                profilePic: profilePic,
                lastMessage: lastMessage,
                lastMessageType: lastMessageType,
                lastMessageSenderId: lastMessageSenderId,
                lastMessageTime: lastMessageTime,
                lastMessageIsRead: lastMessageIsRead,
                lastMessageStatus: lastMessageStatus,
                unreadCount: unreadCount,
                updatedAt: updatedAt,
                isMuted: isMuted,
                status: status,
                otherUserId: otherUserId,
                otherUserUsername: otherUserUsername,
                otherUserIsVerified: otherUserIsVerified,
                otherUserVerificationBadge: otherUserVerificationBadge,
                initiatorId: initiatorId,
                iBlockedThem: iBlockedThem,
                theyBlockedMe: theyBlockedMe,
                sentMessageCount: sentMessageCount,
                lastReactionEmoji: lastReactionEmoji,
                lastReactionAt: lastReactionAt,
                lastReactionUserId: lastReactionUserId,
                lastReactionMessageContent: lastReactionMessageContent,
                syncStatus: syncStatus,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConversationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConversationsTable,
      Conversation,
      $$ConversationsTableFilterComposer,
      $$ConversationsTableOrderingComposer,
      $$ConversationsTableAnnotationComposer,
      $$ConversationsTableCreateCompanionBuilder,
      $$ConversationsTableUpdateCompanionBuilder,
      (
        Conversation,
        BaseReferences<_$AppDatabase, $ConversationsTable, Conversation>,
      ),
      Conversation,
      PrefetchHooks Function()
    >;
typedef $$MessagesTableCreateCompanionBuilder =
    MessagesCompanion Function({
      required String id,
      required String conversationId,
      required String senderId,
      Value<String?> receiverId,
      Value<String> senderName,
      Value<String?> senderPic,
      Value<String?> senderUsername,
      Value<bool> senderIsVerified,
      Value<String?> senderVerificationBadge,
      Value<String> content,
      Value<String> messageType,
      Value<String?> mediaUrl,
      Value<String?> mediaData,
      Value<String?> metadata,
      Value<String?> linkPreview,
      Value<String?> reactions,
      Value<String?> replyToId,
      Value<String?> replyTo,
      Value<bool> isRead,
      Value<String?> readAt,
      Value<String> status,
      Value<bool> isDeleted,
      Value<bool> deletedForSender,
      Value<bool> deletedForReceiver,
      Value<String?> deletedAt,
      Value<bool> isEdited,
      Value<String?> editedAt,
      required int createdAt,
      Value<int> updatedAt,
      Value<String> syncStatus,
      Value<int> retryCount,
      Value<String?> tempId,
      Value<bool> isSystem,
      Value<String?> groupId,
      Value<String?> pollData,
      Value<bool> isForwarded,
      Value<String?> forwardedFrom,
      Value<bool> isPinned,
      Value<String?> translatedContent,
      Value<String?> translatedLanguage,
      Value<int> rowid,
    });
typedef $$MessagesTableUpdateCompanionBuilder =
    MessagesCompanion Function({
      Value<String> id,
      Value<String> conversationId,
      Value<String> senderId,
      Value<String?> receiverId,
      Value<String> senderName,
      Value<String?> senderPic,
      Value<String?> senderUsername,
      Value<bool> senderIsVerified,
      Value<String?> senderVerificationBadge,
      Value<String> content,
      Value<String> messageType,
      Value<String?> mediaUrl,
      Value<String?> mediaData,
      Value<String?> metadata,
      Value<String?> linkPreview,
      Value<String?> reactions,
      Value<String?> replyToId,
      Value<String?> replyTo,
      Value<bool> isRead,
      Value<String?> readAt,
      Value<String> status,
      Value<bool> isDeleted,
      Value<bool> deletedForSender,
      Value<bool> deletedForReceiver,
      Value<String?> deletedAt,
      Value<bool> isEdited,
      Value<String?> editedAt,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String> syncStatus,
      Value<int> retryCount,
      Value<String?> tempId,
      Value<bool> isSystem,
      Value<String?> groupId,
      Value<String?> pollData,
      Value<bool> isForwarded,
      Value<String?> forwardedFrom,
      Value<bool> isPinned,
      Value<String?> translatedContent,
      Value<String?> translatedLanguage,
      Value<int> rowid,
    });

class $$MessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiverId => $composableBuilder(
    column: $table.receiverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderName => $composableBuilder(
    column: $table.senderName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderPic => $composableBuilder(
    column: $table.senderPic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderUsername => $composableBuilder(
    column: $table.senderUsername,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get senderIsVerified => $composableBuilder(
    column: $table.senderIsVerified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderVerificationBadge => $composableBuilder(
    column: $table.senderVerificationBadge,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageType => $composableBuilder(
    column: $table.messageType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaUrl => $composableBuilder(
    column: $table.mediaUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaData => $composableBuilder(
    column: $table.mediaData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkPreview => $composableBuilder(
    column: $table.linkPreview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reactions => $composableBuilder(
    column: $table.reactions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replyToId => $composableBuilder(
    column: $table.replyToId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replyTo => $composableBuilder(
    column: $table.replyTo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRead => $composableBuilder(
    column: $table.isRead,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deletedForSender => $composableBuilder(
    column: $table.deletedForSender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deletedForReceiver => $composableBuilder(
    column: $table.deletedForReceiver,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEdited => $composableBuilder(
    column: $table.isEdited,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get editedAt => $composableBuilder(
    column: $table.editedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tempId => $composableBuilder(
    column: $table.tempId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSystem => $composableBuilder(
    column: $table.isSystem,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pollData => $composableBuilder(
    column: $table.pollData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isForwarded => $composableBuilder(
    column: $table.isForwarded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get forwardedFrom => $composableBuilder(
    column: $table.forwardedFrom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translatedContent => $composableBuilder(
    column: $table.translatedContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translatedLanguage => $composableBuilder(
    column: $table.translatedLanguage,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiverId => $composableBuilder(
    column: $table.receiverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderName => $composableBuilder(
    column: $table.senderName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderPic => $composableBuilder(
    column: $table.senderPic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderUsername => $composableBuilder(
    column: $table.senderUsername,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get senderIsVerified => $composableBuilder(
    column: $table.senderIsVerified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderVerificationBadge => $composableBuilder(
    column: $table.senderVerificationBadge,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageType => $composableBuilder(
    column: $table.messageType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaUrl => $composableBuilder(
    column: $table.mediaUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaData => $composableBuilder(
    column: $table.mediaData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkPreview => $composableBuilder(
    column: $table.linkPreview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reactions => $composableBuilder(
    column: $table.reactions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replyToId => $composableBuilder(
    column: $table.replyToId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replyTo => $composableBuilder(
    column: $table.replyTo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRead => $composableBuilder(
    column: $table.isRead,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deletedForSender => $composableBuilder(
    column: $table.deletedForSender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deletedForReceiver => $composableBuilder(
    column: $table.deletedForReceiver,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEdited => $composableBuilder(
    column: $table.isEdited,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get editedAt => $composableBuilder(
    column: $table.editedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tempId => $composableBuilder(
    column: $table.tempId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSystem => $composableBuilder(
    column: $table.isSystem,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pollData => $composableBuilder(
    column: $table.pollData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isForwarded => $composableBuilder(
    column: $table.isForwarded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get forwardedFrom => $composableBuilder(
    column: $table.forwardedFrom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translatedContent => $composableBuilder(
    column: $table.translatedContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translatedLanguage => $composableBuilder(
    column: $table.translatedLanguage,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<String> get receiverId => $composableBuilder(
    column: $table.receiverId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get senderName => $composableBuilder(
    column: $table.senderName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get senderPic =>
      $composableBuilder(column: $table.senderPic, builder: (column) => column);

  GeneratedColumn<String> get senderUsername => $composableBuilder(
    column: $table.senderUsername,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get senderIsVerified => $composableBuilder(
    column: $table.senderIsVerified,
    builder: (column) => column,
  );

  GeneratedColumn<String> get senderVerificationBadge => $composableBuilder(
    column: $table.senderVerificationBadge,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get messageType => $composableBuilder(
    column: $table.messageType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mediaUrl =>
      $composableBuilder(column: $table.mediaUrl, builder: (column) => column);

  GeneratedColumn<String> get mediaData =>
      $composableBuilder(column: $table.mediaData, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  GeneratedColumn<String> get linkPreview => $composableBuilder(
    column: $table.linkPreview,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reactions =>
      $composableBuilder(column: $table.reactions, builder: (column) => column);

  GeneratedColumn<String> get replyToId =>
      $composableBuilder(column: $table.replyToId, builder: (column) => column);

  GeneratedColumn<String> get replyTo =>
      $composableBuilder(column: $table.replyTo, builder: (column) => column);

  GeneratedColumn<bool> get isRead =>
      $composableBuilder(column: $table.isRead, builder: (column) => column);

  GeneratedColumn<String> get readAt =>
      $composableBuilder(column: $table.readAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<bool> get deletedForSender => $composableBuilder(
    column: $table.deletedForSender,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get deletedForReceiver => $composableBuilder(
    column: $table.deletedForReceiver,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get isEdited =>
      $composableBuilder(column: $table.isEdited, builder: (column) => column);

  GeneratedColumn<String> get editedAt =>
      $composableBuilder(column: $table.editedAt, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tempId =>
      $composableBuilder(column: $table.tempId, builder: (column) => column);

  GeneratedColumn<bool> get isSystem =>
      $composableBuilder(column: $table.isSystem, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get pollData =>
      $composableBuilder(column: $table.pollData, builder: (column) => column);

  GeneratedColumn<bool> get isForwarded => $composableBuilder(
    column: $table.isForwarded,
    builder: (column) => column,
  );

  GeneratedColumn<String> get forwardedFrom => $composableBuilder(
    column: $table.forwardedFrom,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<String> get translatedContent => $composableBuilder(
    column: $table.translatedContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get translatedLanguage => $composableBuilder(
    column: $table.translatedLanguage,
    builder: (column) => column,
  );
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessagesTable,
          Message,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (Message, BaseReferences<_$AppDatabase, $MessagesTable, Message>),
          Message,
          PrefetchHooks Function()
        > {
  $$MessagesTableTableManager(_$AppDatabase db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> senderId = const Value.absent(),
                Value<String?> receiverId = const Value.absent(),
                Value<String> senderName = const Value.absent(),
                Value<String?> senderPic = const Value.absent(),
                Value<String?> senderUsername = const Value.absent(),
                Value<bool> senderIsVerified = const Value.absent(),
                Value<String?> senderVerificationBadge = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> messageType = const Value.absent(),
                Value<String?> mediaUrl = const Value.absent(),
                Value<String?> mediaData = const Value.absent(),
                Value<String?> metadata = const Value.absent(),
                Value<String?> linkPreview = const Value.absent(),
                Value<String?> reactions = const Value.absent(),
                Value<String?> replyToId = const Value.absent(),
                Value<String?> replyTo = const Value.absent(),
                Value<bool> isRead = const Value.absent(),
                Value<String?> readAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<bool> deletedForSender = const Value.absent(),
                Value<bool> deletedForReceiver = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<bool> isEdited = const Value.absent(),
                Value<String?> editedAt = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> tempId = const Value.absent(),
                Value<bool> isSystem = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<String?> pollData = const Value.absent(),
                Value<bool> isForwarded = const Value.absent(),
                Value<String?> forwardedFrom = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<String?> translatedContent = const Value.absent(),
                Value<String?> translatedLanguage = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                conversationId: conversationId,
                senderId: senderId,
                receiverId: receiverId,
                senderName: senderName,
                senderPic: senderPic,
                senderUsername: senderUsername,
                senderIsVerified: senderIsVerified,
                senderVerificationBadge: senderVerificationBadge,
                content: content,
                messageType: messageType,
                mediaUrl: mediaUrl,
                mediaData: mediaData,
                metadata: metadata,
                linkPreview: linkPreview,
                reactions: reactions,
                replyToId: replyToId,
                replyTo: replyTo,
                isRead: isRead,
                readAt: readAt,
                status: status,
                isDeleted: isDeleted,
                deletedForSender: deletedForSender,
                deletedForReceiver: deletedForReceiver,
                deletedAt: deletedAt,
                isEdited: isEdited,
                editedAt: editedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
                retryCount: retryCount,
                tempId: tempId,
                isSystem: isSystem,
                groupId: groupId,
                pollData: pollData,
                isForwarded: isForwarded,
                forwardedFrom: forwardedFrom,
                isPinned: isPinned,
                translatedContent: translatedContent,
                translatedLanguage: translatedLanguage,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String conversationId,
                required String senderId,
                Value<String?> receiverId = const Value.absent(),
                Value<String> senderName = const Value.absent(),
                Value<String?> senderPic = const Value.absent(),
                Value<String?> senderUsername = const Value.absent(),
                Value<bool> senderIsVerified = const Value.absent(),
                Value<String?> senderVerificationBadge = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> messageType = const Value.absent(),
                Value<String?> mediaUrl = const Value.absent(),
                Value<String?> mediaData = const Value.absent(),
                Value<String?> metadata = const Value.absent(),
                Value<String?> linkPreview = const Value.absent(),
                Value<String?> reactions = const Value.absent(),
                Value<String?> replyToId = const Value.absent(),
                Value<String?> replyTo = const Value.absent(),
                Value<bool> isRead = const Value.absent(),
                Value<String?> readAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<bool> deletedForSender = const Value.absent(),
                Value<bool> deletedForReceiver = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<bool> isEdited = const Value.absent(),
                Value<String?> editedAt = const Value.absent(),
                required int createdAt,
                Value<int> updatedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> tempId = const Value.absent(),
                Value<bool> isSystem = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<String?> pollData = const Value.absent(),
                Value<bool> isForwarded = const Value.absent(),
                Value<String?> forwardedFrom = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<String?> translatedContent = const Value.absent(),
                Value<String?> translatedLanguage = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                conversationId: conversationId,
                senderId: senderId,
                receiverId: receiverId,
                senderName: senderName,
                senderPic: senderPic,
                senderUsername: senderUsername,
                senderIsVerified: senderIsVerified,
                senderVerificationBadge: senderVerificationBadge,
                content: content,
                messageType: messageType,
                mediaUrl: mediaUrl,
                mediaData: mediaData,
                metadata: metadata,
                linkPreview: linkPreview,
                reactions: reactions,
                replyToId: replyToId,
                replyTo: replyTo,
                isRead: isRead,
                readAt: readAt,
                status: status,
                isDeleted: isDeleted,
                deletedForSender: deletedForSender,
                deletedForReceiver: deletedForReceiver,
                deletedAt: deletedAt,
                isEdited: isEdited,
                editedAt: editedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
                retryCount: retryCount,
                tempId: tempId,
                isSystem: isSystem,
                groupId: groupId,
                pollData: pollData,
                isForwarded: isForwarded,
                forwardedFrom: forwardedFrom,
                isPinned: isPinned,
                translatedContent: translatedContent,
                translatedLanguage: translatedLanguage,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessagesTable,
      Message,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (Message, BaseReferences<_$AppDatabase, $MessagesTable, Message>),
      Message,
      PrefetchHooks Function()
    >;
typedef $$PendingActionsTableCreateCompanionBuilder =
    PendingActionsCompanion Function({
      Value<int> id,
      required String actionType,
      required String payload,
      Value<int> retryCount,
      required int createdAt,
      Value<String?> lastError,
    });
typedef $$PendingActionsTableUpdateCompanionBuilder =
    PendingActionsCompanion Function({
      Value<int> id,
      Value<String> actionType,
      Value<String> payload,
      Value<int> retryCount,
      Value<int> createdAt,
      Value<String?> lastError,
    });

class $$PendingActionsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingActionsTable> {
  $$PendingActionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingActionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingActionsTable> {
  $$PendingActionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingActionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingActionsTable> {
  $$PendingActionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$PendingActionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingActionsTable,
          PendingAction,
          $$PendingActionsTableFilterComposer,
          $$PendingActionsTableOrderingComposer,
          $$PendingActionsTableAnnotationComposer,
          $$PendingActionsTableCreateCompanionBuilder,
          $$PendingActionsTableUpdateCompanionBuilder,
          (
            PendingAction,
            BaseReferences<_$AppDatabase, $PendingActionsTable, PendingAction>,
          ),
          PendingAction,
          PrefetchHooks Function()
        > {
  $$PendingActionsTableTableManager(
    _$AppDatabase db,
    $PendingActionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingActionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingActionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingActionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> actionType = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => PendingActionsCompanion(
                id: id,
                actionType: actionType,
                payload: payload,
                retryCount: retryCount,
                createdAt: createdAt,
                lastError: lastError,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String actionType,
                required String payload,
                Value<int> retryCount = const Value.absent(),
                required int createdAt,
                Value<String?> lastError = const Value.absent(),
              }) => PendingActionsCompanion.insert(
                id: id,
                actionType: actionType,
                payload: payload,
                retryCount: retryCount,
                createdAt: createdAt,
                lastError: lastError,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingActionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingActionsTable,
      PendingAction,
      $$PendingActionsTableFilterComposer,
      $$PendingActionsTableOrderingComposer,
      $$PendingActionsTableAnnotationComposer,
      $$PendingActionsTableCreateCompanionBuilder,
      $$PendingActionsTableUpdateCompanionBuilder,
      (
        PendingAction,
        BaseReferences<_$AppDatabase, $PendingActionsTable, PendingAction>,
      ),
      PendingAction,
      PrefetchHooks Function()
    >;
typedef $$SyncStatesTableCreateCompanionBuilder =
    SyncStatesCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SyncStatesTableUpdateCompanionBuilder =
    SyncStatesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SyncStatesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SyncStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStatesTable,
          SyncState,
          $$SyncStatesTableFilterComposer,
          $$SyncStatesTableOrderingComposer,
          $$SyncStatesTableAnnotationComposer,
          $$SyncStatesTableCreateCompanionBuilder,
          $$SyncStatesTableUpdateCompanionBuilder,
          (
            SyncState,
            BaseReferences<_$AppDatabase, $SyncStatesTable, SyncState>,
          ),
          SyncState,
          PrefetchHooks Function()
        > {
  $$SyncStatesTableTableManager(_$AppDatabase db, $SyncStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStatesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SyncStatesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStatesTable,
      SyncState,
      $$SyncStatesTableFilterComposer,
      $$SyncStatesTableOrderingComposer,
      $$SyncStatesTableAnnotationComposer,
      $$SyncStatesTableCreateCompanionBuilder,
      $$SyncStatesTableUpdateCompanionBuilder,
      (SyncState, BaseReferences<_$AppDatabase, $SyncStatesTable, SyncState>),
      SyncState,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ConversationsTableTableManager get conversations =>
      $$ConversationsTableTableManager(_db, _db.conversations);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$PendingActionsTableTableManager get pendingActions =>
      $$PendingActionsTableTableManager(_db, _db.pendingActions);
  $$SyncStatesTableTableManager get syncStates =>
      $$SyncStatesTableTableManager(_db, _db.syncStates);
}
