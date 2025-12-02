import 'package:equatable/equatable.dart';
import '../../data/models/post_model.dart';

abstract class PostsState extends Equatable {
  const PostsState();

  @override
  List<Object?> get props => [];
}

class PostsInitial extends PostsState {}

class PostsLoading extends PostsState {}

class PostsLoaded extends PostsState {
  final List<PostModel> posts;
  final bool hasMore;
  final bool isCached;

  const PostsLoaded({
    this.posts = const [],
    this.hasMore = false,
    this.isCached = false,
  });

  @override
  List<Object?> get props => [posts, hasMore, isCached];
}

class PostsError extends PostsState {
  final String message;
  final bool hasCachedData;

  const PostsError(this.message, {this.hasCachedData = false});

  @override
  List<Object?> get props => [message, hasCachedData];
}
