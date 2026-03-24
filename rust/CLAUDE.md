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
  lib.rs                 ← bridge setup, module declarations
  api.rs                 ← bridge exports (all 6 functions + init_models)
  inference/
    mod.rs               ← init_models(), MODEL_DIR storage, OnceLock sessions
    clip.rs              ← embed_image(), embed_text(), preprocessing
    face.rs              ← embed_face(), preprocessing
    yolo.rs              ← detect_objects(), NMS, bbox scaling
    emotion.rs           ← classify_emotion(), preprocessing
  utils/
    phash.rs             ← compute_phash()
    nms.rs               ← non-maximum suppression
    preprocess.rs        ← shared resize/normalize helpers
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
