import 'package:equatable/equatable.dart';

abstract class PostsEvent extends Equatable {
  const PostsEvent();

  @override
  List<Object?> get props => [];
}

class LoadInitialPosts extends PostsEvent {}

class LoadMorePosts extends PostsEvent {}

class RefreshPosts extends PostsEvent {}

class SearchPostEvent extends PostsEvent {
  final String query;
  const SearchPostEvent(this.query);

  @override
  List<Object?> get props => [query];
}
