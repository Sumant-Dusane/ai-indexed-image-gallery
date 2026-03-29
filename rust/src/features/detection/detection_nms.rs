/// Minimum class confidence to keep a detection (before IoU suppression).
pub const CONFIDENCE_THRESHOLD: f32 = 0.35;

/// Minimum IoU between two same-class boxes to suppress the lower-confidence one.
pub const IOU_THRESHOLD: f32 = 0.45;

/// A raw YOLO detection using x1/y1/x2/y2 pixel coordinates on the 640×640 canvas.
pub struct RawDetection {
    pub class_idx: usize,
    pub label: &'static str,
    pub confidence: f32,
    pub x1: f32,
    pub y1: f32,
    pub x2: f32,
    pub y2: f32,
}

/// Filter by `CONFIDENCE_THRESHOLD`, then apply per-class greedy NMS with `IOU_THRESHOLD`.
pub fn apply_nms(mut detections: Vec<RawDetection>) -> Vec<RawDetection> {
    detections.retain(|d| d.confidence >= CONFIDENCE_THRESHOLD);

    // Sort descending by confidence so we keep the highest-scoring box of each group.
    detections.sort_unstable_by(|a, b| {
        b.confidence.partial_cmp(&a.confidence).unwrap()
    });

    let n = detections.len();
    let mut suppressed = vec![false; n];

    for i in 0..n {
        if suppressed[i] {
            continue;
        }
        for j in (i + 1)..n {
            if suppressed[j] {
                continue;
            }
            if detections[i].class_idx == detections[j].class_idx
                && iou(&detections[i], &detections[j]) >= IOU_THRESHOLD
            {
                suppressed[j] = true;
            }
        }
    }

    detections
        .into_iter()
        .zip(suppressed)
        .filter_map(|(d, s)| if !s { Some(d) } else { None })
        .collect()
}

fn iou(a: &RawDetection, b: &RawDetection) -> f32 {
    let ix1 = a.x1.max(b.x1);
    let iy1 = a.y1.max(b.y1);
    let ix2 = a.x2.min(b.x2);
    let iy2 = a.y2.min(b.y2);

    let inter = (ix2 - ix1).max(0.0) * (iy2 - iy1).max(0.0);
    if inter == 0.0 {
        return 0.0;
    }

    let area_a = (a.x2 - a.x1) * (a.y2 - a.y1);
    let area_b = (b.x2 - b.x1) * (b.y2 - b.y1);
    inter / (area_a + area_b - inter)
}
