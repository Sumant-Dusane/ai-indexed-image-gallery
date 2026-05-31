import 'package:ai_gallery/core/debug/app_logger.dart';
import 'package:ai_gallery/core/models/search_result.dart';
import 'package:ai_gallery/core/providers/database_provider.dart';
import 'package:ai_gallery/core/providers/indexing_notifier_provider.dart';
import 'package:ai_gallery/core/providers/inference_repository_provider.dart';
import 'package:ai_gallery/services/query_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_provider.freezed.dart';
part 'search_provider.g.dart';

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

@Riverpod(keepAlive: true)
Future<QueryService> queryService(Ref ref) async {
  final db = await ref.read(databaseProvider.future);
  final inference = await ref.read(inferenceRepositoryProvider.future);
  return QueryService(db: db, inferenceRepository: inference);
}

@riverpod
class SearchNotifier extends _$SearchNotifier {
  static const _pageSize = 50;

  int _generation = 0;

  @override
  SearchState build() => const SearchState();

  void updateQuery(String query) {
    _generation++;
    final indexing = ref.read(indexingNotifierProvider);
    state = state.copyWith(
      query: query,
      isSearching: false,
      indexingPartial: indexing.indexed < indexing.total,
      hasMore: false,
    );
  }

  void clear() {
    _generation++;
    state = const SearchState();
  }

  Future<void> search() async {
    final query = state.query.trim();
    final generation = ++_generation;
    final indexing = ref.read(indexingNotifierProvider);
    final indexingPartial = indexing.indexed < indexing.total;
    if (query.length < 2) {
      state = state.copyWith(
        results: const [],
        isSearching: false,
        indexingPartial: indexingPartial,
        hasMore: false,
      );
      return;
    }

    state = state.copyWith(
      query: query,
      results: const [],
      isSearching: true,
      indexingPartial: indexingPartial,
      hasMore: false,
    );
    await _runSearch(query, generation);
  }

  Future<void> _runSearch(String query, int generation) async {
    try {
      final service = await ref.read(queryServiceProvider.future);
      final page = await service.search(query, limit: _pageSize + 1);
      if (generation != _generation) return;
      final indexing = ref.read(indexingNotifierProvider);
      state = state.copyWith(
        results: page.take(_pageSize).toList(growable: false),
        isSearching: false,
        indexingPartial: indexing.indexed < indexing.total,
        hasMore: page.length > _pageSize,
      );
    } catch (error, stackTrace) {
      AppLogger.search(
        'search failed for "$query"',
        error: error,
        stackTrace: stackTrace,
      );
      if (generation == _generation) {
        state = state.copyWith(isSearching: false);
      }
    }
  }

  Future<void> loadMore() async {
    if (state.isSearching || !state.hasMore) return;
    final query = state.query;
    final generation = _generation;
    state = state.copyWith(isSearching: true);
    try {
      final service = await ref.read(queryServiceProvider.future);
      final page = await service.search(
        query,
        offset: state.results.length,
        limit: _pageSize + 1,
      );
      if (generation != _generation) return;
      final existingIds = state.results.map((result) => result.photoId).toSet();
      final newResults = page
          .where((result) => !existingIds.contains(result.photoId))
          .take(_pageSize);
      state = state.copyWith(
        results: [...state.results, ...newResults],
        isSearching: false,
        hasMore: page.length > _pageSize,
      );
    } catch (error, stackTrace) {
      AppLogger.search(
        'load more failed for "$query"',
        error: error,
        stackTrace: stackTrace,
      );
      if (generation == _generation) {
        state = state.copyWith(isSearching: false);
      }
    }
  }
}
