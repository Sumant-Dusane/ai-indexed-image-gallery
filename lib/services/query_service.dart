import 'dart:typed_data';

import 'package:ai_gallery/core/constants/search_vocabulary.dart';
import 'package:ai_gallery/core/models/search_result.dart';
import 'package:ai_gallery/core/repositories/inference_repository.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:sqlite3/sqlite3.dart';

part 'query_service.freezed.dart';

@freezed
class QueryIntent with _$QueryIntent {
  const factory QueryIntent({
    DateTimeRange? dateRange,
    int? clusterId,
    String? emotion,
    required String cleanQuery,
  }) = _QueryIntent;
}

class QueryService {
  final Database _db;
  final InferenceRepository _inferenceRepository;

  QueryService({
    required Database db,
    required InferenceRepository inferenceRepository,
  }) : _db = db,
       _inferenceRepository = inferenceRepository;

  /// Runs the six-step search pipeline and returns one ranked result page.
  Future<List<SearchResult>> search(
    String query, {
    int offset = 0,
    int limit = 50,
  }) async {
    if (offset < 0) throw ArgumentError.value(offset, 'offset');
    if (limit <= 0) throw ArgumentError.value(limit, 'limit');
    final normalizedQuery = _normalizeWhitespace(query);
    if (normalizedQuery.isEmpty) return const [];

    final intent = _parseIntent(query);
    final embeddingQuery = intent.cleanQuery.isEmpty
        ? normalizedQuery
        : intent.cleanQuery;
    final embedding = await _inferenceRepository.embedText(embeddingQuery);
    final candidateLimit = offset + limit;
    final vectorRows = _vectorSearch(intent, embedding, candidateLimit);
    final metadataRows = _metadataSearch(intent, candidateLimit);
    final rowsByPhotoId = <String, Row>{
      for (final row in vectorRows) row['id'] as String: row,
    };
    for (final row in metadataRows) {
      rowsByPhotoId.putIfAbsent(row['id'] as String, () => row);
    }

    final now = DateTime.now();
    final results = rowsByPhotoId.values
        .map((row) => _toSearchResult(row, now))
        .toList();
    results.sort((a, b) {
      final scoreComparison = b.score.compareTo(a.score);
      return scoreComparison != 0
          ? scoreComparison
          : a.photoId.compareTo(b.photoId);
    });
    return results.skip(offset).take(limit).toList(growable: false);
  }

  QueryIntent _parseIntent(String query) {
    var cleanQuery = query.toLowerCase();
    final dateMatch = _extractDateRange(cleanQuery, DateTime.now());
    if (dateMatch != null) {
      cleanQuery = _removeMatch(cleanQuery, dateMatch.pattern);
    }

    String? emotion;
    for (final entry in SearchVocabulary.emotionAliases.entries) {
      final pattern = RegExp('\\b${RegExp.escape(entry.key)}\\b');
      if (pattern.hasMatch(cleanQuery)) {
        emotion = entry.value;
        cleanQuery = _removeMatch(cleanQuery, pattern);
        break;
      }
    }

    int? clusterId;
    final clusters = _db.select(
      'SELECT id, name FROM clusters WHERE name IS NOT NULL',
    );
    for (final row in clusters) {
      final name = (row['name'] as String).toLowerCase();
      final pattern = RegExp('\\b${RegExp.escape(name)}\\b');
      if (pattern.hasMatch(cleanQuery)) {
        clusterId = row['id'] as int;
        cleanQuery = _removeMatch(cleanQuery, pattern);
        break;
      }
    }

    return QueryIntent(
      dateRange: dateMatch?.range,
      clusterId: clusterId,
      emotion: emotion,
      cleanQuery: _normalizeWhitespace(cleanQuery),
    );
  }

  ResultSet _vectorSearch(
    QueryIntent intent,
    List<double> embedding,
    int candidateLimit,
  ) {
    final filters = _filtersFor(intent);
    return _db.select(
      '''
      SELECT p.id, p.local_path, p.taken_at, v.distance AS score
      FROM vector_full_scan('photo_embeddings', 'embedding', ?, ?) AS v
      JOIN photo_embeddings pe ON v.rowid = pe.rowid
      JOIN photos p ON pe.photo_id = p.id
      ${filters.whereClause}
      ORDER BY v.distance ASC
      LIMIT ?
    ''',
      [
        _toFloat32Blob(embedding),
        candidateLimit,
        ...filters.parameters,
        candidateLimit,
      ],
    );
  }

  ResultSet _metadataSearch(QueryIntent intent, int candidateLimit) {
    final filters = _filtersFor(intent);
    return _db.select(
      '''
      SELECT p.id, p.local_path, p.taken_at, 1.0 AS score
      FROM photos p
      ${filters.whereClause}
      ${filters.hasMetadataFilter ? '' : 'AND 0'}
      ORDER BY p.taken_at DESC
      LIMIT ?
    ''',
      [...filters.parameters, candidateLimit],
    );
  }

