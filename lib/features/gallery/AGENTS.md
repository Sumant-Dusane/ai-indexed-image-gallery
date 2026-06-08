# AGENTS.md — Gallery feature

Before working here, read: `docs/ui-spec.md` (GalleryScreen, PhotoDetailScreen sections).

---

## Files owned by this feature

```
lib/features/gallery/
  gallery_screen.dart          ← main grid grouped by month
  gallery_grid_cell.dart       ← single thumbnail cell
  photo_detail_screen.dart     ← full-screen view + info sheet
```

## Providers consumed

- `galleryProvider` → `Map<String, List<AssetEntity>>` — reads directly from `photo_manager`, no DB required.
  Grid is populated immediately on launch before any AI indexing runs.
- `indexingProvider` → IndexingState (for the indexing banner)

## Photo loading

- Thumbnails: `photo_manager` `entity.thumbnailDataWithSize(ThumbnailSize(200, 200))`
- Detail preview: render the grid thumbnail immediately, then request a display-sized thumbnail after the first frame; keep both in a stable frame derived from the asset aspect ratio
- Full-res: `photo_manager` `entity.file` — only load after zoom starts in PhotoDetailScreen, not in grid
- Hero tag format: `'photo_${photo.id}'` — use this exact string in both grid cell and detail screen

## Do not implement here

- Any DB reads → go through galleryProvider
- Any inference → this feature only displays, never computes
