use image::{ImageBuffer, Rgb, imageops};

const CLIP_MEAN: [f32; 3] = [0.48145466, 0.4578275, 0.40821073];
const CLIP_STD: [f32; 3] = [0.26862954, 0.26130258, 0.27577711];

/// Resize to 224×224 (bilinear), normalise with CLIP mean/std, return CHW float32 vec.
pub fn preprocess_image(pixels: &[u8], width: u32, height: u32) -> Vec<f32> {
    let img: ImageBuffer<Rgb<u8>, Vec<u8>> =
        ImageBuffer::from_raw(width, height, pixels.to_vec())
            .expect("pixel buffer size does not match width × height × 3");
    let resized = imageops::resize(&img, 224, 224, imageops::FilterType::Triangle);

    let mut data = vec![0f32; 3 * 224 * 224];
    for (x, y, pixel) in resized.enumerate_pixels() {
        let idx = y as usize * 224 + x as usize;
        let [r, g, b] = pixel.0;
        data[idx] = (r as f32 / 255.0 - CLIP_MEAN[0]) / CLIP_STD[0];
        data[224 * 224 + idx] = (g as f32 / 255.0 - CLIP_MEAN[1]) / CLIP_STD[1];
        data[2 * 224 * 224 + idx] = (b as f32 / 255.0 - CLIP_MEAN[2]) / CLIP_STD[2];
    }
    data
}

/// L2-normalise a vector in place and return it.
pub fn l2_normalize(mut v: Vec<f32>) -> Vec<f32> {
    let norm: f32 = v.iter().map(|x| x * x).sum::<f32>().sqrt();
    if norm > 1e-12 {
        for x in v.iter_mut() {
            *x /= norm;
        }
    }
    v
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Build a solid-colour RGB24 pixel buffer of the given size.
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
        let out = preprocess_image(&pixels, 64, 64);
        assert_eq!(out.len(), 3 * 224 * 224);
    }

    #[test]
    fn preprocess_channels_are_independent() {
        // Pure-red image: G and B channels should produce different values than R.
        let pixels = solid_rgb(32, 32, 255, 0, 0);
        let out = preprocess_image(&pixels, 32, 32);
        let r_val = out[0];
        let g_val = out[224 * 224];
        let b_val = out[2 * 224 * 224];
        assert!(
            (r_val - g_val).abs() > 0.1,
            "R and G channels should differ for a pure-red image"
        );
        assert!(
            (r_val - b_val).abs() > 0.1,
            "R and B channels should differ for a pure-red image"
        );
    }

    #[test]
    fn preprocess_normalisation_values() {
        // A pixel of value 255 in R should equal (1.0 - CLIP_MEAN[0]) / CLIP_STD[0].
        let pixels = solid_rgb(1, 1, 255, 0, 0);
        let out = preprocess_image(&pixels, 1, 1);
        let expected_r = (1.0f32 - 0.48145466) / 0.26862954;
        assert!(
            (out[0] - expected_r).abs() < 1e-4,
            "R channel: got {}, expected ~{expected_r}",
            out[0]
        );
    }

    #[test]
    fn l2_normalize_unit_norm() {
        let v = vec![3.0f32, 4.0];
        let out = l2_normalize(v);
        let norm: f32 = out.iter().map(|x| x * x).sum::<f32>().sqrt();
        assert!((norm - 1.0).abs() < 1e-6, "norm should be 1.0, got {norm}");
    }

    #[test]
    fn l2_normalize_zero_vector_unchanged() {
        let v = vec![0.0f32; 8];
        let out = l2_normalize(v.clone());
        assert_eq!(out, v, "zero vector should pass through unchanged");
    }
}
