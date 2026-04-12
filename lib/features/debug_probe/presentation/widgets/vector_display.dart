import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'copy_value_row.dart';

/// Displays a float vector as stats (length, min, max, mean, L2 norm) plus
/// a short preview of the first [previewCount] values.
/// A copy icon on the preview row copies the full vector to clipboard.
class VectorDisplay extends StatelessWidget {
  final String label;
  final List<double> values;
  final int previewCount;

  const VectorDisplay({
    super.key,
    required this.label,
    required this.values,
    this.previewCount = 8,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return CopyValueRow(label: label, value: '(empty)');
    }

    final min = values.reduce(math.min);
    final max = values.reduce(math.max);
    final mean = values.fold(0.0, (s, v) => s + v) / values.length;
    final norm = math.sqrt(values.fold(0.0, (s, v) => s + v * v));
    final preview =
        values.take(previewCount).map((v) => v.toStringAsFixed(4)).join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CopyValueRow(label: '$label length', value: '${values.length}'),
        CopyValueRow(label: 'min', value: min.toStringAsFixed(6)),
        CopyValueRow(label: 'max', value: max.toStringAsFixed(6)),
        CopyValueRow(label: 'mean', value: mean.toStringAsFixed(6)),
        CopyValueRow(label: 'L2 norm', value: norm.toStringAsFixed(6)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130,
                child: Text(
                  'first $previewCount values',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              Expanded(
                child: Text(
                  '[$preview, …]',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () {
                  final full =
                      '[${values.map((v) => v.toStringAsFixed(6)).join(', ')}]';
                  Clipboard.setData(ClipboardData(text: full));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Full vector copied'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.copy, size: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
