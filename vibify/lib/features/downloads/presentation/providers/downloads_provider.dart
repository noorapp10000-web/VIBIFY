import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/download_item.dart';
import '../../domain/usecases/download_usecases.dart';
import '../../../player/domain/entities/track.dart';

class DownloadsNotifier extends StateNotifier<AsyncValue<List<DownloadItem>>> {
  final DownloadUsecases _usecases;

  DownloadsNotifier(this._usecases) : super(const AsyncLoading()) {
    load();
    _listenToProgress();
  }

  Future<void> load() async {
    try {
      final downloads = await _usecases.getAll();
      state = AsyncData(downloads);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void _listenToProgress() {
    _usecases.progressStream.listen((item) {
      final current = state.valueOrNull ?? [];
      final idx = current.indexWhere((d) => d.id == item.id);
      if (idx >= 0) {
        final updated = [...current];
        updated[idx] = item;
        state = AsyncData(updated);
      } else {
        state = AsyncData([item, ...current]);
      }
    });
  }

  Future<void> startDownload(Track track) async {
    await _usecases.start(track);
    await load();
  }

  Future<void> pause(String id) => _usecases.pause(id);
  Future<void> resume(String id) => _usecases.resume(id);
  Future<void> cancel(String id) async {
    await _usecases.cancel(id);
    await load();
  }

  Future<void> retry(String id) => _usecases.retry(id);

  Future<void> delete(String id) async {
    await _usecases.delete(id);
    await load();
  }

  Future<void> clearCompleted() async {
    final current = state.valueOrNull ?? [];
    final completed = current.where((d) => d.isCompleted).toList();
    for (final item in completed) {
      await _usecases.delete(item.id);
    }
    await load();
  }
}

final downloadsNotifierProvider =
    StateNotifierProvider<DownloadsNotifier, AsyncValue<List<DownloadItem>>>(
        (ref) {
  return DownloadsNotifier(sl<DownloadUsecases>());
});

/// Returns the latest DownloadItem for the given track id, or null if never downloaded.
final trackDownloadStatusProvider =
    Provider.family<DownloadItem?, String>((ref, trackId) {
  final downloads = ref.watch(downloadsNotifierProvider).valueOrNull ?? [];
  try {
    return downloads.firstWhere((d) => d.track.id == trackId);
  } catch (_) {
    return null;
  }
});
