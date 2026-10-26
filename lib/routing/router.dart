import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/repositories/session_repository.dart';
import '../ui/core/widgets/view_model_host.dart';
import '../ui/home/home_screen.dart';
import '../ui/home/home_view_model.dart';
import '../ui/live_session/live_session_screen.dart';
import '../ui/live_session/live_session_view_model.dart';
import 'routes.dart';

GoRouter createRouter() {
  return GoRouter(
    initialLocation: Routes.home,
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (context, state) => ViewModelHost<HomeViewModel>(
          create: (c) => HomeViewModel(
            sessionRepository: c.read<SessionRepository>(),
          ),
          builder: (c, viewModel) => HomeScreen(viewModel: viewModel),
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
    ],
  );
}