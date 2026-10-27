import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@DataClassName('SessionRow')
class SessionsTable extends Table {
  @override
  String get tableName => 'sessions';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();

  /// Epoch milliseconds, so timing keeps millisecond precision.
  IntColumn get createdAtMs => integer()();

  /// Null until the user presses Start.
  IntColumn get startedAtMs => integer().nullable()();
  IntColumn get endedAtMs => integer().nullable()();
  IntColumn get delaySeconds => integer().withDefault(const Constant(8))();
  TextColumn get videoFile => text().nullable()();
}

@DataClassName('MarkRow')
class MarksTable extends Table {
  @override
  String get tableName => 'marks';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(SessionsTable, #id)();

  /// Raw milliseconds since the session started.
  IntColumn get atMs => integer()();
  TextColumn get tag => text().withDefault(const Constant('Highlight'))();
}

@DriftDatabase(tables: [SessionsTable, MarksTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'clipt'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      // Handle migration from old schema (version 1) to new schema
      if (from < 2) {
        // Delete old tables and recreate with new schema
        await m.deleteTable('marks');
        await m.deleteTable('sessions');
        // Recreate tables using the Migrator
        await m.createTable(sessionsTable);
        await m.createTable(marksTable);
        return;
      }
      // Add videoFile column for version 3
      if (from < 3) {
        await m.addColumn(sessionsTable, sessionsTable.videoFile);
      }
    },
    beforeOpen: (details) async {
      // Enable foreign keys
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Stream<List<SessionRow>> watchSessionRows() {
    return (select(
      sessionsTable,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAtMs)])).watch();
  }

  Future<int> insertSession({required String title, required int createdAtMs}) {
    return into(sessionsTable).insert(
      SessionsTableCompanion.insert(title: title, createdAtMs: createdAtMs),
    );
  }

  Future<SessionRow?> findSessionRow(int id) {
    return (select(
      sessionsTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> setSessionStarted(int id, int startedAtMs) {
    return (update(sessionsTable)..where((t) => t.id.equals(id))).write(
      SessionsTableCompanion(startedAtMs: Value(startedAtMs)),
    );
  }

  Future<void> setSessionEnded(int id, int endedAtMs) {
    return (update(sessionsTable)..where((t) => t.id.equals(id))).write(
      SessionsTableCompanion(endedAtMs: Value(endedAtMs)),
    );
  }

  /// Deletes a session and all of its marks together, or neither.
  Future<void> deleteSessionWithMarks(int id) {
    return transaction(() async {
      await (delete(marksTable)..where((t) => t.sessionId.equals(id))).go();
      await (delete(sessionsTable)..where((t) => t.id.equals(id))).go();
    });
  }

  Future<void> insertMark({
    required int sessionId,
    required int atMs,
    required String tag,
  }) {
    return into(marksTable).insert(
      MarksTableCompanion.insert(
        sessionId: sessionId,
        atMs: atMs,
        tag: Value(tag),
      ),
    );
  }

  Future<List<MarkRow>> findMarkRows(int sessionId) {
    return (select(marksTable)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.atMs)]))
        .get();
  }

  Future<void> setSessionDelay(int id, int seconds) {
    return (update(sessionsTable)..where((t) => t.id.equals(id))).write(
      SessionsTableCompanion(delaySeconds: Value(seconds)),
    );
  }

  Future<void> setSessionVideo(int id, String? fileName) {
    return (update(sessionsTable)..where((t) => t.id.equals(id))).write(
      SessionsTableCompanion(videoFile: Value(fileName)),
    );
  }

  Future<void> setMarkTag(int markId, String tag) {
    return (update(marksTable)..where((t) => t.id.equals(markId))).write(
      MarksTableCompanion(tag: Value(tag)),
    );
  }

  Future<void> deleteMarkRow(int markId) {
    return (delete(marksTable)..where((t) => t.id.equals(markId))).go();
  }
}
