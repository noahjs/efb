import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/api_client.dart';
import '../../../services/airport_providers.dart';

class AirportsScreen extends ConsumerStatefulWidget {
  const AirportsScreen({super.key});

  @override
  ConsumerState<AirportsScreen> createState() => _AirportsScreenState();
}

class _AirportsScreenState extends ConsumerState<AirportsScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSearching = false;
  List<dynamic>? _searchResults;
  bool _searchLoading = false;

  void _onSearchChanged(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchLoading = true;
    });

    try {
      final client = ref.read(apiClientProvider);
      final result = await client.searchAirports(query: query, limit: 25);
      if (mounted && _searchController.text == query) {
        setState(() {
          _searchResults = result['items'] as List<dynamic>?;
          _searchLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _searchLoading = false;
        });
      }
    }
  }

  Future<void> _toggleStar(String identifier, bool isStarred) async {
    final client = ref.read(apiClientProvider);
    try {
      if (isStarred) {
        await client.unstarAirport(identifier);
      } else {
        await client.starAirport(identifier);
      }
      ref.invalidate(starredAirportsProvider);
    } catch (_) {
      // ignore
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final starredAsync = ref.watch(starredAirportsProvider);
    final starredIdsAsync = ref.watch(starredAirportIdsProvider);
    final starredIds =
        starredIdsAsync.whenOrNull(data: (ids) => ids) ?? <String>{};

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Search header
            Container(
              color: AppColors.toolbarBackground,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'Airports',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      if (_isSearching)
                        TextButton(
                          onPressed: () {
                            _searchController.clear();
                            _focusNode.unfocus();
                            setState(() {
                              _isSearching = false;
                              _searchResults = null;
                            });
                          },
                          child: const Text('Cancel',
                              style: TextStyle(color: AppColors.accent)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    onChanged: _onSearchChanged,
                    onTap: () {
                      if (_searchController.text.isNotEmpty) {
                        setState(() => _isSearching = true);
                      }
                    },
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search by identifier, name, or city',
                      prefixIcon: const Icon(Icons.search,
                          color: AppColors.textMuted, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: AppColors.textMuted, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isSearching
                  ? _buildSearchResults(starredIds)
                  : _buildStarredList(starredAsync, starredIds),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarredList(
      AsyncValue<List<dynamic>> starredAsync, Set<String> starredIds) {
    return starredAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.textMuted, size: 32),
            const SizedBox(height: 8),
            const Text('Unable to load starred airports',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => ref.invalidate(starredAirportsProvider),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            ),
          ],
        ),
      ),
      data: (airports) {
        if (airports.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_border,
                      color: AppColors.textMuted, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'No starred airports',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Search for airports to add them to your list',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(starredAirportsProvider);
            await ref.read(starredAirportsProvider.future);
          },
          child: ListView.separated(
            itemCount: airports.length,
            separatorBuilder: (_, _) => const Divider(height: 0.5),
            itemBuilder: (context, index) {
              final airport = airports[index] as Map<String, dynamic>;
              final identifier = airport['identifier'] ?? '';
              final icao = airport['icao_identifier'] ?? '';
              final displayId =
                  icao.isNotEmpty ? icao : identifier;
              final name = airport['name'] ?? '';
              final city = airport['city'] ?? '';
              final state = airport['state'] ?? '';
              final elevation = airport['elevation'];
              final location =
                  [city, state].where((s) => s.isNotEmpty).join(', ');

              return ListTile(
                onTap: () => context.push('/airports/$displayId'),
                title: Row(
                  children: [
                    Text(
                      displayId,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                subtitle: Row(
                  children: [
                    if (location.isNotEmpty)
                      Text(
                        location,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    if (location.isNotEmpty && elevation != null)
                      const SizedBox(width: 12),
                    if (elevation != null)
                      Text(
                        'Elev: ${(elevation as num).round()}\'',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.star, color: AppColors.starred, size: 22),
                  onPressed: () => _toggleStar(identifier, true),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSearchResults(Set<String> starredIds) {
    if (_searchLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final results = _searchResults;
    if (results == null) {
      return const Center(
        child: Text(
          'Search for airports by identifier, name, or city',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    if (results.isEmpty) {
      return const Center(
        child: Text(
          'No airports found',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, _) => const Divider(height: 0.5),
      itemBuilder: (context, index) {
        final airport = results[index] as Map<String, dynamic>;
        final identifier = airport['identifier'] ?? '';
        final icao = airport['icao_identifier'] ?? '';
        final displayId = icao.isNotEmpty ? icao : identifier;
        final name = airport['name'] ?? '';
        final city = airport['city'] ?? '';
        final state = airport['state'] ?? '';
        final elevation = airport['elevation'];
        final location =
            [city, state].where((s) => s.isNotEmpty).join(', ');
        final isStarred = starredIds.contains(identifier);

        return ListTile(
          onTap: () => context.push('/airports/$displayId'),
          title: Row(
            children: [
              Text(
                displayId,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Row(
            children: [
              if (location.isNotEmpty)
                Text(
                  location,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              if (location.isNotEmpty && elevation != null)
                const SizedBox(width: 12),
              if (elevation != null)
                Text(
                  'Elev: ${(elevation as num).round()}\'',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
          trailing: IconButton(
            icon: Icon(
              isStarred ? Icons.star : Icons.star_border,
              color: isStarred ? AppColors.starred : AppColors.textMuted,
              size: 22,
            ),
            onPressed: () => _toggleStar(identifier, isStarred),
          ),
        );
      },
    );
  }
}
