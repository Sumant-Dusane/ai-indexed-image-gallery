import 'package:ai_gallery/core/providers/indexing_notifier_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IndexingProgressScreen extends ConsumerWidget {
  const IndexingProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(indexingNotifierProvider);
    final progress = state.total == 0 ? null : state.indexed / state.total;

    return Scaffold(
      appBar: AppBar(title: const Text('Analysing Library')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 16),
            Text(
              'Analysing ${state.indexed} of ${state.total} photos',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
