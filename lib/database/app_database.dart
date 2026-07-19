import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// ── Conversations table ────────────────────────────────────────────────────────
class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get type => text().withDefault(const Constant('private'))(); // private | group | channel
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get profilePic => text().nullable()();
  TextColumn get lastMessage => text().nullable()();
  TextColumn get lastMessageType => text().nullable()();
  TextColumn get lastMessageSenderId => text().nullable()();
  TextColumn get lastMessageTime => text().nullable()();
  BoolColumn get lastMessageIsRead => boolean().withDefault(const Constant(false))();
  TextColumn get lastMessageStatus => text().nullable()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  BoolColumn get isMuted => boolean().withDefault(const Constant(false))();
  TextColumn get status => text().withDefault(const Constant('active'))(); // active | request_pending | blocked
  TextColumn get otherUserId => text().nullable()();
  TextColumn get otherUserUsername => text().nullable()();
  BoolColumn get otherUserIsVerified => boolean().withDefault(const Constant(false))();
  TextColumn get otherUserVerificationBadge => text().nullable()();
  TextColumn get initiatorId => text().nullable()();
  BoolColumn get iBlockedThem => boolean().withDefault(const Constant(false))();
  BoolColumn get theyBlockedMe => boolean().withDefault(const Constant(false))();
  IntColumn get sentMessageCount => integer().withDefault(const Constant(0))();
  TextColumn get lastReactionEmoji => text().nullable()();
  TextColumn get lastReactionAt => text().nullable()();
  TextColumn get lastReactionUserId => text().nullable()();
  TextColumn get lastReactionMessageContent => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();
  TextColumn get lastSyncedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ── Messages table ─────────────────────────────────────────────────────────────
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text()();
  TextColumn get senderId => text()();
  TextColumn get receiverId => text().nullable()();
  TextColumn get senderName => text().withDefault(const Constant(''))();
  TextColumn get senderPic => text().nullable()();
  TextColumn get senderUsername => text().nullable()();
  BoolColumn get senderIsVerified => boolean().withDefault(const Constant(false))();
  TextColumn get senderVerificationBadge => text().nullable()();
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get messageType => text().withDefault(const Constant('text'))();
  // text | image | video | audio | voice | file | poll | giphy_gif | giphy_sticker
  // shared_post | shared_topic | system | deleted
  TextColumn get mediaUrl => text().nullable()();
  TextColumn get mediaData => text().nullable()(); // JSON: {width, height, aspectRatio, staticUrl, ...}
  TextColumn get metadata => text().nullable()(); // JSON: shared post/topic data
  TextColumn get linkPreview => text().nullable()(); // JSON: {title, description, image, url}
  TextColumn get reactions => text().nullable()(); // JSON array
  TextColumn get replyToId => text().nullable()();
  TextColumn get replyTo => text().nullable()(); // JSON snapshot of replied message
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  TextColumn get readAt => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  // pending | sent | delivered | read | failed
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedForSender => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedForReceiver => boolean().withDefault(const Constant(false))();
  TextColumn get deletedAt => text().nullable()();
  BoolColumn get isEdited => boolean().withDefault(const Constant(false))();
  TextColumn get editedAt => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending_sync'))();
  // pending_sync | synced | sync_failed
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get tempId => text().nullable()();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  TextColumn get groupId => text().nullable()();
  TextColumn get pollData => text().nullable()(); // JSON poll data
  BoolColumn get isForwarded => boolean().withDefault(const Constant(false))();
  TextColumn get forwardedFrom => text().nullable()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  TextColumn get translatedContent => text().nullable()();
  TextColumn get translatedLanguage => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ── PendingActions table (offline queue) ──────────────────────────────────────
class PendingActions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get actionType => text()();
  // send_message | mark_read | delete_message | add_reaction | remove_reaction | send_group_message
  TextColumn get payload => text()(); // JSON
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  TextColumn get lastError => text().nullable()();
}