  ({String whereClause, List<Object> parameters, bool hasMetadataFilter})
  _filtersFor(QueryIntent intent) {
    final clauses = <String>['p.local_path IS NOT NULL'];
    final parameters = <Object>[];
    var hasMetadataFilter = false;
    final dateRange = intent.dateRange;
    if (dateRange != null) {
      hasMetadataFilter = true;
      clauses.add('p.taken_at BETWEEN ? AND ?');
      parameters
        ..add(dateRange.start.millisecondsSinceEpoch ~/ 1000)
        ..add(dateRange.end.millisecondsSinceEpoch ~/ 1000);
    }
    if (intent.clusterId != null) {
      hasMetadataFilter = true;
      clauses.add('''
        EXISTS (
          SELECT 1 FROM faces f
          WHERE f.photo_id = p.id AND f.cluster_id = ?
        )
      ''');
      parameters.add(intent.clusterId!);
    }
    if (intent.emotion != null) {
      hasMetadataFilter = true;
      clauses.add('''
        EXISTS (
          SELECT 1 FROM faces f
          WHERE f.photo_id = p.id AND f.emotion = ?
        )
      ''');
      parameters.add(intent.emotion!);
    }
    if (_containsWord(intent.cleanQuery, 'person')) {
      hasMetadataFilter = true;
      clauses.add('''
        EXISTS (
          SELECT 1 FROM faces f
          WHERE f.photo_id = p.id
        )
      ''');
    }
    final label = _objectLabel(intent.cleanQuery);
    if (label != null) {
      hasMetadataFilter = true;
      clauses.add('''
        EXISTS (
          SELECT 1 FROM detections d
          WHERE d.photo_id = p.id AND d.label LIKE ?
        )
      ''');
      parameters.add(label);
    }
    return (
      whereClause: 'WHERE ${clauses.join(' AND ')}',
      parameters: parameters,
      hasMetadataFilter: hasMetadataFilter,
    );
  }

  SearchResult _toSearchResult(Row row, DateTime now) {
    final takenAtSeconds = row['taken_at'] as int?;
    final takenAt = takenAtSeconds == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(takenAtSeconds * 1000);
    final daysSince = takenAt == null
        ? 365.0
        : now.difference(takenAt).inDays.toDouble();
    final recencyScore = 1.0 / (1.0 + daysSince / 365.0);
    final semanticScore = 1.0 - (row['score'] as num).toDouble();
    final score = 0.7 * semanticScore + 0.3 * recencyScore;
    return SearchResult(
      photoId: row['id'] as String,
      localPath: row['local_path'] as String,
      takenAt: takenAt,
      score: score,
    );
  }
}

({DateTimeRange range, RegExp pattern})? _extractDateRange(
  String query,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final patterns = <({RegExp pattern, DateTimeRange range})>[
    (pattern: RegExp(r'\blast year\b'), range: _fullYear(now.year - 1)),
    (
      pattern: RegExp(r'\bthis year\b'),
      range: DateTimeRange(start: DateTime(now.year), end: now),
    ),
    (
      pattern: RegExp(r'\blast month\b'),
      range: _fullMonth(DateTime(now.year, now.month - 1)),
    ),
    (
      pattern: RegExp(r'\bthis month\b'),
      range: DateTimeRange(start: DateTime(now.year, now.month), end: now),
    ),
    (
      pattern: RegExp(r'\byesterday\b'),
      range: _fullDay(today.subtract(const Duration(days: 1))),
    ),
    (pattern: RegExp(r'\blast week\b'), range: _lastWeek(today)),
    (
      pattern: RegExp(r'\b(?:recent|lately)\b'),
      range: DateTimeRange(
        start: now.subtract(const Duration(days: 30)),
        end: now,
      ),
    ),
  ];
  for (final candidate in patterns) {
    if (candidate.pattern.hasMatch(query)) return candidate;
  }

  final yearPattern = RegExp(r'\bin (\d{4})\b');
  final yearMatch = yearPattern.firstMatch(query);
  if (yearMatch != null) {
    return (
      pattern: yearPattern,
      range: _fullYear(int.parse(yearMatch.group(1)!)),
    );
  }

  for (var month = 1; month <= _monthNames.length; month++) {
    final pattern = RegExp('\\bin ${_monthNames[month - 1]}\\b');
    if (pattern.hasMatch(query)) {
      return (pattern: pattern, range: _fullMonth(DateTime(now.year, month)));
    }
  }
  return null;
}

DateTimeRange _fullYear(int year) => DateTimeRange(
  start: DateTime(year),
  end: _inclusiveEnd(DateTime(year + 1)),
);

DateTimeRange _fullMonth(DateTime month) => DateTimeRange(
  start: DateTime(month.year, month.month),
  end: _inclusiveEnd(DateTime(month.year, month.month + 1)),
);

DateTimeRange _fullDay(DateTime day) => DateTimeRange(
  start: day,
  end: _inclusiveEnd(day.add(const Duration(days: 1))),
);

DateTimeRange _lastWeek(DateTime today) {
  final startOfThisWeek = today.subtract(Duration(days: today.weekday - 1));
  return DateTimeRange(
    start: startOfThisWeek.subtract(const Duration(days: 7)),
    end: _inclusiveEnd(startOfThisWeek),
  );
}

DateTime _inclusiveEnd(DateTime exclusiveEnd) =>
    exclusiveEnd.subtract(const Duration(milliseconds: 1));

String? _objectLabel(String query) {
  final words = RegExp(r"[a-z]+").allMatches(query).map((m) => m.group(0)!);
  for (final word in words) {
    final alias = SearchVocabulary.objectAliases[word];
    if (alias != null) return alias;
    if (SearchVocabulary.isStoredYoloLabel(word)) return word;
  }
  return null;
}

bool _containsWord(String query, String word) =>
    RegExp('\\b${RegExp.escape(word)}\\b').hasMatch(query);

Uint8List _toFloat32Blob(List<double> values) {
  final data = ByteData(values.length * 4);
  for (var i = 0; i < values.length; i++) {
    data.setFloat32(i * 4, values[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

String _removeMatch(String value, RegExp pattern) =>
    value.replaceFirst(pattern, ' ');

String _normalizeWhitespace(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

const _monthNames = <String>[
  'january',
  'february',
  'march',
  'april',
  'may',
  'june',
  'july',
  'august',
  'september',
  'october',
  'november',
  'december',
];
