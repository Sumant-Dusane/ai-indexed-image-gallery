/// Bounding box with normalised 0..1 coordinates.
/// Shared across detection, face, and emotion features.
pub struct BBox {
    pub x: f32,
    pub y: f32,
    pub w: f32,
    pub h: f32,
}
