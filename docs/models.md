# docs/models.md — ML models

All models live in `assets/models/`. All INT8 quantized. ONNX opset 17.
Load lazily on first call. Cache as static `OnceLock<Session>` in Rust.
Never reload a session — one session per model for app lifetime.

---

## Model inventory

| File | Task | Input tensor | Output tensor | INT8 size |
|---|---|---|---|---|
| `mobileclip_s1_int8.onnx` | Image semantic embedding | `[1, 3, 224, 224]` float32 | `[1, 512]` float32 | ~6MB |
| `mobilefacenet_int8.onnx` | Face embedding | `[1, 3, 112, 112]` float32 | `[1, 128]` float32 | ~4MB |
| `yolov8n_int8.onnx` | Object detection | `[1, 3, 640, 640]` float32 | `[1, 84, 8400]` float32 | ~3MB |
| `efficientnet_emotion_int8.onnx` | Emotion classification | `[1, 3, 48, 48]` float32 | `[1, 7]` float32 (softmax) | ~5MB |

Total: ~18MB

---

## Preprocessing — exact steps per model

### MobileCLIP-S1 (image)
1. Resize image to 224×224 (bilinear)
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

### MobileFaceNet
1. Crop face region from original image using bbox (expand bbox 20% on each side, clamp to image bounds)
2. Resize crop to 112×112 (bilinear)
3. Convert to RGB float32
4. Normalize: `pixel = (pixel - 127.5) / 128.0`
5. Layout: CHW → `[1, 3, 112, 112]`
6. L2-normalize the 128-dim output vector before storing

### YOLOv8-nano
1. Resize image to 640×640 (letterbox padding, preserve aspect ratio)
2. Convert to RGB float32
3. Normalize: `pixel = pixel / 255.0`
4. Layout: CHW → `[1, 3, 640, 640]`
5. Output shape `[1, 84, 8400]`: 84 = 4 bbox coords + 80 class scores
6. Apply NMS: confidence threshold 0.35, IoU threshold 0.45
7. Scale bbox coords back to original image dimensions
8. Store bbox as normalised 0..1 values (divide by original w/h)

### EfficientNet-lite (emotion)
1. Crop same face region used for MobileFaceNet
2. Resize to 48×48 (bilinear)
3. Convert to RGB float32
4. Normalize: `pixel = pixel / 255.0`
5. Layout: CHW → `[1, 3, 48, 48]`
6. Output: softmax over 7 classes — take argmax for label, keep score as confidence

---

## Emotion class index mapping (fixed)

```rust
const EMOTION_LABELS: [&str; 7] = [
    "angry",     // 0
    "disgust",   // 1
    "fear",      // 2
    "happy",     // 3
    "neutral",   // 4
    "sad",       // 5
    "surprised", // 6
];
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
snowboard, skis, surfboard, skateboard, sports ball,
mountain (use 'outdoor' proxy), beach (use 'outdoor' proxy)
```

Non-person objects: insert into `detections` table.
Person boxes: do NOT insert into detections — feed to MobileFaceNet + emotion pipeline instead.

---

## pHash algorithm (in Rust)

1. Resize image to 32×32 grayscale
2. Apply 2D DCT
3. Take top-left 8×8 of DCT result (64 values)
4. Compute mean of those 64 values
5. Output: 64-bit integer where bit[i] = 1 if dct[i] > mean
6. Store as 16-char hex string in `photos.phash`
7. Dedup threshold: Hamming distance ≤ 8 = same image
