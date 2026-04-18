use ort::value::Tensor;

use super::clip_preprocess::{l2_normalize, preprocess_image};
use super::clip_session::{get_image_session, get_text_session, get_tokenizer};

/// Returns a 512-dim L2-normalised CLIP image embedding.
pub fn embed_image(pixels: Vec<u8>, width: u32, height: u32) -> Vec<f32> {
    eprintln!("[RUST::clip] embed_image start: {}x{}", width, height);
    let preprocessed = preprocess_image(&pixels, width, height);
    eprintln!("[RUST::clip] preprocess done");

    let tensor = Tensor::<f32>::from_array(([1usize, 3, 224, 224], preprocessed))
        .expect("Failed to create CLIP image input tensor");
    eprintln!("[RUST::clip] tensor created, acquiring session lock");

    let mut session = get_image_session()
        .lock()
        .expect("CLIP image session mutex poisoned");
    eprintln!("[RUST::clip] session locked, running inference");

    let outputs = session
        .run(ort::inputs!["image" => tensor])
        .expect("CLIP image inference failed");
    eprintln!("[RUST::clip] inference done, extracting output");

    let raw: Vec<f32> = outputs["embedding"]
        .try_extract_array::<f32>()
        .expect("Failed to extract CLIP image embedding")
        .iter()
        .copied()
        .collect();
    eprintln!("[RUST::clip] embed_image done: {} dims", raw.len());

    l2_normalize(raw)
}

/// Returns a 512-dim L2-normalised CLIP text embedding.
pub fn embed_text(query: String) -> Vec<f32> {
    let encoding = get_tokenizer()
        .encode(query.as_str(), true)
        .expect("BPE tokenisation failed");

    // Truncate then pad to exactly 77 tokens.
    let mut ids: Vec<i32> = encoding.get_ids().iter().map(|&id| id as i32).collect();
    ids.truncate(77);
    ids.resize(77, 0);

    let tensor = Tensor::<i32>::from_array(([1usize, 77], ids))
        .expect("Failed to create CLIP text input tensor");

    let mut session = get_text_session()
        .lock()
        .expect("CLIP text session mutex poisoned");

    let outputs = session
        .run(ort::inputs!["tokens" => tensor])
        .expect("CLIP text inference failed");

    let raw: Vec<f32> = outputs["embedding"]
        .try_extract_array::<f32>()
        .expect("Failed to extract CLIP text embedding")
        .iter()
        .copied()
        .collect();

    l2_normalize(raw)
}
