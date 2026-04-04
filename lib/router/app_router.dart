import 'package:ai_gallery/core/providers/indexing_notifier_provider.dart';
import 'package:ai_gallery/core/providers/photo_permission_provider.dart';
import 'package:ai_gallery/features/gallery/gallery_screen.dart';
import 'package:ai_gallery/features/gallery/photo_detail_screen.dart';
import 'package:ai_gallery/features/people/cluster_detail_screen.dart';
import 'package:ai_gallery/features/people/people_screen.dart';
import 'package:ai_gallery/features/permission/permission_denied_screen.dart';
import 'package:ai_gallery/features/search/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(Ref ref) {
  final router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final permissionAsync = ref.read(photoPermissionProvider);

      // Permission not yet resolved — let the current route stand.
      if (!permissionAsync.hasValue) return null;

      final permission = permissionAsync.value!;
      final isDenied = !permission.isGranted;
      final onDeniedPage = state.matchedLocation == '/permission-denied';

      if (isDenied && !onDeniedPage) return '/permission-denied';
      if (!isDenied && onDeniedPage) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/permission-denied',
        builder: (_, __) => const PermissionDeniedScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/', builder: (_, __) => const GalleryScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (_, __) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/people',
                builder: (_, __) => const PeopleScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/photo/:photoId',
        builder: (_, state) =>
            PhotoDetailScreen(photoId: state.pathParameters['photoId']!),
      ),
      GoRoute(
        path: '/people/:clusterId',
        builder: (_, state) => ClusterDetailScreen(
          clusterId: int.parse(state.pathParameters['clusterId']!),
        ),
      ),
    ],
  );

  // Re-run redirect whenever permission state changes (e.g. after app resumes
  // from Settings and PermissionDeniedScreen invalidates the provider).
  ref.listen(photoPermissionProvider, (_, __) => router.refresh());

  // Kick off sync + indexing the moment permission is confirmed granted.
  // Central startup — screens do not call syncAndStart() themselves.
  ref.listen(photoPermissionProvider, (_, next) {
    if (!next.hasValue) return;
    if (next.value!.isGranted) {
      ref.read(indexingNotifierProvider.notifier).syncAndStart();
    }
  });
  ref.onDispose(router.dispose);

  return router;
}

class ScaffoldWithNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: 'Gallery',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outlined),
            selectedIcon: Icon(Icons.people),
            label: 'People',
          ),
        ],
      ),
    );
  }
}
