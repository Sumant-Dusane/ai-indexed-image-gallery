# docs/clustering.md — Face clustering (Phase 5)

Owned by: `lib/services/face_cluster_service.dart`
State exposed via: `lib/core/providers/face_cluster_provider.dart`

---

## FaceClusterService public API

```dart
class FaceClusterService {
  // Run full DBSCAN on all face embeddings. Call after initial index completes.
  Future<void> runFullClustering();

  // Incremental — run when >= 50 new faces have been added since last run.
  Future<void> runIncrementalClustering();

  // User assigns a name to a cluster.
  Future<void> nameCluster(int clusterId, String name);

  // Assign a new face to the nearest existing cluster (or create new).
  Future<void> assignNewFace(int faceId, List<double> embedding);
}
```

---

## DBSCAN implementation (pure Dart, no ML)

```
Parameters (fixed):
  epsilon  = 0.4   (cosine distance threshold — faces within this are "neighbours")
  minPts   = 3     (minimum faces to form a cluster)

Algorithm:
  1. Load all face embeddings from face_vss table
     → List<(faceId: int, embedding: List<double>)>

  2. Build distance function:
     cosineDist(a, b) = 1 - dotProduct(a, b)
     (embeddings are L2-normalised, so dot product = cosine similarity)

  3. Run DBSCAN:
     - For each unvisited point, find all neighbours within epsilon
     - If neighbours >= minPts: form cluster, expand recursively
     - Else: mark as noise (cluster_id stays NULL)

  4. For each formed cluster:
     a. INSERT INTO clusters (member_count) VALUES (count)
        or UPDATE clusters SET member_count = count WHERE id = existing_id
     b. Compute centroid = mean of all embeddings in cluster
     c. Find face_id whose embedding has minimum cosine distance to centroid
        → set as cover_face_id
     d. UPDATE faces SET cluster_id = ? WHERE id IN (cluster member face ids)

  5. Run inside compute() — never on main isolate
```

---

## Incremental assignment (for new faces after initial clustering)

```
For a new face embedding:
  1. Load all cluster centroids from DB
     (compute centroid on the fly: mean of face embeddings per cluster_id)
  2. Find nearest centroid by cosine distance
  3. If distance <= epsilon:
       assign face to that cluster
       UPDATE faces SET cluster_id = ? WHERE id = ?
       UPDATE clusters SET member_count = member_count + 1 WHERE id = ?
  4. Else:
       leave cluster_id NULL (noise — will be picked up in next full clustering)

Trigger full re-clustering when noise face count exceeds 50.
```

---

## FaceClusterProvider state

```dart
class FaceClusterState {
  final List<FaceCluster> clusters;   // sorted: unnamed first, then by memberCount desc
  final bool isClustering;
}

// clusters with name == null come first (prompt user to name them)
// clusters with name != null sorted by memberCount descending
```

---

## People screen data queries

**All clusters with cover photo:**
```sql
SELECT c.id, c.name, c.member_count, c.cover_face_id,
       f.photo_id as cover_photo_id,
       p.local_path as cover_path
FROM clusters c
JOIN faces f ON c.cover_face_id = f.id
JOIN photos p ON f.photo_id = p.id
ORDER BY
  CASE WHEN c.name IS NULL THEN 0 ELSE 1 END,
  c.member_count DESC
```

**Photos for a specific cluster:**
```sql
SELECT DISTINCT p.id, p.local_path, p.taken_at
FROM faces f
JOIN photos p ON f.photo_id = p.id
WHERE f.cluster_id = ?
ORDER BY p.taken_at DESC
```
