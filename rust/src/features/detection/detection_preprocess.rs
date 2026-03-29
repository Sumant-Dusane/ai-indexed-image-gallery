use image::{ImageBuffer, Rgb, imageops};

const SIZE: u32 = 640;
const PAD_VALUE: u8 = 114;

/// Output of letterbox preprocessing plus the parameters needed to invert the transform.
pub struct LetterboxResult {
    /// Flattened CHW float32, shape [3, 640, 640], normalised to [0, 1].
    pub data: Vec<f32>,
    /// Uniform scale applied to both axes: resized_side = orig_side × scale.
    pub scale: f32,
    /// Horizontal padding in pixels on the 640×640 canvas (left/right equal).
    pub pad_x: f32,
    /// Vertical padding in pixels on the 640×640 canvas (top/bottom equal).
    pub pad_y: f32,
}

/// Letterbox-resize `pixels` (RGB24, HWC) to 640×640 preserving aspect ratio,
/// pad with gray (114), normalise to [0, 1] float32, and return CHW layout.
pub fn letterbox(pixels: &[u8], width: u32, height: u32) -> LetterboxResult {
    let img: ImageBuffer<Rgb<u8>, Vec<u8>> =
        ImageBuffer::from_raw(width, height, pixels.to_vec())
            .expect("pixel buffer does not match width × height × 3");

    // Uniform scale so the longest edge fits within SIZE.
    let scale = (SIZE as f32 / width as f32).min(SIZE as f32 / height as f32);
    let new_w = (width as f32 * scale).round() as u32;
    let new_h = (height as f32 * scale).round() as u32;

    let resized = imageops::resize(&img, new_w, new_h, imageops::FilterType::Triangle);

    // Centre padding (kept as f32 for inverse-transform precision).
    let pad_x = (SIZE as f32 - new_w as f32) / 2.0;
    let pad_y = (SIZE as f32 - new_h as f32) / 2.0;

    // Create a gray 640×640 canvas and blit the resized image onto it.
    let mut canvas: ImageBuffer<Rgb<u8>, Vec<u8>> =
        ImageBuffer::from_pixel(SIZE, SIZE, Rgb([PAD_VALUE, PAD_VALUE, PAD_VALUE]));
    for (x, y, pixel) in resized.enumerate_pixels() {
        canvas.put_pixel(x + pad_x.round() as u32, y + pad_y.round() as u32, *pixel);
    }

    // Convert to CHW float32, normalised to [0, 1].
    let n = (SIZE * SIZE) as usize;
    let mut data = vec![0f32; 3 * n];
    for (x, y, pixel) in canvas.enumerate_pixels() {
        let idx = y as usize * SIZE as usize + x as usize;
        let [r, g, b] = pixel.0;
        data[idx] = r as f32 / 255.0;
        data[n + idx] = g as f32 / 255.0;
        data[2 * n + idx] = b as f32 / 255.0;
    }

    LetterboxResult { data, scale, pad_x, pad_y }
}
