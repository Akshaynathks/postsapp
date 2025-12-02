import 'dart:async';
import 'package:bloc/bloc.dart';
import '../../data/models/post_model.dart';
import '../../data/repositories/posts_repository.dart';
import 'posts_event.dart';
import 'posts_state.dart';

class PostsBloc extends Bloc<PostsEvent, PostsState> {
  final PostsRepository postsRepository;
  static const int _limit = 20;
  int _page = 1;
  bool _isFetchingMore = false;
  List<PostModel> _allPosts = [];

  Timer? _searchTimer;

  PostsBloc({required this.postsRepository}) : super(PostsInitial()) {
    on<LoadInitialPosts>(_onLoadInitial);
    on<LoadMorePosts>(_onLoadMore);
    on<RefreshPosts>(_onRefresh);
    on<SearchPostEvent>(_onSearch);
  }

  @override
  Future<void> close() {
    _searchTimer?.cancel();
    return super.close();
  }

  Future<void> _onLoadInitial(
    LoadInitialPosts event,
    Emitter<PostsState> emit,
  ) async {
    emit(PostsLoading());

    // Try to load from cache first
    try {
      final cachedPosts = await postsRepository.getCachedPosts();
      if (cachedPosts != null && cachedPosts.isNotEmpty) {
        _allPosts = cachedPosts;
        emit(PostsLoaded(posts: cachedPosts, hasMore: true, isCached: true));
      }
    } catch (e) {
      print('Cache loading error: $e');
      // Continue to fetch from network even if cache fails
    }

    _page = 1;
    try {
      final posts = await postsRepository.fetchPosts(
        page: _page,
        limit: _limit,
        cacheResponse: true,
      );
      _allPosts = posts;
      final hasMore = posts.length == _limit;
      emit(PostsLoaded(posts: posts, hasMore: hasMore, isCached: false));
    } catch (e) {
      // If we already have cached posts, show them
      if (_allPosts.isNotEmpty) {
        emit(PostsLoaded(posts: _allPosts, hasMore: false, isCached: true));
      } else {
        emit(PostsError(e.toString(), hasCachedData: false));
      }
    }
  }

  Future<void> _onLoadMore(
    LoadMorePosts event,
    Emitter<PostsState> emit,
  ) async {
    final currentState = state;
    if (_isFetchingMore) return;

    // Check if current state is PostsLoaded
    if (currentState is! PostsLoaded) return;

    if (currentState.hasMore) {
      _isFetchingMore = true;
      try {
        _page += 1;
        final newPosts = await postsRepository.fetchPosts(
          page: _page,
          limit: _limit,
        );
        final hasMore = newPosts.length == _limit;
        _allPosts.addAll(newPosts);
        emit(PostsLoaded(posts: _allPosts, hasMore: hasMore, isCached: false));
      } catch (e) {
        _page -= 1;
        emit(PostsError(e.toString(), hasCachedData: _allPosts.isNotEmpty));
      } finally {
        _isFetchingMore = false;
      }
    }
  }

  Future<void> _onRefresh(RefreshPosts event, Emitter<PostsState> emit) async {
    _page = 1;
    try {
      final posts = await postsRepository.fetchPosts(
        page: _page,
        limit: _limit,
        cacheResponse: true,
      );
      _allPosts = posts;
      final hasMore = posts.length == _limit;
      emit(PostsLoaded(posts: posts, hasMore: hasMore, isCached: false));
    } catch (e) {
      emit(PostsError(e.toString(), hasCachedData: _allPosts.isNotEmpty));
    }
  }

  void _onSearch(SearchPostEvent event, Emitter<PostsState> emit) {
    if (event.query.isEmpty) {
      emit(PostsLoaded(posts: _allPosts, hasMore: true, isCached: false));
    } else {
      final query = event.query.toLowerCase();
      final filtered = _allPosts
          .where(
            (post) =>
                post.title.toLowerCase().contains(query) ||
                post.body.toLowerCase().contains(query),
          )
          .toList();

      emit(PostsLoaded(posts: filtered, hasMore: false, isCached: false));
    }
  }

  // Public method for search with debounce
  void searchPosts(String query) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 500), () {
      add(SearchPostEvent(query));
    });
  }
}
