# docs/skeleton.md — Phase 1 Skeleton Spec

Phase 1 builds the project foundation. Every later phase depends on these files existing and working correctly.

---

## Files Phase 1 must produce

```
pubspec.yaml                           ← all dependencies from docs/stack.md

lib/
  main.dart                            ← entry point: ensureInitialized, ProviderScope, App
  app.dart                             ← MaterialApp.router, theme, GoRouter
  router/
    app_router.dart                    ← GoRouter config with all routes
  core/
    db/
      database.dart                    ← SQLite singleton, migration runner, sqlite-vec loader
      schema.dart                      ← table/column name constants (strings only)
    models/
      photo_asset.dart                 ← @freezed PhotoAsset
      detection.dart                   ← @freezed Detection
      face.dart                        ← @freezed Face
      cluster.dart                     ← @freezed FaceCluster
      search_result.dart               ← @freezed SearchResult
    providers/
      database_provider.dart           ← @riverpod Database provider
    repositories/
      photo_repository.dart            ← photo_manager wrapper: list assets, get bytes
      inference_repository.dart        ← inference seam (stubs in Phase 1)
  features/
    gallery/
      gallery_screen.dart              ← placeholder scaffold with bottom nav
    search/
      search_screen.dart               ← placeholder scaffold
    people/
      people_screen.dart               ← placeholder scaffold
    onboarding/
      onboarding_screen.dart           ← placeholder scaffold

```

---

## main.dart structure

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: App()));
}
```

No other initialization in main. DB init and permission checks happen lazily via providers. Photo sync (`syncPhotoLibrary` + `startIndexing`) is triggered at navigation time: from the onboarding screen on first launch, and from the gallery screen on every subsequent launch. See `docs/pipeline.md` — "Startup trigger" section.

---

## app.dart structure

```dart
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      routerConfig: router,
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      themeMode: ThemeMode.system,
    );
  }
}
```

Theme definition: see `docs/ui-spec.md` Theme section.

---

## Router configuration

All routes from `docs/ui-spec.md`:

```dart
@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, __) => const GalleryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/people', builder: (_, __) => const PeopleScreen()),
          ]),
        ],
      ),
      GoRoute(
        path: '/photo/:photoId',
        builder: (_, state) => PhotoDetailScreen(
          photoId: state.pathParameters['photoId']!,
        ),
      ),
      GoRoute(
        path: '/people/:clusterId',
        builder: (_, state) => ClusterDetailScreen(
          clusterId: int.parse(state.pathParameters['clusterId']!),
        ),
      ),
    ],
  );
}
```

Also create `ScaffoldWithNavBar` widget for the 3-tab `BottomNavigationBar`.

---

## Database initialization

```dart
@riverpod
Future<Database> database(Ref ref) async {
  final dbPath = await getDatabasesPath();
  final path = join(dbPath, 'gallery.db');
  final db = await openDatabase(
    path,
    version: 1,
    onCreate: (db, version) async {
      // Load sqlite-vec extension first
      // Then run migration 001 from docs/schema.md
    },
  );
  return db;
}
```

Key rules:
- Singleton — only one Database instance ever
- Load sqlite-vec extension immediately after opening, before creating vec0 tables
- Run all CREATE TABLE / CREATE INDEX statements from `docs/schema.md` migration 001
- All queries return plain `Map<String, dynamic>` — model mapping happens in repositories

---

## Photo library permission flow

```
App start → check photo_manager permission
  → if granted: proceed to gallery/onboarding
  → if denied/limited: show permission request screen
  → on permanent deny: show "Open Settings" button
```

Use `PhotoManager.requestPermissionExtend()` for the initial request.
Check `SharedPreferences` key `onboarding_complete` to decide initial route:
- `false` or absent → OnboardingScreen
- `true` → GalleryScreen

---

## Inference repository initialization

Create `lib/core/repositories/inference_repository.dart` with the public API documented in `docs/models.md`.
In Phase 1, methods may return empty/dummy values. Phase 2 fills in Flutter ONNX Runtime-backed implementation details.

---

## Feature placeholders

Each feature screen in Phase 1 is a minimal `Scaffold` with:
- `AppBar` with the screen name
- `Center(child: Text('Coming in Phase N'))` as body
- Correct widget class name matching the AGENTS.md spec for that feature

These placeholders let the router and bottom nav work. Real UI comes in later phases.

---

## Phase 1 does NOT include

- Any ML inference (Phase 2)
- IndexingService (Phase 3)
- QueryService or search UI (Phase 4)
- Face clustering (Phase 5)
- UI polish or onboarding flow (Phase 6)
- Video handling (future phase)

Phase 1 is done when: `flutter run` launches, shows 3-tab navigation, gallery screen loads photo thumbnails from photo_manager, and SQLite DB is created with all tables.
