use image::{ImageBuffer, Rgb, imageops};

/// Compute a 64-bit perceptual hash (pHash) for the given RGB24 pixels.
/// Algorithm (docs/models.md):
///   1. Resize to 32×32 grayscale
///   2. Apply 2D DCT-II
///   3. Take top-left 8×8 block (64 values)
///   4. Compute mean of those 64 values
///   5. Bit i = 1 if dct[i] > mean
///   6. Return as 16-char lowercase hex string
pub fn compute_phash(pixels: Vec<u8>, width: u32, height: u32) -> String {
    let img: ImageBuffer<Rgb<u8>, Vec<u8>> =
        ImageBuffer::from_raw(width, height, pixels)
            .expect("pixel buffer size does not match width × height × 3");

    // Resize to 32×32 and convert to grayscale float.
    let resized = imageops::resize(&img, 32, 32, imageops::FilterType::Triangle);
    let gray: Vec<f32> = resized
        .pixels()
        .map(|p| {
            let [r, g, b] = p.0;
            // Standard luminance weights.
            0.299 * r as f32 + 0.587 * g as f32 + 0.114 * b as f32
        })
        .collect();

    // 2D DCT-II (separable: rows then columns).
    let dct = dct2d(&gray, 32);

    // Top-left 8×8 block.
    let mut block = [0f32; 64];
    for row in 0..8usize {
        for col in 0..8usize {
            block[row * 8 + col] = dct[row * 32 + col];
        }
    }

    // Mean of 64 values.
    let mean: f32 = block.iter().sum::<f32>() / 64.0;

    // Pack 64 bits.
    let mut hash: u64 = 0;
    for (i, &val) in block.iter().enumerate() {
        if val > mean {
            hash |= 1u64 << i;
        }
    }

    format!("{:016x}", hash)
}

/// Separable 2D DCT-II on an N×N signal stored in row-major order.
/// Returns an N×N result in the same layout.
fn dct2d(signal: &[f32], n: usize) -> Vec<f32> {
    // Step 1: DCT-II along each row.
    let mut tmp = vec![0f32; n * n];
    for row in 0..n {
        dct1d(&signal[row * n..(row + 1) * n], &mut tmp[row * n..(row + 1) * n], n);
    }

    // Step 2: DCT-II along each column.
    let mut result = vec![0f32; n * n];
    let mut col_in = vec![0f32; n];
    let mut col_out = vec![0f32; n];
    for col in 0..n {
        for row in 0..n {
            col_in[row] = tmp[row * n + col];
        }
        dct1d(&col_in, &mut col_out, n);
        for row in 0..n {
            result[row * n + col] = col_out[row];
        }
    }

    result
}

/// 1D DCT-II: F[k] = sum_{x=0}^{N-1} f[x] * cos(pi*(2x+1)*k / (2N)).
/// Normalisation is omitted intentionally — only relative magnitudes matter for pHash.
fn dct1d(input: &[f32], output: &mut [f32], n: usize) {
    let scale = std::f32::consts::PI / (2.0 * n as f32);
    for k in 0..n {
        let mut sum = 0f32;
        for x in 0..n {
            sum += input[x] * ((2 * x + 1) as f32 * k as f32 * scale).cos();
        }
        output[k] = sum;
    }
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
    fn phash_length_is_16() {
        let pixels = solid_rgb(64, 64, 128, 64, 32);
        let hash = compute_phash(pixels, 64, 64);
        assert_eq!(hash.len(), 16, "pHash must be a 16-char hex string, got: {hash}");
    }

    #[test]
    fn phash_is_valid_hex() {
        let pixels = solid_rgb(64, 64, 200, 100, 50);
        let hash = compute_phash(pixels, 64, 64);
        assert!(
            hash.chars().all(|c| c.is_ascii_hexdigit()),
            "pHash must contain only hex digits, got: {hash}"
        );
    }

    #[test]
    fn identical_images_have_identical_hash() {
        let pixels = solid_rgb(128, 128, 77, 88, 99);
        let h1 = compute_phash(pixels.clone(), 128, 128);
        let h2 = compute_phash(pixels, 128, 128);
        assert_eq!(h1, h2, "identical images must produce identical pHash");
    }

    #[test]
    fn hamming_distance_of_same_image_is_zero() {
        let pixels = solid_rgb(64, 64, 10, 20, 30);
        let h1 = u64::from_str_radix(&compute_phash(pixels.clone(), 64, 64), 16).unwrap();
        let h2 = u64::from_str_radix(&compute_phash(pixels, 64, 64), 16).unwrap();
        assert_eq!((h1 ^ h2).count_ones(), 0);
    }
}
