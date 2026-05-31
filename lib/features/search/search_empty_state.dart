import 'package:flutter/material.dart';

class SearchEmptyState extends StatelessWidget {
  const SearchEmptyState.suggestions({
    super.key,
    required ValueChanged<String> onSelected,
  }) : _query = null,
       _onSelected = onSelected;

  const SearchEmptyState.noResults({super.key, required String query})
    : _query = query,
      _onSelected = null;

  final String? _query;
  final ValueChanged<String>? _onSelected;

  @override
  Widget build(BuildContext context) {
    final onSelected = _onSelected;
    if (onSelected != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
        ),
      );
    }

    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "No photos found for '${_query ?? ''}'",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try different words, or wait for indexing to finish',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
