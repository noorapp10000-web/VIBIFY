import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../player/domain/entities/track.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../providers/search_provider.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchNotifierProvider);
    final notifier = ref.read(searchNotifierProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
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
                ],
              ),
            ),

            // Content
            Expanded(
              child: searchState.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(AppColors.primaryBeige),
                      ),
                    )
                  : searchState.query.isEmpty
                      ? _RecentSearches(
                          recent: searchState.recentSearches,
                          onTap: (q) {
                            _controller.text = q;
                            notifier.onQueryChanged(q);
                            notifier.search();
                          },
                          onClear: notifier.clearRecentSearches,
                        )
                      : searchState.result == null
                          ? const _BrowseCategories()
                          : searchState.result!.isEmpty
                              ? const _EmptyResults()
                              : _SearchResults(
                                  result: searchState.result!,
                                ),
            ),
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

  const _RecentSearches({
    required this.recent,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (recent.isEmpty) return const _BrowseCategories();

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
                child: Text(
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
      ],
    );
  }
}

class _BrowseCategories extends StatelessWidget {
  const _BrowseCategories();

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

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Browse Genres', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
              physics: const BouncingScrollPhysics(),
              children: categories
                  .map((cat) => _CategoryTile(
                        label: cat.$1,
                        color: cat.$2,
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final Color color;

  const _CategoryTile({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
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
                Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
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
            onPressed: () => ref
                .read(playerNotifierProvider.notifier)
                .addToQueue(track),
            icon: Icon(
              Icons.add_rounded,
              color: Theme.of(context)
                  .colorScheme
                  .onBackground
                  .withOpacity(0.5),
            ),
          ),
        );
      },
    );
  }

  Widget _thumb() => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.primaryBeige.withOpacity(0.15),
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
            backgroundColor: AppColors.primaryBeige.withOpacity(0.2),
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
              color: AppColors.primaryBeige.withOpacity(0.2),
              child: const Icon(Icons.playlist_play_rounded,
                  color: AppColors.primaryBeige),
            ),
          ),
          title: Text(playlist.title,
              style: Theme.of(context).textTheme.titleSmall),
          subtitle: playlist.author != null
              ? Text(playlist.author!,
                  style: Theme.of(context).textTheme.bodySmall)
              : null,
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
            size: 64,
            color: Theme.of(context)
                .colorScheme
                .onBackground
                .withOpacity(0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'No results found',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onBackground
                      .withOpacity(0.5),
                ),
          ),
        ],
      ),
    );
  }
}
