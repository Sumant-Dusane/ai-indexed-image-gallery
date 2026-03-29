use std::sync::{Mutex, OnceLock};

use ort::session::{Session, builder::GraphOptimizationLevel};

static FACENET_SESSION: OnceLock<Mutex<Session>> = OnceLock::new();

/// Returns the shared MobileFaceNet session, loading it lazily on first call.
/// Panics if `init_models()` has not been called.
pub fn get_facenet_session() -> &'static Mutex<Session> {
    FACENET_SESSION.get_or_init(|| {
        let model_dir = crate::shared::MODEL_DIR
            .get()
            .expect("init_models() must be called before embed_face()");
        let path = format!("{}/mobilefacenet_int8.onnx", model_dir);
        let session = Session::builder()
            .expect("Failed to create FaceNet session builder")
            .with_optimization_level(GraphOptimizationLevel::Level3)
            .expect("Failed to set FaceNet optimization level")
            .commit_from_file(&path)
            .expect("Failed to load MobileFaceNet model");
        Mutex::new(session)
    })
}
