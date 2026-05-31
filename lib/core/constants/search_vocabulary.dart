import 'package:ai_gallery/core/constants/yolo_detection_labels.dart';

/// Central vocabulary used by the rule-based search intent parser.
///
/// Keep aliases lowercase. Add new terms here when the parser needs to
/// recognise more user-facing words without changing query pipeline logic.
abstract final class SearchVocabulary {
  static const emotionAliases = <String, String>{
    'laughing': 'happy',
    'smiling': 'happy',
    'smile': 'happy',
    'happy': 'happy',
    'crying': 'sad',
    'sad': 'sad',
    'upset': 'sad',
    'angry': 'angry',
    'anger': 'angry',
    'scared': 'fear',
    'afraid': 'fear',
    'shocked': 'surprised',
    'surprised': 'surprised',
    'disgusted': 'disgust',
  };

  /// Maps user-facing synonyms to the lowercase YOLO label stored in SQLite.
  static const objectAliases = <String, String>{
    'automobile': 'car',
    'mobile': 'phone',
    'puppy': 'dog',
    'kitten': 'cat',
    'sofa': 'couch',
    'glass': 'wine glass',
    'table': 'dining table',
    'bag': 'handbag',
    'ski': 'skis',
    'ball': 'sports ball',
  };

  static bool isStoredYoloLabel(String label) =>
      YoloDetectionLabels.indexedLabels.contains(label);
}