// ── SyncState table ────────────────────────────────────────────────────────────
class SyncStates extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// ── DAO ───────────────────────────────────────────────────────────────────────
@DriftAccessor(tables: [Conversations, Messages, PendingActions, SyncStates])
class ChatDao extends DatabaseAccessor<AppDatabase> with _$ChatDaoMixin {
  ChatDao(super.db);

  // ── Conversations ───────────────────────────────────────────────────────────
  Stream<List<Conversation>> watchConversations() =>
      (select(conversations)..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();

  Future<List<Conversation>> getConversations() =>
      (select(conversations)..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();

  Future<Conversation?> getConversation(String id) =>
      (select(conversations)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertConversation(ConversationsCompanion c) =>
      into(conversations).insertOnConflictUpdate(c);

  Future<void> bulkUpsertConversations(List<ConversationsCompanion> list) =>
      batch((b) => b.insertAllOnConflictUpdate(conversations, list));

  Future<int> markConversationRead(String id) =>
      (update(conversations)..where((t) => t.id.equals(id)))
          .write(const ConversationsCompanion(unreadCount: Value(0)));

  Future<int> deleteConversationRow(String id) =>
      (delete(conversations)..where((t) => t.id.equals(id))).go();

  // ── Messages ────────────────────────────────────────────────────────────────
  Stream<List<Message>> watchMessages(String conversationId) =>
      (select(messages)
        ..where((t) =>
            t.conversationId.equals(conversationId) & t.isDeleted.equals(false))
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  Future<List<Message>> getMessages(String conversationId,
          {int limit = 50, int offset = 0}) =>
      (select(messages)
        ..where((t) =>
            t.conversationId.equals(conversationId) & t.isDeleted.equals(false))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
        ..limit(limit, offset: offset))
          .get();

  Future<Message?> getMessage(String id) =>
      (select(messages)..where((t) => t.id.equals(id) | t.tempId.equals(id)))
          .getSingleOrNull();

  Future<void> insertMessage(MessagesCompanion m) =>
      into(messages).insertOnConflictUpdate(m);

  Future<void> bulkInsertMessages(List<MessagesCompanion> list) =>
      batch((b) => b.insertAllOnConflictUpdate(messages, list));

  Future<int> markMessageRead(String id) =>
      (update(messages)..where((t) => t.id.equals(id)))
          .write(const MessagesCompanion(isRead: Value(true), status: Value('read')));

  Future<void> markAllMessagesRead(String conversationId, String currentUserId) async {
    final readAt = DateTime.now().toIso8601String();
    await (update(messages)
          ..where((t) =>
              t.conversationId.equals(conversationId) &
              t.senderId.isNotValue(currentUserId) &
              t.isRead.equals(false)))
        .write(MessagesCompanion(
            isRead: const Value(true),
            readAt: Value(readAt),
            status: const Value('read')));
  }

  Future<int> softDeleteMessage(String id) =>
      (update(messages)
            ..where((t) => t.id.equals(id) | t.tempId.equals(id)))
          .write(MessagesCompanion(
              isDeleted: const Value(true),
              deletedAt: Value(DateTime.now().toIso8601String())));

  Future<int> hardDeleteMessage(String id) =>
      (delete(messages)..where((t) => t.id.equals(id) | t.tempId.equals(id)))
          .go();

  Future<int> updateMessageStatus(String id, String status, String syncStatus) =>
      (update(messages)..where((t) => t.id.equals(id) | t.tempId.equals(id)))
          .write(MessagesCompanion(
              status: Value(status), syncStatus: Value(syncStatus)));

  Future<void> updateMessageReactions(String id, String reactionsJson) async {
    await (update(messages)..where((t) => t.id.equals(id)))
        .write(MessagesCompanion(reactions: Value(reactionsJson)));
  }

  Future<void> updateMessageContent(String id, String content) async {
    await (update(messages)..where((t) => t.id.equals(id)))
        .write(MessagesCompanion(
            content: Value(content),
            isEdited: const Value(true),
            editedAt: Value(DateTime.now().toIso8601String())));
  }

  Future<void> replaceLocalMessage(String localId, MessagesCompanion real) async {
    await (delete(messages)
          ..where((t) => t.id.equals(localId) | t.tempId.equals(localId)))
        .go();
    await into(messages).insertOnConflictUpdate(real);
  }

  Future<void> setPinned(String id, bool pinned) async {
    await (update(messages)..where((t) => t.id.equals(id)))
        .write(MessagesCompanion(isPinned: Value(pinned)));
  }

  // ── PendingActions ──────────────────────────────────────────────────────────
  Future<List<PendingAction>> getPendingActions() =>
      (select(pendingActions)
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Future<int> insertPendingAction(String actionType, String payloadJson) =>
      into(pendingActions).insert(PendingActionsCompanion.insert(
          actionType: actionType,
          payload: payloadJson,
          createdAt: DateTime.now().millisecondsSinceEpoch));

  Future<int> deletePendingAction(int id) =>
      (delete(pendingActions)..where((t) => t.id.equals(id))).go();

  Future<void> incrementPendingActionRetry(int id, String? error) async {
    final action = await (select(pendingActions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (action == null) return;
    await (update(pendingActions)..where((t) => t.id.equals(id))).write(
        PendingActionsCompanion(
            retryCount: Value(action.retryCount + 1), lastError: Value(error)));
  }

  Future<void> resetPendingActionRetry(int id) async {
    await (update(pendingActions)..where((t) => t.id.equals(id))).write(
        const PendingActionsCompanion(
            retryCount: Value(0), lastError: Value(null)));
  }

  // ── SyncState ────────────────────────────────────────────────────────────────
  Future<String?> getSyncStateValue(String key) async {
    final row = await (select(syncStates)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setSyncStateValue(String key, String value) =>
      into(syncStates).insertOnConflictUpdate(
          SyncStatesCompanion.insert(key: key, value: value));
}

@DriftDatabase(
    tables: [Conversations, Messages, PendingActions, SyncStates],
    daos: [ChatDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(pendingActions);
            await m.createTable(syncStates);
            // Add new columns to conversations
            for (final col in [
              conversations.lastMessageType,
              conversations.lastMessageSenderId,
              conversations.lastMessageTime,
              conversations.lastMessageIsRead,
              conversations.lastMessageStatus,
              conversations.status,
              conversations.otherUserId,
              conversations.otherUserUsername,
              conversations.otherUserIsVerified,
              conversations.otherUserVerificationBadge,
              conversations.initiatorId,
              conversations.iBlockedThem,
              conversations.theyBlockedMe,
              conversations.sentMessageCount,
              conversations.lastReactionEmoji,
              conversations.lastReactionAt,
              conversations.lastReactionUserId,
              conversations.lastReactionMessageContent,
              conversations.syncStatus,
              conversations.lastSyncedAt,
            ]) {
              await m.addColumn(conversations, col);
            }
            // Add new columns to messages
            for (final col in [
              messages.receiverId,
              messages.senderUsername,
              messages.senderIsVerified,
              messages.senderVerificationBadge,
              messages.messageType,
              messages.mediaData,
              messages.metadata,
              messages.linkPreview,
              messages.reactions,
              messages.replyToId,
              messages.replyTo,
              messages.readAt,
              messages.status,
              messages.deletedForSender,
              messages.deletedForReceiver,
              messages.deletedAt,
              messages.isEdited,
              messages.editedAt,
              messages.syncStatus,
              messages.retryCount,
              messages.tempId,
              messages.isSystem,
              messages.groupId,
              messages.pollData,
              messages.isForwarded,
              messages.forwardedFrom,
              messages.isPinned,
              messages.translatedContent,
              messages.translatedLanguage,
              messages.updatedAt,
            ]) {
              await m.addColumn(messages, col);
            }
          }
        },
      );
}

LazyDatabase _openConnection() => LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'witalk.db'));
      return NativeDatabase.createInBackground(file);
    });
