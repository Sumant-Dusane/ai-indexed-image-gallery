# docs/search.md — Search / query pipeline (Phase 4)

Owned by: `lib/services/query_service.dart`
State exposed via: `lib/core/providers/search_provider.dart`

---

## QueryService public API

```dart
class QueryService {
  // Main entry point. Returns ranked results.
  Future<List<SearchResult>> search(String query);

  // Called by provider with debounce — same as search().
  Stream<List<SearchResult>> searchStream(String query);
}
```

---

## 6-step pipeline — implement in order

### Step 1 — Parse intent (pure Dart, no ML)

Extract structured hints from the raw query string:

```dart
@freezed
class QueryIntent with _$QueryIntent {
  const factory QueryIntent({
    DateTimeRange? dateRange,
    int? clusterId,
    String? emotion,
    required String cleanQuery,
  }) = _QueryIntent;
}
```

**Date parsing — handle these patterns:**
```
"last year"        → full previous calendar year
"this year"        → Jan 1 current year → now
"last month"       → full previous calendar month
"this month"       → 1st of current month → now
"in 2023"          → full year 2023
"in january"       → January of current year
"yesterday"        → full previous day
"last week"        → Mon–Sun of previous week
"recent" / "lately"→ last 30 days
```

**Emotion mapping — check query for these words, map to DB emotion:**
```dart
const Map<String, String> emotionAliases = {
  'laughing':  'happy',
  'smiling':   'happy',
  'smile':     'happy',
  'happy':     'happy',
  'crying':    'sad',
  'sad':       'sad',
  'upset':     'sad',
  'angry':     'angry',
  'anger':     'angry',
  'scared':    'fear',
  'afraid':    'fear',
  'shocked':   'surprised',
  'surprised': 'surprised',
  'disgusted': 'disgust',
};
```

**Person name matching:**
```dart
// Query: SELECT id, name FROM clusters WHERE name IS NOT NULL
// Check if any word in query matches any cluster name (case-insensitive)
// If match: set clusterId, remove matching word from cleanQuery
```

---

### Step 2 — Encode text

```dart
final embedding = await inferenceRepository.embedText(intent.cleanQuery);
// Returns List<double> length 512, L2-normalised
// Skip this step if cleanQuery is empty after Step 1 stripping
```

---

### Step 3 — Vector search

```sql
SELECT p.id, p.local_path, p.taken_at,
       vec_distance_cosine(pv.embedding, ?) AS score
FROM photo_clip_vss pv
JOIN photos p ON pv.photo_id = p.id
ORDER BY score ASC
LIMIT 200
```

Bind: embedding vector as blob.

---

### Step 4 — Metadata filters (apply as SQL WHERE clauses on Step 3)

Add filters only if the corresponding hint is present:

```sql
-- Date filter (if dateRange != null):
AND p.taken_at BETWEEN :start AND :end

-- Person filter (if clusterId != null):
AND EXISTS (
  SELECT 1 FROM faces f
  WHERE f.photo_id = p.id AND f.cluster_id = :clusterId
)

-- Emotion filter (if emotion != null):
AND EXISTS (
  SELECT 1 FROM faces f
  WHERE f.photo_id = p.id AND f.emotion = :emotion
)

-- Object label filter (if cleanQuery contains known YOLO label):
AND EXISTS (
  SELECT 1 FROM detections d
  WHERE d.photo_id = p.id AND d.label LIKE :label
)
```

Build the WHERE clause dynamically in Dart. Combine Steps 3+4 into one query.

---

### Step 5 — Re-rank

```dart
double finalScore(double vectorScore, DateTime? takenAt) {
  final daysSince = takenAt == null ? 365.0
    : DateTime.now().difference(takenAt).inDays.toDouble();
  final recencyScore = 1.0 / (1.0 + daysSince / 365.0);
  // vectorScore is cosine distance: lower = better match, invert for combination
  final semanticScore = 1.0 - vectorScore;
  return 0.7 * semanticScore + 0.3 * recencyScore;
  // Higher final score = better result
}
// Sort descending by finalScore, take top 50
```

---

### Step 6 — Return

Return `List<SearchResult>` capped at 50 items, sorted by finalScore descending.

---

## SearchProvider

```dart
@freezed
class SearchState with _$SearchState {
  const factory SearchState({
    @Default('') String query,
    @Default([]) List<SearchResult> results,
    @Default(false) bool isSearching,
    @Default(false) bool indexingPartial,
  }) = _SearchState;
}

// Debounce: 400ms
// Minimum query length: 2 characters
// While indexing is still running: set indexingPartial = true
//   (don't block search — return partial results from what's indexed so far)

@riverpod
class SearchNotifier extends _$SearchNotifier {
  @override
  SearchState build() => const SearchState();

  Future<void> search(String query) async {
    state = state.copyWith(query: query, isSearching: true);
    final results = await ref.read(queryServiceProvider).search(query);
    state = state.copyWith(results: results, isSearching: false);
  }
}
```

---

## Known YOLO labels for object query matching

Check `cleanQuery` against this list. If any word matches, add the object filter:
```dart
const yoloLabels = [
  'person','car','motorcycle','bicycle','bus','truck',
  'dog','cat','bird','horse',
  'bottle','cup','glass','bowl',
  'pizza','cake','sandwich','food',
  'laptop','phone','tv','computer',
  'chair','couch','sofa','bed','table',
  'book','clock','umbrella','backpack','bag',
  'snowboard','ski','surfboard','skateboard','ball',
];
```
