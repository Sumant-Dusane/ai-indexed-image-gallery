# CLAUDE.md — Search feature

Before working here, read: `docs/search.md` (query pipeline) and `docs/ui-spec.md` (SearchScreen section).

---

## Files owned by this feature

```
lib/features/search/
  search_screen.dart         ← full-screen search UI
  search_bar.dart            ← reusable search input widget (also used in GalleryScreen)
  search_results_grid.dart   ← 3-col results grid, reuses gallery grid cell
  search_empty_state.dart    ← suggestion chips + no-results state
```

## Providers consumed (do not modify these)

- `searchProvider` → `SearchState` (query, results, isSearching, indexingPartial)
- `indexingProvider` → `IndexingState` (for the "still analysing" banner)

## Do not implement here

- Query parsing logic → lives in `lib/services/query_service.dart`
- Vector search → lives in `lib/services/query_service.dart`
- Rust calls → go through `lib/core/repositories/inference_repository.dart`
