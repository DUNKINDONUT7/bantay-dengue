import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/image_picker_stub.dart';
import '../../theme/app_theme.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/section_header.dart';

const int _pageSize = 12;

enum _CommunityFilter { latest, trending, mine }

/// Resident-only peer-support feed — share a dengue recovery journey,
/// comment on others', and send a "love" reaction. See
/// supabase/COMMUNITY_STORIES.sql for the schema/RLS this relies on: this
/// screen never enforces "resident-only" itself, RLS already does that
/// server-side (an attempt from any other role fails with a permission
/// error the same way every other RLS-gated write in this app does).
///
/// The feed updates live (new posts/comments/reactions from other
/// residents appear without a manual refresh) via
/// `DatabaseService.watchCommunityFeed` — see supabase/COMMUNITY_REALTIME.sql
/// for the publication/replica-identity setup that makes that possible.
/// Pull-to-refresh and the header refresh button still do a full resync on
/// demand; live updates are additive, not a replacement.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  List<Map<String, dynamic>> _posts = [];
  Map<String, int> _loveCounts = {};
  Set<String> _myReactedPostIds = {};
  Map<String, int> _commentCounts = {};
  Object? _error;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  final Set<String> _busyPostIds = {};
  final _scrollController = ScrollController();
  _CommunityFilter _filter = _CommunityFilter.latest;
  String _search = '';

  RealtimeChannel? _feedChannel;
  Timer? _liveDebounce;

  bool get _isAdmin => authService.currentUser?.role == UserRole.admin;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
    _feedChannel = DatabaseService.instance.watchCommunityFeed(
      _scheduleLiveRefresh,
    );
  }

  @override
  void dispose() {
    _liveDebounce?.cancel();
    _feedChannel?.unsubscribe();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  /// Live changes arrive one at a time (an insert, then its own engagement
  /// notification insert, etc.) — debounce so a burst of related events
  /// triggers one refresh, not several back-to-back ones.
  void _scheduleLiveRefresh() {
    _liveDebounce?.cancel();
    _liveDebounce = Timer(const Duration(milliseconds: 500), _liveRefresh);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts = await DatabaseService.instance.fetchCommunityPosts(
        limit: _pageSize,
      );
      await _applyEngagement(posts);
      _posts = posts;
      _hasMore = posts.length == _pageSize;
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_posts.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final oldest = _posts.last['created_at'] as String?;
      final more = await DatabaseService.instance.fetchCommunityPosts(
        limit: _pageSize,
        before: oldest,
      );
      await _applyEngagement(more, mergeInto: true);
      _posts = [..._posts, ...more];
      _hasMore = more.length == _pageSize;
    } catch (_) {
      // Load-more failing quietly is fine — the user can scroll again or
      // pull-to-refresh; surfacing a banner for a background pagination
      // fetch would be disproportionate.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// Realtime-triggered, in-place refresh: pulls in any posts newer than
  /// what's already on screen, drops any currently-shown post that's been
  /// soft-deleted/moderated elsewhere, and refreshes reaction/comment
  /// counts for everything currently loaded. Deliberately does NOT touch
  /// `_loading` — this must never show a spinner or blank the list, that's
  /// the whole point of "dynamic, not a page reload".
  Future<void> _liveRefresh() async {
    if (!mounted) return;
    if (_posts.isEmpty) {
      await _load();
      return;
    }
    try {
      final newest = _posts.first['created_at'] as String?;
      final newPosts = newest == null
          ? <Map<String, dynamic>>[]
          : await DatabaseService.instance.fetchCommunityPosts(
              limit: 20,
              after: newest,
            );
      final currentIds = _posts.map((p) => '${p['id']}').toList();
      final visible = await DatabaseService.instance
          .fetchVisibleCommunityPostIds(currentIds);
      final merged = [
        ...newPosts,
        ..._posts.where((p) => visible.contains('${p['id']}')),
      ];
      await _applyEngagement(merged, mergeInto: true, replace: true);
      if (!mounted) return;
      setState(() => _posts = merged);
    } catch (_) {
      // Best-effort — live updates failing silently just means the next
      // pull-to-refresh catches up instead. Never surface an error banner
      // for a background sync the user didn't ask for.
    }
  }

  /// Fetches reactions + comment counts for [posts] and folds them into
  /// `_loveCounts`/`_myReactedPostIds`/`_commentCounts`. [mergeInto] keeps
  /// existing entries for ids not in this batch (used for load-more and
  /// live refresh, which only touch a subset of the feed); the initial
  /// load replaces the maps outright.
  Future<void> _applyEngagement(
    List<Map<String, dynamic>> posts, {
    bool mergeInto = false,
    bool replace = false,
  }) async {
    final postIds = posts.map((p) => '${p['id']}').toList();
    final values = await Future.wait([
      DatabaseService.instance.fetchCommunityReactions(postIds),
      DatabaseService.instance.fetchCommunityCommentCounts(postIds),
    ]);
    final reactions = values[0];
    final comments = values[1];
    final myId = authService.currentUser?.id;

    final loveCounts = mergeInto ? Map<String, int>.from(_loveCounts) : {};
    final myReacted = mergeInto
        ? Set<String>.from(_myReactedPostIds)
        : <String>{};
    final commentCounts = mergeInto
        ? Map<String, int>.from(_commentCounts)
        : {};

    for (final id in postIds) {
      loveCounts[id] = 0;
      myReacted.remove(id);
      commentCounts[id] = 0;
    }
    for (final reaction in reactions) {
      final postId = '${reaction['post_id']}';
      loveCounts[postId] = (loveCounts[postId] ?? 0) + 1;
      if (reaction['user_id'] == myId) myReacted.add(postId);
    }
    for (final comment in comments) {
      final postId = '${comment['post_id']}';
      commentCounts[postId] = (commentCounts[postId] ?? 0) + 1;
    }

    _loveCounts = loveCounts.cast<String, int>();
    _myReactedPostIds = myReacted;
    _commentCounts = commentCounts.cast<String, int>();
  }

  Future<void> _toggleReaction(Map<String, dynamic> post) async {
    final postId = '${post['id']}';
    if (_busyPostIds.contains(postId)) return;
    final currentlyReacted = _myReactedPostIds.contains(postId);
    setState(() {
      _busyPostIds.add(postId);
      // Optimistic update — this is a lightweight, frequent action (like a
      // Facebook like), waiting for a round-trip before showing feedback
      // would feel broken. Reverted in the catch block if the write fails.
      if (currentlyReacted) {
        _myReactedPostIds.remove(postId);
        _loveCounts[postId] = (_loveCounts[postId] ?? 1) - 1;
      } else {
        _myReactedPostIds.add(postId);
        _loveCounts[postId] = (_loveCounts[postId] ?? 0) + 1;
      }
    });
    try {
      await DatabaseService.instance.setCommunityReaction(
        postId: postId,
        reacted: !currentlyReacted,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          // Revert the optimistic update.
          if (currentlyReacted) {
            _myReactedPostIds.add(postId);
            _loveCounts[postId] = (_loveCounts[postId] ?? 0) + 1;
          } else {
            _myReactedPostIds.remove(postId);
            _loveCounts[postId] = (_loveCounts[postId] ?? 1) - 1;
          }
        });
        showMessage(context, errorMessage(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _busyPostIds.remove(postId));
    }
  }

  Future<void> _deletePost(Map<String, dynamic> post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this story?'),
        content: Text(
          _isAdmin && post['author_id'] != authService.currentUser?.id
              ? 'This removes the post for everyone. This cannot be undone.'
              : 'This removes your story. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await DatabaseService.instance.deleteCommunityPost('${post['id']}');
      if (mounted) showMessage(context, 'Story removed.');
      await _load();
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    }
  }

  Future<void> _openComposer() async {
    final posted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _ComposeStorySheet(),
    );
    if (posted == true) await _load();
  }

  Future<void> _openComments(Map<String, dynamic> post) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _CommentsSheet(post: post, onChanged: _load),
    );
  }

  // Only residents can post (RLS: community_posts_insert requires
  // current_role() = 'resident') — admin reaches this screen for
  // moderation only, so the compose FAB would just surface a permission
  // error for them. Hiding it is cheap and avoids that dead end.
  bool get _canPost => authService.currentUser?.role == UserRole.civilian;

  /// Loaded-posts-only count, same "no new query, just count what's
  /// already fetched" pattern dashboard_screen.dart uses for its own
  /// this-week captions.
  int get _sinceLastWeek {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return _posts.where((p) {
      final created = DateTime.tryParse('${p['created_at']}');
      return created != null && created.isAfter(cutoff);
    }).length;
  }

  /// Client-side only, over whatever pages are already loaded — there's no
  /// server-side search/trending query behind this. "Trending" is an
  /// approximation (love ×2 + comments, on currently-loaded posts only);
  /// good enough for browsing what's on screen without a bigger
  /// server-side ranking feature this app doesn't have yet.
  List<Map<String, dynamic>> get _visiblePosts {
    var list = _posts;
    if (_search.isNotEmpty) {
      list = list
          .where(
            (p) => '${p['content'] ?? ''}'.toLowerCase().contains(_search),
          )
          .toList();
    }
    switch (_filter) {
      case _CommunityFilter.mine:
        final myId = authService.currentUser?.id;
        list = list.where((p) => p['author_id'] == myId).toList();
      case _CommunityFilter.trending:
        list = [...list]..sort((a, b) {
          final aId = '${a['id']}';
          final bId = '${b['id']}';
          final aScore =
              (_loveCounts[aId] ?? 0) * 2 + (_commentCounts[aId] ?? 0);
          final bScore =
              (_loveCounts[bId] ?? 0) * 2 + (_commentCounts[bId] ?? 0);
          return bScore.compareTo(aScore);
        });
      case _CommunityFilter.latest:
        break;
    }
    return list;
  }

  /// Whether a filter/search is narrowing the view — while active, the
  /// infinite-scroll "load more" sentinel is hidden (see build()): mixing
  /// a pagination spinner into a client-side-filtered, re-sorted list
  /// would be confusing, and there's no server-side query behind these
  /// filters to paginate against anyway. Background pagination itself
  /// keeps working underneath; clearing the filter reveals whatever
  /// loaded while it was on.
  bool get _isFiltering =>
      _search.isNotEmpty || _filter != _CommunityFilter.latest;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _canPost
          ? FloatingActionButton.extended(
              onPressed: _openComposer,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Share your story'),
            )
          : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'Community stories',
              subtitle:
                  'A safe space to share your dengue journey, connect, and '
                  'support each other — not an official medical or case '
                  'record.',
              action: IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _CommunityToolbar(
                storyCountThisWeek: _sinceLastWeek,
                filter: _filter,
                onFilterChanged: (f) => setState(() => _filter = f),
                onSearchChanged: (q) =>
                    setState(() => _search = q.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: AsyncStateView(
                loading: _loading,
                error: _error,
                empty: _posts.isEmpty,
                emptyTitle: 'No stories yet',
                emptyMessage:
                    'Be the first to share your journey with the community.',
                onRetry: _load,
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: Builder(
                    builder: (context) {
                      final items = _visiblePosts;
                      final showLoadMore = !_isFiltering && _hasMore;
                      if (items.isEmpty) {
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
                          children: const [
                            Center(
                              child: Text(
                                'No stories match this filter.',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            ),
                          ],
                        );
                      }
                      return ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        itemCount: items.length + (showLoadMore ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          if (index >= items.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                  ),
                                ),
                              ),
                            );
                          }
                          final post = items[index];
                          final postId = '${post['id']}';
                          return _PostCard(
                            key: ValueKey(postId),
                            post: post,
                            loveCount: _loveCounts[postId] ?? 0,
                            commentCount: _commentCounts[postId] ?? 0,
                            reacted: _myReactedPostIds.contains(postId),
                            canDelete:
                                _isAdmin ||
                                post['author_id'] ==
                                    authService.currentUser?.id,
                            onReact: () => _toggleReaction(post),
                            onComment: () => _openComments(post),
                            onDelete: () => _deletePost(post),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "hierarchy" block between the page title and the feed itself: a
/// one-line activity stat, filter pills (Latest/Trending/My Stories), and
/// search — everything client-side over already-loaded posts (see
/// `_CommunityScreenState._visiblePosts`), no server-side search/ranking
/// query exists behind this.
class _CommunityToolbar extends StatelessWidget {
  final int storyCountThisWeek;
  final _CommunityFilter filter;
  final ValueChanged<_CommunityFilter> onFilterChanged;
  final ValueChanged<String> onSearchChanged;

  const _CommunityToolbar({
    required this.storyCountThisWeek,
    required this.filter,
    required this.onFilterChanged,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.local_fire_department_outlined,
              size: 15,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 5),
            Text(
              storyCountThisWeek == 0
                  ? 'No new stories this week yet'
                  : '$storyCountThisWeek ${storyCountThisWeek == 1 ? 'story' : 'stories'} shared this week',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _FilterPill(
              label: 'Latest',
              selected: filter == _CommunityFilter.latest,
              onTap: () => onFilterChanged(_CommunityFilter.latest),
            ),
            const SizedBox(width: 8),
            _FilterPill(
              label: 'Trending',
              selected: filter == _CommunityFilter.trending,
              onTap: () => onFilterChanged(_CommunityFilter.trending),
            ),
            const SizedBox(width: 8),
            _FilterPill(
              label: 'My Stories',
              selected: filter == _CommunityFilter.mine,
              onTap: () => onFilterChanged(_CommunityFilter.mine),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: TextField(
            onChanged: onSearchChanged,
            style: const TextStyle(fontSize: 13.5),
            decoration: const InputDecoration(
              hintText: 'Search community stories',
              hintStyle: TextStyle(fontSize: 13.5),
              prefixIcon: Icon(Icons.search, size: 19),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.ink : AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.ink : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.onPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final int loveCount;
  final int commentCount;
  final bool reacted;
  final bool canDelete;
  final VoidCallback onReact;
  final VoidCallback onComment;
  final VoidCallback onDelete;

  const _PostCard({
    super.key,
    required this.post,
    required this.loveCount,
    required this.commentCount,
    required this.reacted,
    required this.canDelete,
    required this.onReact,
    required this.onComment,
    required this.onDelete,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _showHeartBurst = false;

  void _onDoubleTapPhoto() {
    if (!widget.reacted) widget.onReact();
    setState(() => _showHeartBurst = true);
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _showHeartBurst = false);
    });
  }

  String _timeAgo(dynamic value) {
    final raw = value?.toString();
    if (raw == null) return '';
    final date = DateTime.tryParse(raw);
    if (date == null) return '';
    final diff = DateTime.now().difference(date.toLocal());
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
    return formatDateTime(value);
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final author = post['profiles'] as Map<String, dynamic>?;
    final authorName = author?['full_name'] as String? ?? 'Resident';
    final authorPhoto = author?['photo_url'] as String?;
    final photoPath = post['photo_url'] as String?;
    final hasPhoto = photoPath != null && photoPath.trim().isNotEmpty;
    final displayName = authorName.trim().isEmpty ? 'Resident' : authorName;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: AppColors.surfaceElevated,
                  backgroundImage:
                      authorPhoto != null && authorPhoto.trim().isNotEmpty
                      ? NetworkImage(
                          DatabaseService.instance.avatarPublicUrl(
                            authorPhoto,
                          ),
                        )
                      : null,
                  child: authorPhoto == null || authorPhoto.trim().isEmpty
                      ? Text(
                          displayName[0].toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _timeAgo(post['created_at']),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.canDelete)
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_horiz,
                      color: AppColors.textMuted,
                    ),
                    tooltip: 'More',
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: AppColors.danger,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Remove',
                              style: TextStyle(color: AppColors.danger),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (_) => widget.onDelete(),
                  ),
              ],
            ),
          ),
          if ('${post['content'] ?? ''}'.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Text(
                '${post['content'] ?? ''}',
                style: const TextStyle(height: 1.35, fontSize: 14.5),
              ),
            ),
          if (hasPhoto)
            GestureDetector(
              onDoubleTap: _onDoubleTapPhoto,
              onTap: () => _openFullscreenImage(
                context,
                DatabaseService.instance.communityPhotoPublicUrl(photoPath),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Fixed height (not just a cap) on purpose — a max-height
                  // alone still let a tall/odd-aspect image (a document
                  // screenshot, a Gantt chart, whatever a resident
                  // actually attaches) dominate the whole card at close to
                  // the cap every time. A fixed box + BoxFit.cover crops
                  // instead, but every post's media now takes up exactly
                  // the same amount of space, which is what actually reads
                  // as "consistent" scrolling through a feed.
                  SizedBox(
                    height: 260,
                    width: double.infinity,
                    child: Image.network(
                      DatabaseService.instance.communityPhotoPublicUrl(
                        photoPath,
                      ),
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          alignment: Alignment.center,
                          color: AppColors.surfaceElevated,
                          child: const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: _showHeartBurst ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: AnimatedScale(
                      scale: _showHeartBurst ? 1.1 : 0.6,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: 92,
                        shadows: [
                          Shadow(color: Colors.black38, blurRadius: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // One labeled action row instead of bare icons — the counts
          // always show (even "0"), because hiding a zero is exactly what
          // made these read as broken/disconnected: no way to tell "no
          // reactions yet" from "this number failed to load".
          Padding(
            padding: EdgeInsets.fromLTRB(10, hasPhoto ? 10 : 4, 10, 10),
            child: Row(
              children: [
                _ActionPill(
                  icon: widget.reacted
                      ? Icons.favorite
                      : Icons.favorite_border,
                  label: 'Support',
                  count: widget.loveCount,
                  active: widget.reacted,
                  onTap: widget.onReact,
                ),
                const SizedBox(width: 8),
                _ActionPill(
                  icon: Icons.mode_comment_outlined,
                  label: 'Comments',
                  count: widget.commentCount,
                  active: false,
                  onTap: widget.onComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Single tap on a post photo — pinch-zoom, black background, matches the
/// pattern already used for waste-evidence photos
/// (waste_collection_screen.dart's `_viewPhoto`), just full-screen instead
/// of a bounded dialog since a social feed photo warrants the bigger view.
void _openFullscreenImage(BuildContext context, String url) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, __) =>
          FadeTransition(opacity: animation, child: _FullscreenImage(url: url)),
    ),
  );
}

class _FullscreenImage extends StatelessWidget {
  final String url;
  const _FullscreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 48,
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: Colors.black45),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _ActionPill({
    required this.icon,
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.danger : AppColors.textSecondary;
    return Expanded(
      child: Material(
        color: active
            ? AppColors.danger.withValues(alpha: 0.08)
            : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: color),
                const SizedBox(width: 6),
                Text(
                  '$label $count',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposeStorySheet extends StatefulWidget {
  const _ComposeStorySheet();

  @override
  State<_ComposeStorySheet> createState() => _ComposeStorySheetState();
}

class _ComposeStorySheetState extends State<_ComposeStorySheet> {
  final _content = TextEditingController();
  Uint8List? _photo;
  bool _posting = false;

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _content.text.trim();
    if (text.length < 5) {
      showMessage(
        context,
        'Share at least a few words about your journey.',
        error: true,
      );
      return;
    }
    setState(() => _posting = true);
    try {
      await DatabaseService.instance.createCommunityPost(
        content: text,
        photoBytes: _photo,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myName = authService.profile?.fullName ?? 'You';
    final myPhoto = authService.profile?.photoUrl;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.surfaceElevated,
                backgroundImage: myPhoto != null && myPhoto.trim().isNotEmpty
                    ? NetworkImage(
                        DatabaseService.instance.avatarPublicUrl(myPhoto),
                      )
                    : null,
                child: myPhoto == null || myPhoto.trim().isEmpty
                    ? Text(myName.isNotEmpty ? myName[0].toUpperCase() : '?')
                    : null,
              ),
              const SizedBox(width: 10),
              Text(
                'Share your story',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 46),
            child: Text(
              'Visible to other residents. Not a medical record — for '
              'urgent symptoms, use Report a case instead.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: TextField(
              controller: _content,
              minLines: 4,
              maxLines: 8,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: "What's your journey been like?",
                alignLabelWithHint: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
              ),
            ),
          ),
          if (_photo != null) ...[
            const SizedBox(height: 8),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Image.memory(
                    _photo!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: IconButton.filled(
                    onPressed: () => setState(() => _photo = null),
                    icon: const Icon(Icons.close, size: 16),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      minimumSize: const Size(28, 28),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _posting
                ? null
                : () async {
                    final bytes = await pickEvidenceImage(context);
                    if (bytes != null && mounted) {
                      setState(() => _photo = bytes);
                    }
                  },
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(
              _photo == null ? 'Add a photo (optional)' : 'Replace photo',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _posting ? null : _submit,
            icon: _posting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(_posting ? 'Sharing…' : 'Share'),
          ),
        ],
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onChanged;

  const _CommentsSheet({required this.post, required this.onChanged});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  List<Map<String, dynamic>> _comments = [];
  final _controller = TextEditingController();
  bool _loading = true;
  bool _sending = false;
  Object? _error;

  bool get _isAdmin => authService.currentUser?.role == UserRole.admin;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _comments = await DatabaseService.instance.fetchCommunityComments(
        '${widget.post['id']}',
      );
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await DatabaseService.instance.createCommunityComment(
        postId: '${widget.post['id']}',
        content: text,
      );
      _controller.clear();
      await _load();
      widget.onChanged();
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> comment) async {
    try {
      await DatabaseService.instance.deleteCommunityComment(
        '${comment['id']}',
      );
      await _load();
      widget.onChanged();
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Comments',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: AsyncStateView(
                loading: _loading,
                error: _error,
                empty: _comments.isEmpty,
                emptyTitle: 'No comments yet',
                emptyMessage: 'Be the first to respond.',
                onRetry: _load,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _comments.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final comment = _comments[index];
                    final author =
                        comment['profiles'] as Map<String, dynamic>?;
                    final mine =
                        comment['author_id'] == authService.currentUser?.id;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.surfaceElevated,
                          child: Text(
                            (author?['full_name'] as String? ?? '?')
                                    .isNotEmpty
                                ? (author?['full_name'] as String)[0]
                                      .toUpperCase()
                                : '?',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${author?['full_name'] ?? 'Resident'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text('${comment['content'] ?? ''}'),
                            ],
                          ),
                        ),
                        if (mine || _isAdmin)
                          IconButton(
                            onPressed: () => _delete(comment),
                            icon: const Icon(Icons.close, size: 16),
                            tooltip: 'Remove',
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Write a comment…',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onPrimary,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
