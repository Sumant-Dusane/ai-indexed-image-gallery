use ort::value::Tensor;

use crate::shared::BBox;
use super::emotion_preprocess::preprocess_emotion;
use super::emotion_session::get_emotion_session;
use super::emotion_types::EmotionResult;

const EMOTION_LABELS: [&str; 8] = [
    "neutral",   // 0
    "happy",     // 1
    "sad",       // 2
    "surprised", // 3
    "fear",      // 4
    "disgust",   // 5
    "angry",     // 6
    "contempt",  // 7 — mapped to "neutral"
];

/// Crops the face region from `pixels`, runs EfficientNet-B0 emotion classification,
/// and returns the predicted label and softmax confidence.
/// Index 7 (contempt) is mapped to "neutral" per docs/models.md.
pub fn classify_emotion(pixels: Vec<u8>, width: u32, height: u32, bbox: BBox) -> EmotionResult {
    let preprocessed = preprocess_emotion(&pixels, width, height, &bbox);

    let tensor = Tensor::<f32>::from_array(([1usize, 3, 224, 224], preprocessed))
        .expect("Failed to create Emotion input tensor");

    let mut session = get_emotion_session()
        .lock()
        .expect("Emotion session mutex poisoned");

    let outputs = session
        .run(ort::inputs!["face" => tensor])
        .expect("Emotion inference failed");

    let logits: Vec<f32> = outputs["logits"]
        .try_extract_array::<f32>()
        .expect("Failed to extract Emotion logits")
        .iter()
        .copied()
        .collect();

    // Softmax over 8 logits.
    let max_logit = logits.iter().cloned().fold(f32::NEG_INFINITY, f32::max);
    let exps: Vec<f32> = logits.iter().map(|&l| (l - max_logit).exp()).collect();
    let sum_exps: f32 = exps.iter().sum();
    let probs: Vec<f32> = exps.iter().map(|&e| e / sum_exps).collect();

    // Argmax.
    let idx = probs
        .iter()
        .enumerate()
        .max_by(|a, b| a.1.partial_cmp(b.1).unwrap())
        .map(|(i, _)| i)
        .unwrap_or(0);

    let label = if idx == 7 { "neutral" } else { EMOTION_LABELS[idx] };
    let confidence = probs[idx];

    EmotionResult {
        label: label.to_string(),
        confidence,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn contempt_maps_to_neutral() {
        // Logits where index 7 is the highest.
        let logits = vec![0.0f32, 0.1, 0.2, 0.1, 0.0, 0.1, 0.2, 5.0];
        let max_logit = logits.iter().cloned().fold(f32::NEG_INFINITY, f32::max);
        let exps: Vec<f32> = logits.iter().map(|&l| (l - max_logit).exp()).collect();
        let sum_exps: f32 = exps.iter().sum();
        let probs: Vec<f32> = exps.iter().map(|&e| e / sum_exps).collect();
        let idx = probs
            .iter()
            .enumerate()
            .max_by(|a, b| a.1.partial_cmp(b.1).unwrap())
            .map(|(i, _)| i)
            .unwrap_or(0);
        let label = if idx == 7 { "neutral" } else { EMOTION_LABELS[idx] };
        assert_eq!(label, "neutral");
    }

    #[test]
    fn happy_label_correct() {
        // Logits where index 1 (happy) is highest.
        let logits = vec![0.0f32, 5.0, 0.1, 0.0, 0.0, 0.0, 0.0, 0.0];
        let max_logit = logits.iter().cloned().fold(f32::NEG_INFINITY, f32::max);
        let exps: Vec<f32> = logits.iter().map(|&l| (l - max_logit).exp()).collect();
        let sum_exps: f32 = exps.iter().sum();
        let probs: Vec<f32> = exps.iter().map(|&e| e / sum_exps).collect();
        let idx = probs
            .iter()
            .enumerate()
            .max_by(|a, b| a.1.partial_cmp(b.1).unwrap())
            .map(|(i, _)| i)
            .unwrap_or(0);
        let label = if idx == 7 { "neutral" } else { EMOTION_LABELS[idx] };
        assert_eq!(label, "happy");
    }
}
