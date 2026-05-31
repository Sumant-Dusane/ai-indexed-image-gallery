import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';

class FaceClusterService {
  FaceClusterService({required Database db}) : _db = db;

  static const _epsilon = 0.4;

  final Database _db;

  Future<void> runFullClustering() async {
    final rows = _db.select('''
      SELECT fe.face_id, fe.embedding, f.cluster_id
      FROM face_embeddings fe
      JOIN faces f ON fe.face_id = f.id
    ''');
    final clusters = await compute(_runDbscan, [
      for (final row in rows)
        {
          'faceId': row['face_id'] as int,
          'embedding': row['embedding'] as Uint8List,
        },
    ]);
    final previousClusterByFace = <int, int?>{
      for (final row in rows) row['face_id'] as int: row['cluster_id'] as int?,
    };

    _db.execute('BEGIN IMMEDIATE');
    try {
      final oldClusterIds = _db
          .select('SELECT id FROM clusters')
          .map((row) => row['id'] as int)
          .toSet();
      final retainedClusterIds = <int>{};
      _db.execute('UPDATE faces SET cluster_id = NULL');

      for (final cluster in clusters) {
        final faceIds = (cluster['faceIds'] as List<Object?>).cast<int>();
        final existingId = _bestExistingCluster(
          faceIds,
          previousClusterByFace,
          retainedClusterIds,
        );
        final clusterId = existingId ?? _insertCluster(cluster);
        if (existingId != null) {
          _db.execute(
            'UPDATE clusters SET member_count = ?, cover_face_id = ? WHERE id = ?',
            [faceIds.length, cluster['coverFaceId'] as int, existingId],
          );
        }
        retainedClusterIds.add(clusterId);
        _assignFaces(clusterId, faceIds);
      }

      for (final clusterId in oldClusterIds.difference(retainedClusterIds)) {
        _db.execute('DELETE FROM clusters WHERE id = ?', [clusterId]);
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<void> runIncrementalClustering() async {
    final centroidRows = _clusteredEmbeddingRows();
    final unassignedRows = _db.select('''
      SELECT fe.face_id, fe.embedding
      FROM face_embeddings fe
      JOIN faces f ON fe.face_id = f.id
      WHERE f.cluster_id IS NULL
    ''');
    final assignments = await compute(_assignToNearestCentroids, {
      'clustered': centroidRows,
      'unassigned': [
        for (final row in unassignedRows)
          {
            'faceId': row['face_id'] as int,
            'embedding': row['embedding'] as Uint8List,
          },
      ],
    });

    _db.execute('BEGIN IMMEDIATE');
    try {
      for (final assignment in assignments) {
        final faceId = assignment['faceId'] as int;
        final clusterId = assignment['clusterId'] as int?;
        if (clusterId == null) continue;
        _db.execute('UPDATE faces SET cluster_id = ? WHERE id = ?', [
          clusterId,
          faceId,
        ]);
        _db.execute(
          'UPDATE clusters SET member_count = member_count + 1 WHERE id = ?',
          [clusterId],
        );
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }

    await _reclusterIfNoiseThresholdExceeded();
  }

  Future<void> nameCluster(int clusterId, String name) async {
    final trimmedName = name.trim();
    _db.execute('UPDATE clusters SET name = ? WHERE id = ?', [
      trimmedName.isEmpty ? null : trimmedName,
      clusterId,
    ]);
  }

  Future<void> assignNewFace(int faceId, List<double> embedding) async {
    final clusterId = await compute(_nearestCluster, {
      'clustered': _clusteredEmbeddingRows(),
      'embedding': embedding,
    });
    if (clusterId != null) {
      _db.execute('BEGIN IMMEDIATE');
      try {
        _db.execute(
          'UPDATE faces SET cluster_id = ? WHERE id = ? AND cluster_id IS NULL',
          [clusterId, faceId],
        );
        if (_db.updatedRows > 0) {
          _db.execute(
            'UPDATE clusters SET member_count = member_count + 1 WHERE id = ?',
            [clusterId],
          );
        }
        _db.execute('COMMIT');
      } catch (_) {
        _db.execute('ROLLBACK');
        rethrow;
      }
    }
    await _reclusterIfNoiseThresholdExceeded();
  }

  List<Map<String, Object>> _clusteredEmbeddingRows() {
    final rows = _db.select('''
      SELECT f.cluster_id, fe.embedding
      FROM face_embeddings fe
      JOIN faces f ON fe.face_id = f.id
      WHERE f.cluster_id IS NOT NULL
    ''');
    return [
      for (final row in rows)
        {
          'clusterId': row['cluster_id'] as int,
          'embedding': row['embedding'] as Uint8List,
        },
    ];
  }

  Future<void> _reclusterIfNoiseThresholdExceeded() async {
    final row = _db
        .select('SELECT COUNT(*) AS count FROM faces WHERE cluster_id IS NULL')
        .first;
    if ((row['count'] as int) > 50) {
      await runFullClustering();
    }
  }

  int _insertCluster(Map<String, Object> cluster) {
    _db.execute(
      'INSERT INTO clusters(member_count, cover_face_id) VALUES(?, ?)',
      [
        (cluster['faceIds'] as List<Object?>).length,
        cluster['coverFaceId'] as int,
      ],
    );
    return _db.lastInsertRowId;
  }

  void _assignFaces(int clusterId, List<int> faceIds) {
    final statement = _db.prepare(
      'UPDATE faces SET cluster_id = ? WHERE id = ?',
    );
    try {
      for (final faceId in faceIds) {
        statement.execute([clusterId, faceId]);
      }
    } finally {
      statement.close();
    }
  }
}

int? _bestExistingCluster(
  List<int> faceIds,
  Map<int, int?> previousClusterByFace,
  Set<int> retainedClusterIds,
) {
  final counts = <int, int>{};
  for (final faceId in faceIds) {
    final clusterId = previousClusterByFace[faceId];
    if (clusterId != null && !retainedClusterIds.contains(clusterId)) {
      counts.update(clusterId, (count) => count + 1, ifAbsent: () => 1);
    }
  }
  if (counts.isEmpty) return null;
  final candidates = counts.keys.toList()..sort();
  return candidates.reduce(
    (best, candidate) => counts[candidate]! > counts[best]! ? candidate : best,
  );
}

List<Map<String, Object>> _runDbscan(List<Map<String, Object>> rows) {
  const minPts = 3;
  final points = [
    for (final row in rows)
      (
        faceId: row['faceId'] as int,
        embedding: _embeddingFromBlob(row['embedding'] as Uint8List),
      ),
  ];
  final labels = List<int>.filled(points.length, -1);
  final visited = List<bool>.filled(points.length, false);
  var nextCluster = 0;

  List<int> neighboursOf(int index) {
    final neighbours = <int>[];
    for (var candidate = 0; candidate < points.length; candidate++) {
      if (_cosineDistance(
            points[index].embedding,
            points[candidate].embedding,
          ) <=
          FaceClusterService._epsilon) {
        neighbours.add(candidate);
      }
    }
    return neighbours;
  }

  for (var point = 0; point < points.length; point++) {
    if (visited[point]) continue;
    visited[point] = true;
    final neighbours = neighboursOf(point);
    if (neighbours.length < minPts) {
      labels[point] = -2;
      continue;
    }

    labels[point] = nextCluster;
    final queue = [...neighbours];
    final queued = neighbours.toSet();
    for (var queueIndex = 0; queueIndex < queue.length; queueIndex++) {
      final neighbour = queue[queueIndex];
      if (!visited[neighbour]) {
        visited[neighbour] = true;
        final expanded = neighboursOf(neighbour);
        if (expanded.length >= minPts) {
          for (final candidate in expanded) {
            if (queued.add(candidate)) queue.add(candidate);
          }
        }
      }
      if (labels[neighbour] < 0) labels[neighbour] = nextCluster;
    }
    nextCluster++;
  }

  return [
    for (var clusterId = 0; clusterId < nextCluster; clusterId++)
      _clusterResult([
        for (var index = 0; index < points.length; index++)
          if (labels[index] == clusterId) points[index],
      ]),
  ];
}

Map<String, Object> _clusterResult(
  List<({int faceId, List<double> embedding})> members,
) {
  final centroid = _normalizedCentroid([
    for (final member in members) member.embedding,
  ]);
  var cover = members.first;
  var coverDistance = _cosineDistance(cover.embedding, centroid);
  for (final member in members.skip(1)) {
    final distance = _cosineDistance(member.embedding, centroid);
    if (distance < coverDistance) {
      cover = member;
      coverDistance = distance;
    }
  }
  return {
    'faceIds': [for (final member in members) member.faceId],
    'coverFaceId': cover.faceId,
  };
}

List<Map<String, Object?>> _assignToNearestCentroids(
  Map<String, Object> input,
) {
  final centroids = _centroids(
    (input['clustered'] as List<Object?>).cast<Map<String, Object>>(),
  );
  return [
    for (final row
        in (input['unassigned'] as List<Object?>).cast<Map<String, Object>>())
      {
        'faceId': row['faceId'] as int,
        'clusterId': _nearestCentroid(
          _embeddingFromBlob(row['embedding'] as Uint8List),
          centroids,
        ),
      },
  ];
}

int? _nearestCluster(Map<String, Object> input) {
  final centroids = _centroids(
    (input['clustered'] as List<Object?>).cast<Map<String, Object>>(),
  );
  return _nearestCentroid(
    (input['embedding'] as List<Object?>).cast<double>(),
    centroids,
  );
}

Map<int, List<double>> _centroids(List<Map<String, Object>> rows) {
  final embeddingsByCluster = <int, List<List<double>>>{};
  for (final row in rows) {
    embeddingsByCluster
        .putIfAbsent(row['clusterId'] as int, () => [])
        .add(_embeddingFromBlob(row['embedding'] as Uint8List));
  }
  return {
    for (final entry in embeddingsByCluster.entries)
      entry.key: _normalizedCentroid(entry.value),
  };
}

int? _nearestCentroid(
  List<double> embedding,
  Map<int, List<double>> centroids,
) {
  int? nearestId;
  var nearestDistance = double.infinity;
  for (final entry in centroids.entries) {
    final distance = _cosineDistance(embedding, entry.value);
    if (distance < nearestDistance) {
      nearestId = entry.key;
      nearestDistance = distance;
    }
  }
  return nearestDistance <= FaceClusterService._epsilon ? nearestId : null;
}

List<double> _normalizedCentroid(List<List<double>> embeddings) {
  final centroid = List<double>.filled(embeddings.first.length, 0);
  for (final embedding in embeddings) {
    for (var index = 0; index < embedding.length; index++) {
      centroid[index] += embedding[index];
    }
  }
  return _normalize(centroid);
}

List<double> _normalize(List<double> values) {
  var squaredMagnitude = 0.0;
  for (final value in values) {
    squaredMagnitude += value * value;
  }
  if (squaredMagnitude == 0) return values;
  final magnitude = math.sqrt(squaredMagnitude);
  return [for (final value in values) value / magnitude];
}

double _cosineDistance(List<double> a, List<double> b) {
  var dotProduct = 0.0;
  for (var index = 0; index < a.length; index++) {
    dotProduct += a[index] * b[index];
  }
  return 1 - dotProduct;
}

List<double> _embeddingFromBlob(Uint8List blob) {
  final data = ByteData.sublistView(blob);
  return [
    for (var offset = 0; offset < blob.length; offset += 4)
      data.getFloat32(offset, Endian.little),
  ];
}
