/// Canonical subset of YOLO detector labels retained by the app.
///
/// The model emits 80 COCO classes. The app indexes only this subset to limit
/// storage. Values must match the lowercase strings stored in SQLite exactly.
abstract final class YoloDetectionLabels {
  static const person = 'person';

  static const retainedByClassIndex = <int, String>{
    0: person,
    1: 'bicycle',
    2: 'car',
    3: 'motorcycle',
    5: 'bus',
    7: 'truck',
    14: 'bird',
    15: 'cat',
    16: 'dog',
    17: 'horse',
    24: 'backpack',
    25: 'umbrella',
    26: 'handbag',
    30: 'skis',
    31: 'snowboard',
    32: 'sports ball',
    36: 'skateboard',
    37: 'surfboard',
    39: 'bottle',
    40: 'wine glass',
    41: 'cup',
    45: 'bowl',
    48: 'sandwich',
    53: 'pizza',
    55: 'cake',
    56: 'chair',
    57: 'couch',
    59: 'bed',
    60: 'dining table',
    62: 'tv',
    63: 'laptop',
    67: 'phone',
    73: 'book',
    74: 'clock',
  };

  /// Person detections feed the face pipeline and are not inserted into the
  /// detections table, so exclude them from metadata-searchable labels.
  static final indexedLabels = Set<String>.unmodifiable(
    retainedByClassIndex.values.where((label) => label != person),
  );
}
