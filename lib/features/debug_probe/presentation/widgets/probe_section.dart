import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Collapsible card section with a coloured left accent bar.
/// Optional [timing] shows a "N ms" badge in the header.
/// Optional [copyAllText] adds a "Copy all" button at the top of the expanded body.
class ProbeSection extends StatelessWidget {
  final String title;
  final Color accentColor;
  final List<Widget> children;
  final Duration? timing;
  final String? copyAllText;

  const ProbeSection({
    super.key,
    required this.title,
    required this.accentColor,
    required this.children,
    this.timing,
    this.copyAllText,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.hardEdge,
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: EdgeInsets.zero,
        leading: Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            if (timing != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${timing!.inMilliseconds} ms',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ],
        ),
        children: [
          if (copyAllText != null)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton.icon(
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('Copy all', style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: copyAllText!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Section copied'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ),
            ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
