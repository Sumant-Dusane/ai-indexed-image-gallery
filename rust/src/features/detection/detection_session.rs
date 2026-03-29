use std::sync::{Mutex, OnceLock};

use ort::session::{Session, builder::GraphOptimizationLevel};

static YOLO_SESSION: OnceLock<Mutex<Session>> = OnceLock::new();

/// Returns the shared YOLOv8-nano session, loading it lazily on first call.
/// Panics if `init_models()` has not been called.
pub fn get_yolo_session() -> &'static Mutex<Session> {
    YOLO_SESSION.get_or_init(|| {
        let model_dir = crate::shared::MODEL_DIR
            .get()
            .expect("init_models() must be called before detect_objects()");
        let path = format!("{}/yolov8n_int8.onnx", model_dir);
        let session = Session::builder()
            .expect("Failed to create YOLO session builder")
            .with_optimization_level(GraphOptimizationLevel::Level3)
            .expect("Failed to set YOLO optimization level")
            .commit_from_file(&path)
            .expect("Failed to load YOLOv8-nano model");
        Mutex::new(session)
    })
}
