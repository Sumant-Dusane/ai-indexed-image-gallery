import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ai_gallery/core/inference/image_tensor_utils.dart';
import 'package:image/image.dart' as img;

String computePhashDart(Uint8List pixels, int width, int height) {
  final source = rgbImageFromBytes(pixels, width, height);
  final resized = img.copyResize(
    source,
    width: 32,
    height: 32,
    interpolation: img.Interpolation.linear,
  );

  final gray = List<double>.filled(32 * 32, 0);
  for (var y = 0; y < 32; y++) {
    for (var x = 0; x < 32; x++) {
      final p = resized.getPixel(x, y);
      gray[y * 32 + x] = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).toDouble();
    }
  }

  final dct = _dct2d(gray, 32);
  final block = List<double>.filled(64, 0);
  for (var row = 0; row < 8; row++) {
    for (var col = 0; col < 8; col++) {
      block[row * 8 + col] = dct[row * 32 + col];
    }
  }

  final mean = block.reduce((a, b) => a + b) / 64.0;
  var hash = BigInt.zero;
  for (var i = 0; i < block.length; i++) {
    if (block[i] > mean) {
      hash |= BigInt.one << i;
    }
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

List<double> _dct2d(List<double> signal, int n) {
  final tmp = List<double>.filled(n * n, 0);
  for (var row = 0; row < n; row++) {
    final input = signal.sublist(row * n, (row + 1) * n);
    final output = _dct1d(input, n);
    tmp.setRange(row * n, (row + 1) * n, output);
  }

  final result = List<double>.filled(n * n, 0);
  for (var col = 0; col < n; col++) {
    final input = List<double>.filled(n, 0);
    for (var row = 0; row < n; row++) {
      input[row] = tmp[row * n + col];
    }
    final output = _dct1d(input, n);
    for (var row = 0; row < n; row++) {
      result[row * n + col] = output[row];
    }
  }
  return result;
}

List<double> _dct1d(List<double> input, int n) {
  final output = List<double>.filled(n, 0);
  final scale = math.pi / (2.0 * n);
  for (var k = 0; k < n; k++) {
    var sum = 0.0;
    for (var x = 0; x < n; x++) {
      sum += input[x] * math.cos((2 * x + 1) * k * scale);
    }
    output[k] = sum;
  }
  return output;
}
