# docs/ui-spec.md — UI specification (Phase 4, 5, 6)

Visual target: iOS Photos app aesthetic.
All screens use standard Flutter Material 3 with custom theme (no third-party UI kit).
No rounded corners on full-bleed images. Consistent 3-column grid throughout.

---

## App structure

```
BottomNavigationBar (3 tabs):
  Tab 0: Gallery (PhotosIcon)
  Tab 1: Search  (SearchIcon)  — or tap search bar from Gallery
  Tab 2: People  (PeopleIcon)
```

Route definitions (go_router):
```
/                     → GalleryScreen
/search               → SearchScreen
/people               → PeopleScreen
/people/:clusterId    → ClusterDetailScreen
/photo/:photoId       → PhotoDetailScreen
/permission-denied    → PermissionDeniedScreen
```

Router redirect (evaluated on every navigation and on `router.refresh()`):
- Read `photoPermissionProvider` (sync, `AsyncValue`)
- If still loading → no redirect
- If denied/restricted and not already on `/permission-denied` → redirect to `/permission-denied`
- If authorized/limited and on `/permission-denied` → redirect to `/`

---

## PermissionDeniedScreen

Component: `lib/features/permission/permission_denied_screen.dart`

Shown when photo library permission is `denied` or `restricted` (routed here by the go_router redirect — never pushed directly).

Layout — full screen, centered column:
- `Icons.lock_outline`, 64px, `colorScheme.outline`
- "No Access to Photos" — `titleMedium`
- "AI Gallery needs permission to show your photo library." — `bodyMedium`, `onSurfaceVariant`, centred
- `FilledButton` "Open Settings" → `PhotoManager.openSetting()`

Behaviour:
- Implements `WidgetsBindingObserver`; on `AppLifecycleState.resumed` calls `ref.invalidate(photoPermissionProvider)`
- This triggers the router redirect to re-evaluate — if permission was granted in Settings, the user is automatically navigated to `/`

---

## GalleryScreen

Component: `lib/features/gallery/gallery_screen.dart`

Layout:
- `CustomScrollView` with `SliverAppBar` (pinned, title "Library")
- Search bar row below app bar title — tapping navigates to /search
- `SliverList` of month sections, each containing a `SliverGrid`
- Grid: 3 columns, 2px gap between cells, square cells
- Section header: month + year in iOS Photos style ("September 2024"), 13px semibold, left-padded 16px
- Thumbnails: `photo_manager` `ThumbnailData`, `BoxFit.cover`
- Tap thumbnail: `Hero` animation → PhotoDetailScreen

Behaviour:
- Group photos by calendar month (taken_at)
- Load thumbnails lazily as user scrolls (use `photo_manager` caching)
- If indexing is in progress: show subtle banner at top "Analysing your library… X of Y"
  (tap banner → go to IndexingProgressScreen)

Do NOT show any AI-generated labels on the grid — clean grid only.

---

## SearchScreen

Component: `lib/features/search/search_screen.dart`

Layout:
- Full screen, white/system background
- Search bar at top, auto-focused, keyboard opens immediately
- Below search bar: results grid (3-col, same as gallery) or empty state
- Results stream as user types (debounce 400ms, min 2 chars)

States:
- **Empty / initial**: show suggestion chips
  ```
  "beach sunset"   "birthday"   "red shirt"
  "dog"            "snow"       "laughing"
  ```
- **Searching** (waiting for results): show subtle activity indicator in search bar
- **Results**: 3-col grid of matched photos, no labels visible on grid cells
- **No results**: centered text "No photos found for '[query]'"
  subtitle: "Try different words, or wait for indexing to finish"
- **Partial index**: if `indexingState.indexed < indexingState.total`, show below search bar:
  "Still analysing — showing results from X of Y photos"

Search bar clear button: always visible when query is non-empty.
Back button: clears search and returns to Gallery.

---

## PhotoDetailScreen

Component: `lib/features/gallery/photo_detail_screen.dart`

Layout:
- Full screen black background
- `InteractiveViewer` with pinch-to-zoom on the image
- `Hero` tag: `photo_${photo.id}`
- Top bar: back button (white), share button, favourite button (match iOS icons)
- Bottom info sheet (always visible, 80px collapsed):
  Swipe up to expand to full info

Bottom sheet content (expanded):
- Date: "15 September 2024, 3:42 PM"
- Location (if available from EXIF — use photo_manager metadata)
- Detected labels as chips: each detection label, sorted by confidence
  Chip style: light grey background, 12px text, no border
- Emotion chip (if face detected): e.g. "😊 Happy" — only show if confidence > 0.6
- Person chip (if face has cluster name): e.g. "👤 Rahul" — tap → ClusterDetailScreen
- If not yet indexed: show "Still analysing this photo…" in place of chips

---

## PeopleScreen

Component: `lib/features/people/people_screen.dart`

Layout:
- `SliverAppBar` title "People"
- Grid of cluster cards: 3 columns, square, 4px gap
- Each card: cover photo as background, name overlay at bottom (white text, subtle scrim)
- Unnamed clusters: show "Who is this?" overlay in amber
- Unnamed clusters appear first

Tap cluster card → ClusterDetailScreen

---

## ClusterDetailScreen

Component: `lib/features/people/cluster_detail_screen.dart`

Layout:
- `SliverAppBar` with cluster name as title (or "Unknown Person" if unnamed)
- Edit name button in app bar → shows `NameFaceSheet`
- "X Photos" subtitle below name
- 3-col photo grid (same as gallery), all photos for this cluster

---

## NameFaceSheet

Component: `lib/features/people/name_face_sheet.dart`

Layout:
- `showModalBottomSheet`
- Shows the cover face photo (circular, 80px diameter)
- Text field: "Enter name" placeholder
- "Save" button — calls `faceClusterService.nameCluster(id, name)`
- "Not a person / Remove" link — sets cluster name to null, hides from People screen

---

## OnboardingScreen + IndexingProgressScreen

Component: `lib/features/onboarding/`

Show only on first launch (persist flag in SharedPreferences: `onboarding_complete`).
Displayed while foreground indexing runs during setup.

Layout:
- Full screen, clean white
- App icon + "AI Gallery" title centred at top third
- Progress bar (linear, indeterminate until total count known, then determinate)
- Counter: "Analysing 1,240 of 8,432 photos"
- Three status rows (each gets a green checkmark when phase hits first completion):
  ```
  ○ / ✓   Scenes and places
  ○ / ✓   Objects and things  
  ○ / ✓   People
  ```
- Bottom: "Skip for now" text button
  → sets `onboarding_complete = true`, dismisses to GalleryScreen
  → indexing continues in background

Do not block the user from the app after "Skip". Onboarding screen never reappears.

---

## Theme

```dart
ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: Brightness.light,
  ),
  // Match iOS Photos: clean whites, system fonts, minimal chrome
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Colors.black,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: Colors.white,
    selectedItemColor: Colors.blue,
    unselectedItemColor: Colors.grey,
    type: BottomNavigationBarType.fixed,
  ),
)
// Support dark mode: use system brightness, swap to dark ColorScheme
```
