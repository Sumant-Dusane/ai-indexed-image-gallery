// Emotion preprocessing: crop bbox (expand 20%, clamp), resize 224×224, normalize CHW.
// Input tensor: [1, 3, 224, 224]. Normalize: pixel = pixel / 255.0.
// NOTE: spec (docs/models.md) specifies 224×224 — matches emotion_enet_b0_int8.onnx input shape.

use image::{ImageBuffer, Rgb, imageops};

use crate::shared::BBox;

/// Expand bbox by 20% on each side, clamp to image bounds, resize crop to
/// 224×224 (bilinear), and normalise with `pixel / 255.0`.
/// Returns a flat CHW float32 vec of length 3 × 224 × 224.
pub fn preprocess_emotion(pixels: &[u8], width: u32, height: u32, bbox: &BBox) -> Vec<f32> {
    let img: ImageBuffer<Rgb<u8>, Vec<u8>> =
        ImageBuffer::from_raw(width, height, pixels.to_vec())
            .expect("pixel buffer size does not match width × height × 3");

    // Convert normalised top-left + size bbox to pixel corner coordinates.
    let x1_px = bbox.x * width as f32;
    let y1_px = bbox.y * height as f32;
    let x2_px = (bbox.x + bbox.w) * width as f32;
    let y2_px = (bbox.y + bbox.h) * height as f32;

    // Expand 20% on each side.
    let pad_x = bbox.w * width as f32 * 0.2;
    let pad_y = bbox.h * height as f32 * 0.2;

    let x1 = (x1_px - pad_x).max(0.0) as u32;
    let y1 = (y1_px - pad_y).max(0.0) as u32;
    let x2 = (x2_px + pad_x).min(width as f32) as u32;
    let y2 = (y2_px + pad_y).min(height as f32) as u32;

    let crop_w = (x2 - x1).max(1);
    let crop_h = (y2 - y1).max(1);

    let cropped = imageops::crop_imm(&img, x1, y1, crop_w, crop_h).to_image();
    let resized = imageops::resize(&cropped, 224, 224, imageops::FilterType::Triangle);

    let mut data = vec![0f32; 3 * 224 * 224];
    for (x, y, pixel) in resized.enumerate_pixels() {
        let idx = y as usize * 224 + x as usize;
        let [r, g, b] = pixel.0;
        data[idx] = r as f32 / 255.0;
        data[224 * 224 + idx] = g as f32 / 255.0;
        data[2 * 224 * 224 + idx] = b as f32 / 255.0;
    }
    data
}

#[cfg(test)]
mod tests {
    use super::*;

    fn solid_rgb(width: u32, height: u32, r: u8, g: u8, b: u8) -> Vec<u8> {
        let n = (width * height) as usize;
        let mut buf = Vec::with_capacity(n * 3);
        for _ in 0..n {
            buf.extend_from_slice(&[r, g, b]);
        }
        buf
    }

    #[test]
    fn preprocess_output_length() {
        let pixels = solid_rgb(64, 64, 128, 64, 32);
        let bbox = BBox { x: 0.1, y: 0.1, w: 0.8, h: 0.8 };
        let out = preprocess_emotion(&pixels, 64, 64, &bbox);
        assert_eq!(out.len(), 3 * 224 * 224);
    }

    #[test]
    fn preprocess_normalisation_range() {
        // White image: all values should be 1.0.
        let pixels = solid_rgb(64, 64, 255, 255, 255);
        let bbox = BBox { x: 0.0, y: 0.0, w: 1.0, h: 1.0 };
        let out = preprocess_emotion(&pixels, 64, 64, &bbox);
        assert!((out[0] - 1.0f32).abs() < 1e-6, "expected 1.0, got {}", out[0]);
    }
}
