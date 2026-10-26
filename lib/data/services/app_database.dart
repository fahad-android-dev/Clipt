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
  IntColumn get startedAtMs => integer()();
  IntColumn get endedAtMs => integer().nullable()();
  IntColumn get delaySeconds => integer().withDefault(const Constant(8))();
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

/// Service for the local SQLite data source. Knows nothing about the UI or
/// the domain models: repositories map these rows to domain objects.
@DriftDatabase(tables: [SessionsTable, MarksTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'clipt'));

  /// For tests: pass an in-memory executor.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Stream<List<SessionRow>> watchSessionRows() {
    return (select(sessionsTable)
          ..orderBy([(t) => OrderingTerm.desc(t.startedAtMs)]))
        .watch();
  }

  Future<int> insertSession({
    required String title,
    required int startedAtMs,
  }) {
    return into(sessionsTable).insert(
      SessionsTableCompanion.insert(title: title, startedAtMs: startedAtMs),
    );
  }

  Future<SessionRow?> findSessionRow(int id) {
    return (select(sessionsTable)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> setSessionEnded(int id, int endedAtMs) {
    return (update(sessionsTable)..where((t) => t.id.equals(id))).write(
      SessionsTableCompanion(endedAtMs: Value(endedAtMs)),
    );
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
}