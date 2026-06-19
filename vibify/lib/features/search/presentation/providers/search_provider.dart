import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../domain/entities/search_result.dart';
import '../../domain/usecases/search_tracks_usecase.dart';

const _kUndefined = Object();

class SearchState {
  final String query;
  final bool isLoading;
  final SearchResult? result;
  final String? error;
  final List<String> recentSearches;

  const SearchState({
    this.query = '',
    this.isLoading = false,
    this.result,
    this.error,
    this.recentSearches = const [],
  });

  SearchState copyWith({
    String? query,
    bool? isLoading,
    Object? result = _kUndefined,
    Object? error = _kUndefined,
    List<String>? recentSearches,
  }) =>
      SearchState(
        query: query ?? this.query,
        isLoading: isLoading ?? this.isLoading,
        result: result == _kUndefined ? this.result : result as SearchResult?,
        error: error == _kUndefined ? this.error : error as String?,
        recentSearches: recentSearches ?? this.recentSearches,
      );

  SearchState clearResult() => SearchState(
        query: query,
        isLoading: isLoading,
        result: null,
        error: null,
        recentSearches: recentSearches,
      );
}

class SearchNotifier extends StateNotifier<SearchState> {
  final SearchTracksUsecase _usecase;
  Timer? _debounce;

  SearchNotifier(this._usecase) : super(const SearchState()) {
    _loadRecentSearches();
  }

  void _loadRecentSearches() {
    final box = Hive.box(AppConstants.cacheBox);
    final recent = List<String>.from(
      box.get('recent_searches', defaultValue: <String>[]) as List,
    );
    state = state.copyWith(recentSearches: recent);
  }

  void onQueryChanged(String query) {
    state = state.clearResult().copyWith(query: query);
    _debounce?.cancel();
    if (query.trim().isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 500), search);
  }

  Future<void> searchNow(String query) async {
    _debounce?.cancel();
    state = state.clearResult().copyWith(query: query);
    await search();
  }

  Future<void> search() async {
    final q = state.query.trim();
    if (q.isEmpty) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _usecase(q);
      state = state.copyWith(isLoading: false, result: result, error: null);
      _saveRecentSearch(q);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _saveRecentSearch(String query) {
    final box = Hive.box(AppConstants.cacheBox);
    final recent = List<String>.from(state.recentSearches);
    recent.remove(query);
    recent.insert(0, query);
    final trimmed = recent.take(10).toList();
    box.put('recent_searches', trimmed);
    state = state.copyWith(recentSearches: trimmed);
  }

  void clearRecentSearches() {
    final box = Hive.box(AppConstants.cacheBox);
    box.delete('recent_searches');
    state = state.copyWith(recentSearches: []);
  }

  void clear() {
    _debounce?.cancel();
    state = const SearchState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final searchNotifierProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(sl<SearchTracksUsecase>());
});
