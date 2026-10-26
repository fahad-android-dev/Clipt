import 'package:material_ui/material_ui.dart';

import 'routing/router.dart';
import 'ui/core/themes/app_theme.dart';

final _router = createRouter();

class CliptApp extends StatelessWidget {
  const CliptApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Clipt',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}