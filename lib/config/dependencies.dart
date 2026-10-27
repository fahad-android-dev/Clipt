import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../data/repositories/local_session_repository.dart';
import '../data/repositories/local_video_repository.dart';
import '../data/repositories/session_repository.dart';
import '../data/repositories/video_repository.dart';
import '../data/services/app_database.dart';
import '../data/services/video_storage_service.dart';

/// Dependency injection: everything the app needs is created here, once.
/// To use fakes in tests, build a different list.
List<SingleChildWidget> get dependencies => [
      // Services: one per data source.
      Provider<AppDatabase>(
        create: (_) => AppDatabase(),
        dispose: (_, db) => db.close(),
      ),
      Provider<VideoStorageService>(create: (_) => VideoStorageService()),
      // Repositories: the single source of truth for each kind of data.
      Provider<SessionRepository>(
        create: (context) =>
            LocalSessionRepository(database: context.read<AppDatabase>()),
      ),
      Provider<VideoRepository>(
        create: (context) => LocalVideoRepository(
          storage: context.read<VideoStorageService>(),
        ),
      ),
    ];