# CLAUDE.md — People feature

Read before any work in lib/features/people/.
Full clustering spec: @docs/clustering.md
UI spec: @docs/ui-spec.md (PeopleScreen, ClusterDetailScreen, NameFaceSheet sections)

---

## Files owned by this feature

```
lib/features/people/
  people_screen.dart           ← cluster grid, unnamed first
  cluster_detail_screen.dart   ← all photos for one cluster
  name_face_sheet.dart         ← bottom sheet to assign name to cluster
```

## Providers consumed

- `faceClusterProvider` → `FaceClusterState` (clusters list, isClustering)

## Do not implement here

- DBSCAN logic → lives in `lib/services/face_cluster_service.dart`
- DB queries → go through `lib/core/db/database.dart`
- Embedding logic → lives in Rust layer
