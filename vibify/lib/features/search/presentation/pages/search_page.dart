import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/add_to_playlist_sheet.dart';
import '../../../../core/widgets/download_option.dart';
import '../../../player/data/datasources/youtube_stream_service.dart';
import '../../../player/domain/entities/track.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../providers/search_provider.dart';

const String _kDefaultQuery = 'حمو المرشدي';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isFocused = false;
  bool _isAutoTesting = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.text = _kDefaultQuery;
      final notifier = ref.read(searchNotifierProvider.notifier);
      notifier.onQueryChanged(_kDefaultQuery);
      notifier.search();
    });
  }

  /// اختبار كامل: بحث → استخراج رابط الصوت
  Future<void> _runDebugTest() async {
    if (_isAutoTesting) return;
    setState(() => _isAutoTesting = true);

    final messenger = ScaffoldMessenger.of(context);

    try {
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('[DebugTest] Query: $_kDefaultQuery');

      // 1. بحث عبر Cloudflare Worker
      final notifier = ref.read(searchNotifierProvider.notifier);
      await notifier.search();
      final state = ref.read(searchNotifierProvider);

      if (state.result == null || state.result!.tracks.isEmpty) {
        debugPrint('[DebugTest] ✗ No search results');
        messenger.showSnackBar(const SnackBar(
          content: Text('البحث لم يُرجع نتائج — تحقق من الكونسول'),
          backgroundColor: Colors.red,
        ));
        return;
      }

      final firstTrack = state.result!.tracks.first;
      debugPrint('[DebugTest] ✓ Search OK → "${firstTrack.title}" '
          'by ${firstTrack.artist} (${firstTrack.youtubeVideoId})');

      // 2. استخراج رابط الصوت عبر youtube_explode_dart
      final videoId = firstTrack.youtubeVideoId ?? firstTrack.id;
      debugPrint('[DebugTest] Fetching stream URL for $videoId …');

      final streamService = YoutubeStreamService();
      final streamUrl = await streamService.getAudioUrl(videoId);

      if (streamUrl != null && streamUrl.isNotEmpty) {
        debugPrint('[DebugTest] ✓ Stream URL OK (${streamUrl.length} chars)');
        debugPrint('═══════════════════════════════════════════════════════');
        messenger.showSnackBar(SnackBar(
          content: Text('✓ يعمل! "${firstTrack.title}"'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ));
      } else {
        debugPrint('[DebugTest] ✗ Stream URL was null');
        debugPrint('═══════════════════════════════════════════════════════');
        messenger.showSnackBar(const SnackBar(
          content: Text('رابط الصوت فارغ — تحقق من الكونسول'),
          backgroundColor: Colors.orange,
        ));
      }
    } catch (e) {
      debugPrint('[DebugTest] ✗ Exception: $e');
      debugPrint('═══════════════════════════════════════════════════════');
      messenger.showSnackBar(SnackBar(
        content: Text('الاختبار فشل: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isAutoTesting = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _searchGenre(String genre) {
    _controller.text = genre;
    final notifier = ref.read(searchNotifierProvider.notifier);
    notifier.onQueryChanged(genre);
    notifier.search();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchNotifierProvider);
    final notifier = ref.read(searchNotifierProvider.notifier);

    Widget body;

    if (searchState.isLoading) {
      body = const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppColors.primaryBeige),
        ),
      );
    } else if (searchState.error != null) {
      body = _ErrorWidget(
        error: searchState.error!,
        onRetry: notifier.search,
      );
    } else if (searchState.result != null) {
      body = searchState.result!.isEmpty
          ? const _EmptyResults()
          : _SearchResults(result: searchState.result!);
    } else if (_isFocused && searchState.query.isEmpty) {
      body = _RecentSearches(
        recent: searchState.recentSearches,
        onTap: (q) {
          _controller.text = q;
          notifier.onQueryChanged(q);
          notifier.search();
        },
        onClear: notifier.clearRecentSearches,
        onGenreTap: _searchGenre,
      );
    } else {
      body = _BrowseCategories(onTap: _searchGenre);
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: notifier.onQueryChanged,
                onSubmitted: (_) => notifier.search(),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search songs, artists, playlists...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: searchState.query.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _controller.clear();
                            notifier.clear();
                          },
                          icon: const Icon(Icons.close_rounded, size: 18),
                        )
                      : null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isAutoTesting ? null : _runDebugTest,
                  icon: _isAutoTesting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.biotech_rounded, size: 16),
                  label: Text(
                    _isAutoTesting
                        ? 'Testing…'
                        : 'Test Search & Stream (حمو المرشدي)',
                    style: const TextStyle(fontSize: 12, fontFamily: 'Inter'),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBeige,
                    side: const BorderSide(
                        color: AppColors.primaryBeige, width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _RecentSearches extends StatelessWidget {
  final List<String> recent;
  final void Function(String) onTap;
  final VoidCallback onClear;
  final void Function(String) onGenreTap;

  const _RecentSearches({
    required this.recent,
    required this.onTap,
    required this.onClear,
    required this.onGenreTap,
  });

  @override
  Widget build(BuildContext context) {
    if (recent.isEmpty) return _BrowseCategories(onTap: onGenreTap);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Searches',
                  style: Theme.of(context).textTheme.titleSmall),
              TextButton(
                onPressed: onClear,
                child: const Text(
                  'Clear',
                  style: TextStyle(
                    color: AppColors.primaryBeige,
                    fontSize: 13,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
        ),
        ...recent.map((q) => ListTile(
              leading: const Icon(Icons.history_rounded),
              title: Text(q, style: Theme.of(context).textTheme.bodyMedium),
              trailing: const Icon(Icons.north_west_rounded, size: 16),
              onTap: () => onTap(q),
            )),
        const Divider(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Browse Genres',
              style: Theme.of(context).textTheme.titleSmall),
        ),
        const SizedBox(height: 8),
        Expanded(child: _GenreGrid(onTap: onGenreTap)),
      ],
    );
  }
}

