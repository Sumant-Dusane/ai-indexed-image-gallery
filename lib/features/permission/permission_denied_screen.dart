import 'package:ai_gallery/core/providers/photo_permission_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

/// Shown when photo library permission is denied or restricted.
///
/// Uses [WidgetsBindingObserver] to re-check permission when the user returns
/// from the system Settings app, which invalidates [photoPermissionProvider]
/// and triggers the router redirect to re-evaluate.
class PermissionDeniedScreen extends ConsumerStatefulWidget {
  const PermissionDeniedScreen({super.key});

  @override
  ConsumerState<PermissionDeniedScreen> createState() =>
      _PermissionDeniedScreenState();
}

class _PermissionDeniedScreenState extends ConsumerState<PermissionDeniedScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-request permission — the router redirect will navigate away if granted.
      ref.invalidate(photoPermissionProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 24),
                Text(
                  'No Access to Photos',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'AI Gallery needs permission to show your photo library.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => PhotoManager.openSetting(),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
