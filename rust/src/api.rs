// Facade: declares all bridge functions exposed to Dart.
// No type definitions here — types live in their feature or shared modules.
// Inference implementations will live in crate::features::* (Phase 2+).

use crate::shared::BBox;
use crate::features::detection::Detection;
use crate::features::emotion::EmotionResult;

/// Initialises all ONNX sessions from the given model directory.
/// Must be called once before any inference function.
pub fn init_models(model_dir: String) {
    todo!()
}

/// Computes a 512-dim CLIP image embedding from raw RGB24 pixels.
pub fn embed_image(pixels: Vec<u8>, width: u32, height: u32) -> Vec<f32> {
    todo!()
}

/// Runs YOLOv8-nano object detection on raw RGB24 pixels.
pub fn detect_objects(pixels: Vec<u8>, width: u32, height: u32) -> Vec<Detection> {
    todo!()
}

/// Computes a 128-dim MobileFaceNet face embedding using the given bounding box.
pub fn embed_face(pixels: Vec<u8>, width: u32, height: u32, bbox: BBox) -> Vec<f32> {
    todo!()
}

/// Classifies the emotion in the face region described by bbox.
pub fn classify_emotion(pixels: Vec<u8>, width: u32, height: u32, bbox: BBox) -> EmotionResult {
    todo!()
}

/// Computes a 64-bit perceptual hash for the given pixels, returned as a 16-char hex string.
pub fn compute_phash(pixels: Vec<u8>, width: u32, height: u32) -> String {
    todo!()
}

/// Computes a 512-dim CLIP text embedding for the given query string.
pub fn embed_text(query: String) -> Vec<f32> {
    todo!()
}
