# docs/search.md — Search / query pipeline (Phase 4)

Owned by: `lib/services/query_service.dart`
State exposed via: `lib/core/providers/search_provider.dart`
Vocabulary owned by: `lib/core/constants/search_vocabulary.dart`
Canonical retained YOLO labels owned by: `lib/core/constants/yolo_detection_labels.dart`

---

## QueryService public API

```dart
class QueryService {
  // Main entry point. Returns one ranked page. Pass offset + limit to continue
  // the same query for a future "Load more" action.
  Future<List<SearchResult>> search(
    String query, {
    int offset = 0,
    int limit = 50,
  });
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

**Emotion mapping — check query for these words, map to DB emotion. Keep the
expandable map in `SearchVocabulary.emotionAliases`:**
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
// If cleanQuery is empty after Step 1 stripping, embed the normalized original
// query so vector search still runs for metadata-only text such as "last month".
```

---

### Step 3 — Vector search

```sql
SELECT p.id, p.local_path, p.taken_at, v.distance AS score
FROM vector_full_scan('photo_embeddings', 'embedding', ?, :candidateLimit) AS v
JOIN photo_embeddings pe ON v.rowid = pe.rowid
JOIN photos p ON pe.photo_id = p.id
ORDER BY v.distance ASC
LIMIT :candidateLimit
```

Bind: embedding vector as raw little-endian float32 blob. Set
`:candidateLimit = offset + limit` so later pages expand the ranked candidate
window.

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

-- Person object filter (if cleanQuery contains "person"):
-- YOLO person detections are represented by faces, not stored in detections.
AND EXISTS (
  SELECT 1 FROM faces f
  WHERE f.photo_id = p.id
)
```

Build the WHERE clause dynamically in Dart. Combine Steps 3+4 into one vector
query. Also run a metadata-only query on every search. When no structured
metadata hint was parsed, the metadata-only query returns no candidates.

Merge vector and metadata-only candidates by photo ID before re-ranking. If a
photo appears in both sets, retain its vector distance.

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
// Sort descending by finalScore, then photoId ascending as a stable tie-breaker.
```

---

### Step 6 — Return

Return one sorted page of `List<SearchResult>`. Default page size: 50 items.
Support continuation with `offset` and `limit` so a future "Load more" button
can request the next page without changing the initial result cap.

## Future ranking stability

The same query should return a stable result order across repeated searches and
pagination. The current implementation uses `photoId` as a deterministic
tie-breaker. A future iteration should add a query-session snapshot or cached
ranked candidate list so newly indexed photos and time-based recency changes do
not drastically reorder an active search session.

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
    @Default(false) bool hasMore,
  }) = _SearchState;
}

// Search runs only after explicit submission from the search button or keyboard
// search action. Typing updates state.query but never starts inference or SQL.
// Minimum submitted query length: 2 characters
// While indexing is still running: set indexingPartial = true
//   (don't block search — return partial results from what's indexed so far)

@riverpod
class SearchNotifier extends _$SearchNotifier {
  @override
  SearchState build() => const SearchState();

  void updateQuery(String query) {
    state = state.copyWith(query: query);
  }

  Future<void> search() async {
    state = state.copyWith(isSearching: true);
    final page = await ref.read(queryServiceProvider.future).search(
      state.query,
      limit: 51, // One extra row determines whether continuation is available.
    );
    state = state.copyWith(
      results: page.take(50).toList(),
      isSearching: false,
      hasMore: page.length > 50,
    );
  }

  Future<void> loadMore() async {
    final page = await ref.read(queryServiceProvider.future).search(
      state.query,
      offset: state.results.length,
      limit: 51,
    );
    state = state.copyWith(
      results: [...state.results, ...page.take(50)],
      hasMore: page.length > 50,
    );
  }
}
```

---

## Known YOLO labels for object query matching

Use the derived indexed-label set in `YoloDetectionLabels.indexedLabels`.
Search must not duplicate this list. If any word matches, add the object filter.

Keep user-facing synonyms in `SearchVocabulary.objectAliases`. Map aliases to
their stored YOLO labels before applying the object filter:
```dart
const objectAliases = {
  'automobile': 'car',
  'mobile':     'phone',
  'puppy':      'dog',
  'kitten':     'cat',
  'sofa':       'couch',
  'glass':      'wine glass',
  'table':      'dining table',
  'bag':        'handbag',
  'ski':        'skis',
  'ball':       'sports ball',
};
```