class _BrowseCategories extends StatelessWidget {
  final void Function(String) onTap;

  const _BrowseCategories({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Browse Genres',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Expanded(child: _GenreGrid(onTap: onTap)),
        ],
      ),
    );
  }
}

class _GenreGrid extends StatelessWidget {
  final void Function(String) onTap;

  const _GenreGrid({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final categories = [
      ('Pop', const Color(0xFFE91E63)),
      ('Hip-Hop', const Color(0xFF9C27B0)),
      ('Rock', const Color(0xFF3F51B5)),
      ('Electronic', const Color(0xFF00BCD4)),
      ('R&B', const Color(0xFFFF5722)),
      ('Jazz', const Color(0xFF795548)),
      ('Classical', const Color(0xFF607D8B)),
      ('Country', const Color(0xFF8BC34A)),
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      physics: const BouncingScrollPhysics(),
      children: categories
          .map((cat) => _CategoryTile(
                label: cat.$1,
                color: cat.$2,
                onTap: () => onTap(cat.$1),
              ))
          .toList(),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  final dynamic result;

  const _SearchResults({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            indicatorColor: AppColors.primaryBeige,
            labelColor: AppColors.primaryBeige,
            unselectedLabelColor:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            labelStyle: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            tabs: [
              Tab(text: 'Songs (${result.tracks.length})'),
              Tab(text: 'Artists (${result.artists.length})'),
              Tab(text: 'Playlists (${result.playlists.length})'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _TrackList(tracks: result.tracks),
                _ArtistList(artists: result.artists),
                _PlaylistList(playlists: result.playlists),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackList extends ConsumerWidget {
  final List<Track> tracks;

  const _TrackList({required this.tracks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tracks.isEmpty) return const _EmptyResults();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      physics: const BouncingScrollPhysics(),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        return ListTile(
          onTap: () {
            ref.read(playerNotifierProvider.notifier).playAll(
              tracks,
              startIndex: index,
            );
            context.push(AppRoutes.player);
          },
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: track.thumbnailUrl != null
                ? CachedNetworkImage(
                    imageUrl: track.thumbnailUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _thumb(),
                  )
                : _thumb(),
          ),
          title: Text(
            track.title,
            style: Theme.of(context).textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            track.artist,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
          ),
          trailing: IconButton(
            onPressed: () => _showTrackMenu(context, ref, track, tracks, index),
            icon: Icon(
              Icons.more_vert_rounded,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
          ),
        );
      },
    );
  }

  void _showTrackMenu(
    BuildContext context,
    WidgetRef ref,
    Track track,
    List<Track> tracks,
    int index,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: track.thumbnailUrl != null
                        ? CachedNetworkImage(
                            imageUrl: track.thumbnailUrl!,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 44,
                            height: 44,
                            color: AppColors.primaryBeige.withValues(alpha: 0.2),
                            child: const Icon(Icons.music_note_rounded,
                                color: AppColors.primaryBeige),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(track.title,
                            style: Theme.of(context).textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(track.artist,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.play_arrow_rounded),
              title: const Text('Play Now'),
              onTap: () {
                Navigator.pop(context);
                ref
                    .read(playerNotifierProvider.notifier)
                    .playAll(tracks, startIndex: index);
                context.push(AppRoutes.player);
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: const Text('Add to Queue'),
              onTap: () {
                Navigator.pop(context);
                ref.read(playerNotifierProvider.notifier).addToQueue(track);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Added to queue'),
                    duration: Duration(seconds: 2),
                    backgroundColor: AppColors.primaryBeige,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded),
              title: const Text('Add to Playlist'),
              onTap: () {
                Navigator.pop(context);
                showAddToPlaylistSheet(context, ref, track);
              },
            ),
            DownloadOption(
              track: track,
              onDownloadStarted: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _thumb() => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.primaryBeige.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.music_note_rounded,
          color: AppColors.primaryBeige,
          size: 20,
        ),
      );
}

class _ArtistList extends StatelessWidget {
  final List<dynamic> artists;

  const _ArtistList({required this.artists});

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) return const _EmptyResults();
    return ListView.builder(
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        return ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryBeige.withValues(alpha: 0.2),
            backgroundImage: artist.thumbnailUrl != null
                ? CachedNetworkImageProvider(artist.thumbnailUrl!)
                : null,
            child: artist.thumbnailUrl == null
                ? const Icon(Icons.person_rounded,
                    color: AppColors.primaryBeige)
                : null,
          ),
          title: Text(artist.name,
              style: Theme.of(context).textTheme.titleSmall),
        );
      },
    );
  }
}

class _PlaylistList extends StatelessWidget {
  final List<dynamic> playlists;

  const _PlaylistList({required this.playlists});

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) return const _EmptyResults();
    return ListView.builder(
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 48,
              height: 48,
              color: AppColors.primaryBeige.withValues(alpha: 0.2),
              child: const Icon(Icons.playlist_play_rounded,
                  color: AppColors.primaryBeige),
            ),
          ),
          title: Text(playlist.title,
              style: Theme.of(context).textTheme.titleSmall),
          subtitle: playlist.author != null ? Text(playlist.author!) : null,
        );
      },
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 56,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.25),
          ),
          const SizedBox(height: 12),
          Text(
            'No results found',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
                ),
          ),
        ],
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorWidget({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: AppColors.primaryBeige),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBeige,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
