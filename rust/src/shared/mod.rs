pub mod types;
pub mod utils;
pub use types::BBox;

use std::sync::OnceLock;

/// Model directory path set once by `init_models()`.
/// All session getters read this before loading ONNX files.
pub static MODEL_DIR: OnceLock<String> = OnceLock::new();
