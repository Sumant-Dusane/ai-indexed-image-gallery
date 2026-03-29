use ort::value::Tensor;

use crate::shared::BBox;
use super::detection_preprocess::letterbox;
use super::detection_session::get_yolo_session;
use super::detection_nms::{RawDetection, apply_nms, CONFIDENCE_THRESHOLD};
use super::detection_types::Detection;

/// YOLO output dimensions (fixed for YOLOv8-nano).
const ANCHORS: usize = 8400;
const ROWS: usize = 84; // 4 bbox coords + 80 class scores

/// Map a COCO class index to the allowed label string, or `None` to skip.
/// Only classes listed in docs/models.md "YOLO class filter" are kept.
fn allowed_label(class_idx: usize) -> Option<&'static str> {
    match class_idx {
        0 => Some("person"),
        1 => Some("bicycle"),
        2 => Some("car"),
        3 => Some("motorcycle"),
        5 => Some("bus"),
        7 => Some("truck"),
        14 => Some("bird"),
        15 => Some("cat"),
        16 => Some("dog"),
        17 => Some("horse"),
        24 => Some("backpack"),
        25 => Some("umbrella"),
        26 => Some("handbag"),
        30 => Some("skis"),
        31 => Some("snowboard"),
        32 => Some("sports ball"),
        36 => Some("skateboard"),
        37 => Some("surfboard"),
        39 => Some("bottle"),
        40 => Some("wine glass"),
        41 => Some("cup"),
        45 => Some("bowl"),
        48 => Some("sandwich"),
        53 => Some("pizza"),
        55 => Some("cake"),
        56 => Some("chair"),
        57 => Some("couch"),
        59 => Some("bed"),
        60 => Some("dining table"),
        62 => Some("tv"),
        63 => Some("laptop"),
        67 => Some("phone"),
        73 => Some("book"),
        74 => Some("clock"),
        _ => None,
    }
}

/// Run YOLOv8-nano on `pixels` (RGB24 HWC), apply NMS, and return detections with
/// bounding boxes normalised to 0..1 relative to the original image dimensions.
pub fn detect_objects(pixels: Vec<u8>, width: u32, height: u32) -> Vec<Detection> {
    // 1. Letterbox preprocess → [1, 3, 640, 640] float32.
    let lb = letterbox(&pixels, width, height);

    let tensor = Tensor::<f32>::from_array(([1usize, 3, 640, 640], lb.data))
        .expect("Failed to create YOLO input tensor");

    // 2. Run session.
    let mut session = get_yolo_session()
        .lock()
        .expect("YOLO session mutex poisoned");

    let outputs = session
        .run(ort::inputs!["images" => tensor])
        .expect("YOLO inference failed");

    // 3. Extract output [1, 84, 8400] → flat vec length 84 × 8400.
    let raw: Vec<f32> = outputs["output0"]
        .try_extract_array::<f32>()
        .expect("Failed to extract YOLO output tensor")
        .iter()
        .copied()
        .collect();

    assert_eq!(
        raw.len(),
        ROWS * ANCHORS,
        "Unexpected YOLO output size: {} (expected {})",
        raw.len(),
        ROWS * ANCHORS
    );

    // 4. Parse detections.
    // Row-major layout: value at (row r, anchor i) = raw[r * ANCHORS + i].
    // Rows 0-3: cx, cy, w, h (in 640×640 space).
    // Rows 4-83: per-class confidence scores.
    let mut raw_detections: Vec<RawDetection> = Vec::new();

    for i in 0..ANCHORS {
        let cx = raw[0 * ANCHORS + i];
        let cy = raw[1 * ANCHORS + i];
        let w = raw[2 * ANCHORS + i];
        let h = raw[3 * ANCHORS + i];

        // Find the class with the highest score.
        let (class_idx, confidence) = (0usize..80)
            .map(|j| (j, raw[(4 + j) * ANCHORS + i]))
            .max_by(|a, b| a.1.partial_cmp(&b.1).unwrap())
            .unwrap();

        if confidence < CONFIDENCE_THRESHOLD {
            continue;
        }

        let Some(label) = allowed_label(class_idx) else {
            continue;
        };

        // Convert centre-format to corner-format (still in 640×640 pixel space).
        let x1 = cx - w / 2.0;
        let y1 = cy - h / 2.0;
        let x2 = cx + w / 2.0;
        let y2 = cy + h / 2.0;

        raw_detections.push(RawDetection { class_idx, label, confidence, x1, y1, x2, y2 });
    }

    // 5. Apply NMS.
    let kept = apply_nms(raw_detections);

    // 6. Invert letterbox transform and normalise to 0..1.
    let orig_w = width as f32;
    let orig_h = height as f32;

    kept.into_iter()
        .map(|d| {
            let x1 = ((d.x1 - lb.pad_x) / lb.scale).clamp(0.0, orig_w);
            let y1 = ((d.y1 - lb.pad_y) / lb.scale).clamp(0.0, orig_h);
            let x2 = ((d.x2 - lb.pad_x) / lb.scale).clamp(0.0, orig_w);
            let y2 = ((d.y2 - lb.pad_y) / lb.scale).clamp(0.0, orig_h);

            Detection {
                label: d.label.to_string(),
                confidence: d.confidence,
                bbox: BBox {
                    x: x1 / orig_w,
                    y: y1 / orig_h,
                    w: (x2 - x1) / orig_w,
                    h: (y2 - y1) / orig_h,
                },
            }
        })
        .collect()
}
