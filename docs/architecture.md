# Clipt architecture
Follows the Flutter app architecture guide.
- UI layer: ui/<feature>/ holds a Screen (widgets only) and a ViewModel (ChangeNotifier, all logic).
- Data layer: data/repositories/ is the source of truth (abstract class + implementation). data/services/ has one class per data source (SQLite now).
- Domain: domain/models/ holds immutable models shared by both layers.
Rules:
1. Widgets contain no business logic.
2. View models talk to repositories only, never to services.
3. Repositories are abstract classes, so tests can use fakes.
4. All objects are created in config/dependencies.dart (dependency injection).
5. A new feature gets a new folder under ui/, plus a repository if it has new data.
6. Shared widgets go in ui/core/widgets/ and themes in ui/core/themes/.
Naming: HomeScreen, HomeViewModel, SessionRepository, LocalSessionRepository, AppDatabase.
