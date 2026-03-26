# CLAUDE.md — Rust inference layer

Before working here, read: `docs/models.md` (preprocessing steps, tensor shapes, reference code)

---

## Responsibility

This crate owns all ML inference and pixel math.
It does NOT own photo library access — that stays in Dart/photo_manager.
Dart passes raw pixel bytes. Rust returns structured data.

## Exposed bridge functions — exact signatures, do not rename

```rust
pub fn embed_image(pixels: Vec<u8>, width: u32, height: u32) -> Vec<f32>
pub fn detect_objects(pixels: Vec<u8>, width: u32, height: u32) -> Vec<Detection>
pub fn embed_face(pixels: Vec<u8>, width: u32, height: u32, bbox: BBox) -> Vec<f32>
pub fn classify_emotion(pixels: Vec<u8>, width: u32, height: u32, bbox: BBox) -> EmotionResult
pub fn compute_phash(pixels: Vec<u8>, width: u32, height: u32) -> String
pub fn embed_text(query: String) -> Vec<f32>
```

Plus one init function:
```rust
pub fn init_models(model_dir: String)
```

## Shared types (exported to Dart via bridge)

```rust
pub struct Detection {
    pub label: String,
    pub confidence: f32,
    pub bbox: BBox,
}

pub struct BBox {
    pub x: f32,   // normalised 0..1
    pub y: f32,
    pub w: f32,
    pub h: f32,
}

pub struct EmotionResult {
    pub label: String,
    pub confidence: f32,
}
```

## Session management

- One `OnceLock<Session>` per model at module level (4 total: CLIP, FaceNet, YOLO, Emotion)
- Sessions load on first call, never reload
- ONNX model files accessed via path passed from Dart at app init
  (`init_models(model_dir: String)` stores the path, sessions use it lazily)
- See `docs/models.md` "Reference: ort crate inference pattern" for the exact code pattern

## Threading

- Each bridge function call runs in its own Rust thread (flutter_rust_bridge default)
- Use `rayon` for internal parallelism within a single inference call if beneficial
- Do not share mutable state across threads — Sessions are read-only after init

## File layout

```
rust/src/
  lib.rs                          ← bridge setup, module declarations
  api.rs                          ← bridge exports (all 6 functions + init_models)
  features/
    mod.rs
    clip/
      mod.rs
      clip_session.rs             ← OnceLock<Session> for MobileCLIP-S1
      clip_inference.rs           ← embed_image(), embed_text()
      clip_preprocess.rs          ← resize 224x224, normalize CHW, L2-normalize
    face/
      mod.rs
      face_session.rs             ← OnceLock<Session> for MobileFaceNet
      face_inference.rs           ← embed_face()
      face_preprocess.rs          ← crop bbox (20% expand), resize 112x112, normalize CHW
    detection/
      mod.rs
      detection_types.rs          ← Detection struct
      detection_session.rs        ← OnceLock<Session> for YOLOv8-nano
      detection_inference.rs      ← detect_objects(), bbox scaling
      detection_preprocess.rs     ← letterbox resize 640x640, normalize CHW
      detection_nms.rs            ← non-maximum suppression
    emotion/
      mod.rs
      emotion_types.rs            ← EmotionResult struct
      emotion_session.rs          ← OnceLock<Session> for EfficientNet-lite
      emotion_inference.rs        ← classify_emotion()
      emotion_preprocess.rs       ← crop bbox, resize 48x48, normalize CHW
  shared/
    mod.rs
    types/
      mod.rs
      bbox.rs                     ← BBox struct (shared by detection, face, emotion)
    utils/
      mod.rs
      phash.rs                    ← compute_phash()
```

## Dependencies — Cargo.toml

```toml
[dependencies]
flutter_rust_bridge = "=2.0.0"
ort = { version = "2.0", features = ["load-dynamic"] }
image = "0.25"
rayon = "1.10"
once_cell = "1.19"
ndarray = "0.16"
tokenizers = ">=0.19"
```

Note: `tokenizers` is for BPE tokenization in `embed_text()`. See `docs/models.md` for details.
