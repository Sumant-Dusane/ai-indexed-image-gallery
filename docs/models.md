# docs/models.md — ML models

All models are bundled in `assets/models/`. All INT8 quantized. ONNX opset 17.
Load lazily on first call. Cache one `OrtSession` per model in `InferenceRepository`.
Never reload a session — one session per model for app lifetime.

## Model loading

Use `flutter_onnxruntime` through `InferenceRepository`.
Prefer `OnnxRuntime.createSessionFromAsset('assets/models/<file>.onnx')`.
Only copy assets to `getApplicationDocumentsDirectory()/models/` if a plugin/platform limitation requires a real file path.

---

## Model inventory

| File | Task | Input name | Input tensor | Output name | Output tensor | Expected size | Actual size |
|---|---|---|---|---|---|---|---|
| `mobileclip_s1_image_int8.onnx` | Image semantic embedding | `"image"` | `[1, 3, 224, 224]` float32 | `"embedding"` | `[1, 512]` float32 | ~6MB | 21MB |
| `mobileclip_s1_text_int8.onnx` | Text query embedding | `"tokens"` | `[1, 77]` int32 | `"embedding"` | `[1, 512]` float32 | ~3MB | 60.9MB¹ |
| `mobilefacenet_int8.onnx` | Face embedding | `"face"` | `[1, 3, 112, 112]` float32 | `"embedding"` | `[1, 128]` float32 | ~4MB | 1.1MB |
| `yolov8n_int8.onnx` | Object detection | `"images"` | `[1, 3, 640, 640]` float32 | `"output0"` | `[1, 84, 8400]` float32 | ~3MB | 3.3MB |
| `emotion_enet_b0_int8.onnx` | Emotion classification | `"face"` | `[1, 3, 224, 224]` float32 | `"logits"` | `[1, 8]` float32 | ~5MB | 4.0MB |

Total: ~18MB expected / ~90MB actual

¹ `quantize_dynamic` has limited effect on transformer attention layers — most weights remain float32.

---

## Preprocessing — exact steps per model

### MobileCLIP-S1 (image)
1. Resize image to 224x224 (bilinear)
2. Convert to RGB float32
3. Normalize: `pixel = (pixel / 255.0 - mean) / std`
   - mean: `[0.48145466, 0.4578275, 0.40821073]`
   - std:  `[0.26862954, 0.26130258, 0.27577711]`
4. Layout: CHW, batch dim prepended → `[1, 3, 224, 224]`
5. L2-normalize the 512-dim output vector before storing

### MobileCLIP-S1 (text)
1. BPE tokenize query string (vocab file: `assets/models/bpe_vocab.json`)
2. Pad or truncate to 77 tokens
3. Input tensor: `[1, 77]` int32
4. L2-normalize the 512-dim output vector

**Note on BPE tokenizer:** Tokenization is owned by Dart in the inference layer. Load `assets/models/bpe_vocab.json` once, produce the documented `[1, 77]` int32 token tensor, and validate token IDs against golden queries before enabling search.

### MobileFaceNet
1. Crop face region from original image using bbox (expand bbox 20% on each side, clamp to image bounds)
2. Resize crop to 112x112 (bilinear)
3. Convert to RGB float32
4. Normalize: `pixel = (pixel - 127.5) / 128.0`
5. Layout: CHW → `[1, 3, 112, 112]`
6. L2-normalize the 128-dim output vector before storing

### YOLOv8-nano
1. Resize image to 640x640 (letterbox padding, preserve aspect ratio)
2. Convert to RGB float32
3. Normalize: `pixel = pixel / 255.0`
4. Layout: CHW → `[1, 3, 640, 640]`
5. Output shape `[1, 84, 8400]`: 84 = 4 bbox coords + 80 class scores
6. Apply NMS: confidence threshold 0.35, IoU threshold 0.45
7. Scale bbox coords back to original image dimensions
8. Store bbox as normalised 0..1 values (divide by original w/h)

### EfficientNet-B0 (emotion)
1. Crop face region using YOLO bbox (expand 20%, clamp to image bounds)
2. Resize crop to 224x224 (bilinear)
3. Convert to RGB float32
4. Normalize: `pixel = pixel / 255.0`
5. Layout: CHW → `[1, 3, 224, 224]`
6. Output: `[1, 8]` logits → softmax → argmax → label (see class mapping below)

---

## Emotion class index mapping (fixed)

```dart
const emotionLabels = [
  'neutral',   // 0
  'happy',     // 1
  'sad',       // 2
  'surprised', // 3
  'fear',      // 4
  'disgust',   // 5
  'angry',     // 6
  'contempt',  // 7: map to "neutral"
];

final idx = argmax(logits);
final label = idx == 7 ? 'neutral' : emotionLabels[idx];
```

---

## YOLO class filter

Only store detections for these classes (ignore the rest to save space):
```
person, car, motorcycle, bicycle, bus, truck,
dog, cat, bird, horse,
bottle, cup, wine glass, bowl,
pizza, cake, sandwich,
laptop, phone, tv,
chair, couch, bed, dining table,
book, clock, umbrella, backpack, handbag,
snowboard, skis, surfboard, skateboard, sports ball
```

Non-person objects: insert into `detections` table.
Person boxes: do NOT insert into detections — feed to MobileFaceNet + emotion pipeline instead.

---

## pHash algorithm (in Dart)

1. Resize image to 32x32 grayscale
2. Apply 2D DCT
3. Take top-left 8x8 of DCT result (64 values)
4. Compute mean of those 64 values
5. Output: 64-bit integer where bit[i] = 1 if dct[i] > mean
6. Store as 16-char hex string in `photos.phash`
7. Dedup threshold: Hamming distance <= 8 = same image

---

## Reference: Flutter ONNX Runtime inference pattern

Use this pattern for all model inference. Keep calls behind `InferenceRepository`.

```dart
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

final runtime = OnnxRuntime();
final session = await runtime.createSessionFromAsset(
  'assets/models/mobileclip_s1_image_int8.onnx',
);

final input = await OrtValue.fromList(preprocessed, [1, 3, 224, 224]);
final outputs = await session.run({'image': input});
final raw = await outputs['embedding']!.asFlattenedList();
final embedding = raw.cast<double>();
```

**Tensor names per model (use these exactly in `inputs![]` and `outputs[]`):**
| Model file | Input name | Output name |
|---|---|---|
| `mobileclip_s1_image_int8.onnx` | `"image"` | `"embedding"` |
| `mobileclip_s1_text_int8.onnx` | `"tokens"` | `"embedding"` |
| `mobilefacenet_int8.onnx` | `"face"` | `"embedding"` |
| `yolov8n_int8.onnx` | `"images"` | `"output0"` |
| `emotion_enet_b0_int8.onnx` | `"face"` | `"logits"` |

---

## Reference: InferenceRepository API

All app code calls `InferenceRepository`; no service, provider, or feature screen should create ONNX sessions directly.

```dart
final embedding = await inference.embedImage(
  pixels: pixels,
  width: w,
  height: h,
);
```
