import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:posts_list/data/models/post_model.dart';
import 'package:posts_list/presentation/screens/posts_detail_screen.dart';
import '../../logic/posts_bloc/posts_bloc.dart';
import '../../logic/posts_bloc/posts_event.dart';
import '../../logic/posts_bloc/posts_state.dart';
import '../widgets/post_item.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/shimmer_placeholder.dart';

class PostsScreen extends StatefulWidget {
  const PostsScreen({Key? key}) : super(key: key);

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  late PostsBloc _postsBloc;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _postsBloc = context.read<PostsBloc>();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);

    // Initial load if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_postsBloc.state is PostsInitial) {
        _postsBloc.add(LoadInitialPosts());
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final thresholdPixels = 200.0;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll <= thresholdPixels) {
      _postsBloc.add(LoadMorePosts());
    }
  }

  Future<void> _onRefresh() async {
    _isRefreshing = true;
    _postsBloc.add(RefreshPosts());
    await Future.delayed(const Duration(seconds: 1));
    _isRefreshing = false;
  }

  void _onSearchChanged() {
    final currentState = _postsBloc.state;
    if (currentState is PostsLoaded || currentState is PostsError) {
      _postsBloc.searchPosts(_searchController.text);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _postsBloc.searchPosts('');
  }

  void _navigateToDetail(PostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Posts'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _onRefresh),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: "Search posts...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearSearch,
                  ),
                ),
              ),
            ),

            Expanded(
              child: BlocConsumer<PostsBloc, PostsState>(
                listener: (context, state) {
                  if (state is PostsError && !state.hasCachedData) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.message),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    });
                  }
                },
                builder: (context, state) {
                  // Handle loading state (initial load)
                  if (state is PostsLoading && !_isRefreshing) {
                    return _buildShimmerList();
                  }

                  // Handle error state
                  if (state is PostsError) {
                    return _buildErrorState(state);
                  }

                  // Handle loaded state
                  if (state is PostsLoaded) {
                    return _buildPostsList(state);
                  }

                  // Handle initial state - show shimmer
                  if (state is PostsInitial) {
                    return _buildShimmerList();
                  }

                  // Fallback
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (context, index) {
        return const PostShimmerItem();
      },
    );
  }

  Widget _buildErrorState(PostsError state) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.amber,
            size: 60,
          ),
          const SizedBox(height: 16),
          const Text(
            'Failed to Load Posts',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Network error. Please check your connection.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
          ),
          if (state.hasCachedData)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text(
                'Showing cached data from last session',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.blue,
                ),
              ),
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _postsBloc.add(LoadInitialPosts()),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsList(PostsLoaded state) {
    final posts = state.posts;

    if (posts.isEmpty) {
      return const Center(child: Text('No posts found'));
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: AnimationLimiter(
        child: ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: posts.length + (state.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index < posts.length) {
              final post = posts[index];
              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 500),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: GestureDetector(
                      onTap: () => _navigateToDetail(post),
                      child: PostItem(post: post),
                    ),
                  ),
                ),
              );
            } else {
              // Show shimmer for loading more instead of just LoadingIndicator
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: PostShimmerItem(),
              );
            }
          },
        ),
      ),
    );
  }
}
