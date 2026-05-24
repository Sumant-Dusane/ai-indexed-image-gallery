# AGENTS.md — People feature

Before working here, read: `docs/clustering.md` (DBSCAN spec) and `docs/ui-spec.md` (PeopleScreen, ClusterDetailScreen, NameFaceSheet sections).

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
- DB queries → go through providers and repositories
- Embedding logic → lives in `lib/core/repositories/inference_repository.dart`
