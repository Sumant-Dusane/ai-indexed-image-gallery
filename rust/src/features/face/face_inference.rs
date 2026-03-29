use ort::value::Tensor;

use crate::shared::BBox;
use super::face_preprocess::{preprocess_face, l2_normalize};
use super::face_session::get_facenet_session;

/// Crops and preprocesses the face region, runs MobileFaceNet, and returns a
/// 128-dim L2-normalised embedding.
pub fn embed_face(pixels: Vec<u8>, width: u32, height: u32, bbox: BBox) -> Vec<f32> {
    let preprocessed = preprocess_face(&pixels, width, height, &bbox);

    let tensor = Tensor::<f32>::from_array(([1usize, 3, 112, 112], preprocessed))
        .expect("Failed to create FaceNet input tensor");

    let mut session = get_facenet_session()
        .lock()
        .expect("FaceNet session mutex poisoned");

    let outputs = session
        .run(ort::inputs!["face" => tensor])
        .expect("FaceNet inference failed");

    let raw: Vec<f32> = outputs["embedding"]
        .try_extract_array::<f32>()
        .expect("Failed to extract FaceNet embedding")
        .iter()
        .copied()
        .collect();

    l2_normalize(raw)
}
