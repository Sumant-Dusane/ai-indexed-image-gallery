import 'package:flutter/material.dart';

class SearchInputBar extends StatelessWidget {
  const SearchInputBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.onSubmitted,
    this.autofocus = false,
    this.isSearching = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onSubmitted;
  final bool autofocus;
  final bool isSearching;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onSubmitted: (_) => onSubmitted(),
      decoration: InputDecoration(
        hintText: 'Search your photos',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSearching)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (controller.text.isNotEmpty)
              IconButton(
                tooltip: 'Clear',
                onPressed: onClear,
                icon: const Icon(Icons.clear),
              ),
            IconButton(
              tooltip: 'Search',
              onPressed: isSearching ? null : onSubmitted,
              icon: const Icon(Icons.search),
            ),
          ],
        ),
      ),
    );
  }
}
