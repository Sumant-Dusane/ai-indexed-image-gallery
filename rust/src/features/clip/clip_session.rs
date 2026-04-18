use std::sync::{Mutex, OnceLock};

use ort::session::{Session, builder::GraphOptimizationLevel};
use tokenizers::Tokenizer;

static CLIP_IMAGE_SESSION: OnceLock<Mutex<Session>> = OnceLock::new();
static CLIP_TEXT_SESSION: OnceLock<Mutex<Session>> = OnceLock::new();
static CLIP_TOKENIZER: OnceLock<Tokenizer> = OnceLock::new();

pub fn get_image_session() -> &'static Mutex<Session> {
    CLIP_IMAGE_SESSION.get_or_init(|| {
        let model_dir = crate::shared::MODEL_DIR
            .get()
            .expect("init_models() must be called before embed_image()");
        let path = format!("{}/mobileclip_s1_image_int8.onnx", model_dir);
        eprintln!("[RUST::clip] loading image model from: {}", path);
        let session = Session::builder()
            .expect("Failed to create session builder")
            .with_optimization_level(GraphOptimizationLevel::Level3)
            .expect("Failed to set optimization level")
            .commit_from_file(&path)
            .expect("Failed to load CLIP image model");
        eprintln!("[RUST::clip] image model loaded ok");
        Mutex::new(session)
    })
}

pub fn get_text_session() -> &'static Mutex<Session> {
    CLIP_TEXT_SESSION.get_or_init(|| {
        let model_dir = crate::shared::MODEL_DIR
            .get()
            .expect("init_models() must be called before embed_text()");
        let path = format!("{}/mobileclip_s1_text_int8.onnx", model_dir);
        let session = Session::builder()
            .expect("Failed to create session builder")
            .with_optimization_level(GraphOptimizationLevel::Level3)
            .expect("Failed to set optimization level")
            .commit_from_file(&path)
            .expect("Failed to load CLIP text model");
        Mutex::new(session)
    })
}

pub fn get_tokenizer() -> &'static Tokenizer {
    CLIP_TOKENIZER.get_or_init(|| {
        let model_dir = crate::shared::MODEL_DIR
            .get()
            .expect("init_models() must be called before embed_text()");
        let path = format!("{}/bpe_vocab.json", model_dir);
        Tokenizer::from_file(&path).expect("Failed to load BPE tokenizer")
    })
}
