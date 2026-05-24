import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ai_gallery/core/inference/inference_types.dart';
import 'package:image/image.dart' as img;

const _clipMean = [0.48145466, 0.4578275, 0.40821073];
const _clipStd = [0.26862954, 0.26130258, 0.27577711];

img.Image rgbImageFromBytes(Uint8List pixels, int width, int height) {
  final image = img.Image(width: width, height: height, numChannels: 3);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 3;
      image.setPixelRgb(x, y, pixels[i], pixels[i + 1], pixels[i + 2]);
    }
  }
  return image;
}

Float32List preprocessClipImage(Uint8List pixels, int width, int height) {
  final source = rgbImageFromBytes(pixels, width, height);
  final resized = img.copyResize(
    source,
    width: 224,
    height: 224,
    interpolation: img.Interpolation.linear,
  );
  final data = Float32List(3 * 224 * 224);
  for (var y = 0; y < 224; y++) {
    for (var x = 0; x < 224; x++) {
      final p = resized.getPixel(x, y);
      final idx = y * 224 + x;
      data[idx] = (p.r / 255.0 - _clipMean[0]) / _clipStd[0];
      data[224 * 224 + idx] = (p.g / 255.0 - _clipMean[1]) / _clipStd[1];
      data[2 * 224 * 224 + idx] = (p.b / 255.0 - _clipMean[2]) / _clipStd[2];
    }
  }
  return data;
}

LetterboxResult preprocessYolo(Uint8List pixels, int width, int height) {
  const size = 640;
  const pad = 114;
  final source = rgbImageFromBytes(pixels, width, height);
  final scale = math.min(size / width, size / height);
  final newW = (width * scale).round();
  final newH = (height * scale).round();
  final resized = img.copyResize(
    source,
    width: newW,
    height: newH,
    interpolation: img.Interpolation.linear,
  );
  final padX = (size - newW) / 2.0;
  final padY = (size - newH) / 2.0;
  final canvas = img.Image(width: size, height: size, numChannels: 3);
  img.fill(canvas, color: img.ColorRgb8(pad, pad, pad));
  img.compositeImage(canvas, resized, dstX: padX.round(), dstY: padY.round());

  final data = Float32List(3 * size * size);
  final n = size * size;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final p = canvas.getPixel(x, y);
      final idx = y * size + x;
      data[idx] = p.r / 255.0;
      data[n + idx] = p.g / 255.0;
      data[2 * n + idx] = p.b / 255.0;
    }
  }
  return LetterboxResult(data: data, scale: scale, padX: padX, padY: padY);
}

Float32List preprocessFace(Uint8List pixels, int width, int height, BBox bbox) {
  final crop = _cropExpandedBbox(pixels, width, height, bbox);
  final resized = img.copyResize(
    crop,
    width: 112,
    height: 112,
    interpolation: img.Interpolation.linear,
  );
  final data = Float32List(3 * 112 * 112);
  for (var y = 0; y < 112; y++) {
    for (var x = 0; x < 112; x++) {
      final p = resized.getPixel(x, y);
      final idx = y * 112 + x;
      data[idx] = ((p.r - 127.5) / 128.0).toDouble();
      data[112 * 112 + idx] = ((p.g - 127.5) / 128.0).toDouble();
      data[2 * 112 * 112 + idx] = ((p.b - 127.5) / 128.0).toDouble();
    }
  }
  return data;
}

Float32List preprocessEmotion(
  Uint8List pixels,
  int width,
  int height,
  BBox bbox,
) {
  final crop = _cropExpandedBbox(pixels, width, height, bbox);
  final resized = img.copyResize(
    crop,
    width: 224,
    height: 224,
    interpolation: img.Interpolation.linear,
  );
  final data = Float32List(3 * 224 * 224);
  for (var y = 0; y < 224; y++) {
    for (var x = 0; x < 224; x++) {
      final p = resized.getPixel(x, y);
      final idx = y * 224 + x;
      data[idx] = p.r / 255.0;
      data[224 * 224 + idx] = p.g / 255.0;
      data[2 * 224 * 224 + idx] = p.b / 255.0;
    }
  }
  return data;
}

List<double> l2Normalize(List<double> values) {
  var sum = 0.0;
  for (final v in values) {
    sum += v * v;
  }
  final norm = math.sqrt(sum);
  if (norm <= 1e-12) return values;
  return values.map((v) => v / norm).toList(growable: false);
}

img.Image _cropExpandedBbox(
  Uint8List pixels,
  int width,
  int height,
  BBox bbox,
) {
  final source = rgbImageFromBytes(pixels, width, height);
  final x1Px = bbox.x * width;
  final y1Px = bbox.y * height;
  final x2Px = (bbox.x + bbox.w) * width;
  final y2Px = (bbox.y + bbox.h) * height;
  final padX = bbox.w * width * 0.2;
  final padY = bbox.h * height * 0.2;

  final x1 = math.max(0, x1Px - padX).toInt();
  final y1 = math.max(0, y1Px - padY).toInt();
  final x2 = math.min(width, x2Px + padX).toInt();
  final y2 = math.min(height, y2Px + padY).toInt();
  return img.copyCrop(
    source,
    x: x1,
    y: y1,
    width: math.max(1, x2 - x1),
    height: math.max(1, y2 - y1),
  );
}

class LetterboxResult {
  final Float32List data;
  final double scale;
  final double padX;
  final double padY;

  const LetterboxResult({
    required this.data,
    required this.scale,
    required this.padX,
    required this.padY,
  });
}
