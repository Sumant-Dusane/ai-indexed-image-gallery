import 'package:ai_gallery/core/providers/indexing_notifier_provider.dart';
import 'package:ai_gallery/core/providers/search_provider.dart';
import 'package:ai_gallery/features/search/search_bar.dart';
import 'package:ai_gallery/features/search/search_empty_state.dart';
import 'package:ai_gallery/features/search/search_results_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;
  bool _hasSubmitted = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(searchNotifierProvider).query,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    ref.read(searchNotifierProvider.notifier).clear();
    setState(() => _hasSubmitted = false);
  }

  void _setQuery(String query) {
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    ref.read(searchNotifierProvider.notifier).updateQuery(query);
  }

  Future<void> _submit() async {
    if (_controller.text.trim().length < 2) {
      setState(() => _hasSubmitted = false);
      return;
    }
    setState(() => _hasSubmitted = true);
    await ref.read(searchNotifierProvider.notifier).search();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchNotifierProvider);
    final indexingState = ref.watch(indexingNotifierProvider);
    final isPartial = indexingState.indexed < indexingState.total;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to gallery',
          onPressed: () {
            _clear();
            context.go('/');
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Search'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: SearchInputBar(
              controller: _controller,
              autofocus: true,
              isSearching: searchState.isSearching,
              onChanged: (query) {
                setState(() => _hasSubmitted = false);
                ref.read(searchNotifierProvider.notifier).updateQuery(query);
              },
              onClear: _clear,
              onSubmitted: _submit,
            ),
          ),
          if (isPartial)
            _PartialIndexBanner(
              indexed: indexingState.indexed,
              total: indexingState.total,
            ),
          Expanded(
            child: _SearchBody(
              hasSubmitted: _hasSubmitted,
              onSuggestionSelected: (query) {
                _setQuery(query);
                _submit();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBody extends ConsumerWidget {
  const _SearchBody({
    required this.hasSubmitted,
    required this.onSuggestionSelected,
  });

  final bool hasSubmitted;
  final ValueChanged<String> onSuggestionSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchNotifierProvider);

    if (!hasSubmitted) {
      return SearchEmptyState.suggestions(onSelected: onSuggestionSelected);
    }
    if (state.isSearching && state.results.isEmpty) {
      return const SizedBox.shrink();
    }
    if (state.results.isEmpty) {
      return SearchEmptyState.noResults(query: state.query);
    }
    return SearchResultsGrid(results: state.results);
  }
}

class _PartialIndexBanner extends StatelessWidget {
  const _PartialIndexBanner({required this.indexed, required this.total});

  final int indexed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Still analysing — showing results from $indexed of $total photos',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
