import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/repositories/session_repository.dart';
import '../data/repositories/video_repository.dart';
import '../dev/ffmpeg_lab_screen.dart';
import '../ui/core/widgets/view_model_host.dart';
import '../ui/folder/folder_screen.dart';
import '../ui/folder/folder_view_model.dart';
import '../ui/home/home_screen.dart';
import '../ui/home/home_view_model.dart';
import '../ui/live_session/live_session_screen.dart';
import '../ui/live_session/live_session_view_model.dart';
import '../ui/review/review_screen.dart';
import '../ui/review/review_view_model.dart';
import 'routes.dart';

GoRouter createRouter() {
  final routes = [
    GoRoute(
      path: Routes.home,
      builder: (context, state) => ViewModelHost<HomeViewModel>(
        create: (c) => HomeViewModel(
          sessionRepository: c.read<SessionRepository>(),
          videoRepository: c.read<VideoRepository>(),
        ),
        builder: (c, viewModel) => HomeScreen(viewModel: viewModel),
      ),
    ),
    GoRoute(
      path: Routes.folder,
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
        return ViewModelHost<FolderViewModel>(
          key: ValueKey('folder-$id'),
          create: (c) => FolderViewModel(
            sessionRepository: c.read<SessionRepository>(),
            videoRepository: c.read<VideoRepository>(),
            folderId: id,
          ),
          builder: (c, viewModel) => FolderScreen(viewModel: viewModel),
        );
      },
    ),
    GoRoute(
      path: Routes.unfiled,
      builder: (context, state) => ViewModelHost<FolderViewModel>(
        key: const ValueKey('unfiled'),
        create: (c) => FolderViewModel(
          sessionRepository: c.read<SessionRepository>(),
          videoRepository: c.read<VideoRepository>(),
          folderId: null,
        ),
        builder: (c, viewModel) => FolderScreen(viewModel: viewModel),
      ),
    ),
    GoRoute(
      path: Routes.session,
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
        return ViewModelHost<LiveSessionViewModel>(
          key: ValueKey('session-$id'),
          create: (c) => LiveSessionViewModel(
            sessionRepository: c.read<SessionRepository>(),
            sessionId: id,
          ),
          builder: (c, viewModel) => LiveSessionScreen(viewModel: viewModel),
        );
      },
    ),
    GoRoute(
      path: Routes.review,
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
        return ViewModelHost<ReviewViewModel>(
          key: ValueKey('review-$id'),
          create: (c) => ReviewViewModel(
            sessionRepository: c.read<SessionRepository>(),
            videoRepository: c.read<VideoRepository>(),
            sessionId: id,
          )..load(),
          builder: (c, viewModel) => ReviewScreen(viewModel: viewModel),
        );
      },
    ),
  ];

  if (kDebugMode) {
    routes.add(
      GoRoute(
        path: '/dev/ffmpeg',
        builder: (_, _) => const FfmpegLabScreen(),
      ),
    );
  }

  return GoRouter(
    initialLocation: Routes.home,
    routes: routes,
  );
}