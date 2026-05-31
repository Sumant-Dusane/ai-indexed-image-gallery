import 'dart:io';

import 'package:ai_gallery/core/providers/indexing_notifier_provider.dart';
import 'package:ai_gallery/core/providers/search_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  bool _hasSubmitted = false;

  void _setQuery(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    ref.read(searchNotifierProvider.notifier).updateQuery(query);
  }

  Future<void> _submit() async {
    setState(() => _hasSubmitted = true);
    await ref.read(searchNotifierProvider.notifier).search();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchNotifierProvider);
    final indexing = ref.watch(indexingNotifierProvider);
    final notifier = ref.read(searchNotifierProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        leading: IconButton(
          tooltip: 'Back to gallery',
          onPressed: () {
            _controller.clear();
            notifier.clear();
            context.go('/');
          },
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (query) {
                setState(() => _hasSubmitted = false);
                notifier.updateQuery(query);
              },
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Search your photos',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.isSearching)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    if (_controller.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear',
                        onPressed: () {
                          _controller.clear();
                          setState(() => _hasSubmitted = false);
                          notifier.clear();
                        },
                        icon: const Icon(Icons.clear),
                      ),
                    IconButton(
                      tooltip: 'Search',
                      onPressed: state.isSearching ? null : _submit,
                      icon: const Icon(Icons.search),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (state.indexingPartial)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Still analysing - showing results from '
                '${indexing.indexed} of ${indexing.total} photos',
              ),
            ),
          Expanded(
            child: _SearchResults(
              state: state,
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

class _SearchResults extends StatelessWidget {
  final SearchState state;
  final bool hasSubmitted;
  final void Function(String query) onSuggestionSelected;

  const _SearchResults({
    required this.state,
    required this.hasSubmitted,
    required this.onSuggestionSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasSubmitted) {
      return _SearchSuggestions(onSelected: onSuggestionSelected);
    }
    if (state.results.isEmpty) {
      if (state.query.trim().isEmpty) {
        return const Center(child: Text('Search your photo library'));
      }
      if (state.isSearching) return const SizedBox.shrink();
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("No photos found for '${state.query}'"),
            const SizedBox(height: 8),
            const Text('Try different words, or wait for indexing to finish'),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: state.results.length,
      itemBuilder: (context, index) {
        final result = state.results[index];
        return GestureDetector(
          onTap: () => context.go('/photo/${result.photoId}'),
          child: Hero(
            tag: 'photo_${result.photoId}',
            child: Image.file(File(result.localPath), fit: BoxFit.cover),
          ),
        );
      },
    );
  }
}

class _SearchSuggestions extends StatelessWidget {
  final void Function(String query) onSelected;

  const _SearchSuggestions({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (final suggestion in _searchSuggestions)
            ActionChip(
              label: Text(suggestion),
              onPressed: () => onSelected(suggestion),
            ),
        ],
      ),
    );
  }
}

const _searchSuggestions = <String>[
  'beach sunset',
  'birthday',
  'red shirt',
  'dog',
  'snow',
  'laughing',
];
