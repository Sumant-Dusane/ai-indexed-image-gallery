# CLAUDE.md — Gallery feature

Read before any work in lib/features/gallery/.
UI spec: @docs/ui-spec.md (GalleryScreen, PhotoDetailScreen sections)

---

## Files owned by this feature

```
lib/features/gallery/
  gallery_screen.dart          ← main grid grouped by month
  gallery_grid_cell.dart       ← single thumbnail cell, Hero tag
  photo_detail_screen.dart     ← full-screen view + info sheet
```

## Providers consumed

- `galleryProvider` → grouped photo list `Map<String, List<PhotoAsset>>`
- `indexingProvider` → IndexingState (for the indexing banner)

## Photo loading

- Thumbnails: `photo_manager` `entity.thumbnailDataWithSize(ThumbnailSize(200, 200))`
- Full-res: `photo_manager` `entity.file` — only load in PhotoDetailScreen, not in grid
- Hero tag format: `'photo_${photo.id}'` — use this exact string in both grid cell and detail screen

## Do not implement here

- Any DB reads → go through galleryProvider
- Any inference → this feature only displays, never computes
