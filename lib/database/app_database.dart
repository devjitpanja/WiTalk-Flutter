import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()(); // private | group | channel
  TextColumn get name => text()();
  TextColumn get profilePic => text().nullable()();
  TextColumn get lastMessage => text().nullable()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  BoolColumn get isMuted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text()();
  TextColumn get senderId => text()();
  TextColumn get senderName => text().withDefault(const Constant(''))();
  TextColumn get senderPic => text().nullable()();
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get type => text().withDefault(const Constant('text'))();
  TextColumn get mediaUrl => text().nullable()();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  BoolColumn get isSending => boolean().withDefault(const Constant(false))();
  BoolColumn get isFailed => boolean().withDefault(const Constant(false))();
  TextColumn get replyToId => text().nullable()();
  IntColumn get createdAt => integer()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftAccessor(tables: [Conversations, Messages])
class ChatDao extends DatabaseAccessor<AppDatabase> with _$ChatDaoMixin {
  ChatDao(super.db);

  Stream<List<Conversation>> watchConversations() =>
      (select(conversations)..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();

  Future<void> upsertConversation(ConversationsCompanion c) =>
      into(conversations).insertOnConflictUpdate(c);

  Future<void> bulkUpsertConversations(List<ConversationsCompanion> list) =>
      batch((b) => b.insertAllOnConflictUpdate(conversations, list));

  Future<int> markConversationRead(String id) =>
      (update(conversations)..where((t) => t.id.equals(id)))
          .write(const ConversationsCompanion(unreadCount: Value(0)));

  Stream<List<Message>> watchMessages(String conversationId) =>
      (select(messages)
        ..where((t) => t.conversationId.equals(conversationId) & t.isDeleted.equals(false))
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  Future<void> insertMessage(MessagesCompanion m) =>
      into(messages).insertOnConflictUpdate(m);

  Future<void> bulkInsertMessages(List<MessagesCompanion> list) =>
      batch((b) => b.insertAllOnConflictUpdate(messages, list));

  Future<int> markMessageRead(String id) =>
      (update(messages)..where((t) => t.id.equals(id)))
          .write(const MessagesCompanion(isRead: Value(true)));

  Future<int> deleteMessage(String id) =>
      (update(messages)..where((t) => t.id.equals(id)))
          .write(const MessagesCompanion(isDeleted: Value(true)));

  Future<void> replaceLocalMessage(String localId, MessagesCompanion real) async {
    await (delete(messages)..where((t) => t.id.equals(localId))).go();
    await into(messages).insertOnConflictUpdate(real);
  }
}

@DriftDatabase(tables: [Conversations, Messages], daos: [ChatDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() => LazyDatabase(() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'witalk.db'));
  return NativeDatabase.createInBackground(file);
});
