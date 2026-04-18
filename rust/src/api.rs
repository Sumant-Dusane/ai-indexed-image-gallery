// Facade: all bridge functions exposed to Dart.
// Types live in their feature or shared modules.

use crate::features::detection::Detection;
use crate::features::emotion::EmotionResult;
use crate::shared::BBox;

/// Installs a structured panic hook that replaces Rust's noisy default format.
/// Prints `[RUST_PANIC::<stem>:<line>] <message>` to stderr so Xcode output
/// matches the AppLogger format visible in the Flutter debug console.
fn setup_panic_hook() {
    std::panic::set_hook(Box::new(|info| {
        let location = info
            .location()
            .map(|l| {
                let stem = l
                    .file()
                    .split('/')
                    .last()
                    .unwrap_or(l.file())
                    .trim_end_matches(".rs");
                format!("{}:{}", stem, l.line())
            })
            .unwrap_or_else(|| "unknown".to_string());

        let payload = if let Some(s) = info.payload().downcast_ref::<&str>() {
            s.to_string()
        } else if let Some(s) = info.payload().downcast_ref::<String>() {
            s.clone()
        } else {
            "panic".to_string()
        };

        eprintln!("[RUST_PANIC::{}] {}", location, payload);
    }));
}

/// Stores the model directory path so ONNX sessions can load lazily on first use.
/// Must be called once at app startup before any inference function.
pub fn init_models(model_dir: String) {
    setup_panic_hook();
    ort::init().commit();
    // Silently ignore if already initialised (e.g. hot-reload, Riverpod async
    // re-run). The OnceLock already holds the correct path.
    let _ = crate::shared::MODEL_DIR.set(model_dir);
}

/// Computes a 512-dim L2-normalised CLIP image embedding from raw RGB24 pixels.
pub fn embed_image(pixels: Vec<u8>, width: u32, height: u32) -> Vec<f32> {
    crate::features::clip::clip_inference::embed_image(pixels, width, height)
}

/// Computes a 512-dim L2-normalised CLIP text embedding for the given query string.
pub fn embed_text(query: String) -> Vec<f32> {
    crate::features::clip::clip_inference::embed_text(query)
}

/// Runs YOLOv8-nano object detection on raw RGB24 pixels.
pub fn detect_objects(pixels: Vec<u8>, width: u32, height: u32) -> Vec<Detection> {
    crate::features::detection::detection_inference::detect_objects(pixels, width, height)
}

/// Computes a 128-dim MobileFaceNet face embedding using the given bounding box.
pub fn embed_face(pixels: Vec<u8>, width: u32, height: u32, bbox: BBox) -> Vec<f32> {
    crate::features::face::face_inference::embed_face(pixels, width, height, bbox)
}

/// Classifies the emotion in the face region described by bbox.
pub fn classify_emotion(pixels: Vec<u8>, width: u32, height: u32, bbox: BBox) -> EmotionResult {
    crate::features::emotion::emotion_inference::classify_emotion(pixels, width, height, bbox)
}

/// Computes a 64-bit perceptual hash for the given pixels, returned as a 16-char hex string.
pub fn compute_phash(pixels: Vec<u8>, width: u32, height: u32) -> String {
    crate::shared::utils::phash::compute_phash(pixels, width, height)
}
