import 'package:flutter/material.dart';

// Phase 6 — replace this placeholder with the full onboarding screen.
// When implemented, trigger indexing here on first launch:
//   ref.read(indexingNotifierProvider.notifier).syncAndStart();
// Then watch indexingProvider to drive the progress bar + phase checkmarks.
// See docs/pipeline.md — "Startup trigger" section.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: const Center(child: Text('Coming in Phase 6')),
    );
  }
}
