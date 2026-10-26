import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../data/repositories/local_session_repository.dart';
import '../data/repositories/session_repository.dart';
import '../data/services/app_database.dart';

/// Dependency injection: everything the app needs is created here, once.
/// To use fakes in tests, build a different list.
List<SingleChildWidget> get dependencies => [
      // Service: one per data source.
      Provider<AppDatabase>(
        create: (_) => AppDatabase(),
        dispose: (_, db) => db.close(),
      ),
      // Repository: the single source of truth for session data.
      Provider<SessionRepository>(
        create: (context) =>
            LocalSessionRepository(database: context.read<AppDatabase>()),
      ),
    ];