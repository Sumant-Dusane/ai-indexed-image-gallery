use std::sync::{Mutex, OnceLock};

use ort::session::{Session, builder::GraphOptimizationLevel};

static EMOTION_SESSION: OnceLock<Mutex<Session>> = OnceLock::new();

/// Returns the shared EfficientNet-B0 emotion session, loading it lazily on first call.
/// Panics if `init_models()` has not been called.
pub fn get_emotion_session() -> &'static Mutex<Session> {
    EMOTION_SESSION.get_or_init(|| {
        let model_dir = crate::shared::MODEL_DIR
            .get()
            .expect("init_models() must be called before classify_emotion()");
        let path = format!("{}/emotion_enet_b0_int8.onnx", model_dir);
        let session = Session::builder()
            .expect("Failed to create Emotion session builder")
            .with_optimization_level(GraphOptimizationLevel::Level3)
            .expect("Failed to set Emotion optimization level")
            .commit_from_file(&path)
            .expect("Failed to load EfficientNet-B0 emotion model");
        Mutex::new(session)
    })
}
