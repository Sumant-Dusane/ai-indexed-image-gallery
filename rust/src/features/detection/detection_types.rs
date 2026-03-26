use crate::shared::BBox;

/// YOLO object detection result.
pub struct Detection {
    pub label: String,
    pub confidence: f32,
    pub bbox: BBox,
}
