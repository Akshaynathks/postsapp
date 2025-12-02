import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import '../models/post_model.dart';

class PostsRepository {
  static const _baseUrl = 'https://jsonplaceholder.typicode.com/posts';
  final http.Client _client;
  bool _isHiveInitialized = false;

  PostsRepository({http.Client? client}) : _client = client ?? http.Client();

  /// Initialize Hive
  Future<void> _ensureHiveInitialized() async {
    if (!_isHiveInitialized) {
      try {
        await Hive.initFlutter();
        _isHiveInitialized = true;
      } catch (e) {
        print('Hive initialization failed: $e');
        _isHiveInitialized = false;
      }
    }
  }

  /// Fetch posts  page with limit 20
  Future<List<PostModel>> fetchPosts({
    required int page,
    int limit = 20,
    bool cacheResponse = true,
  }) async {
    final uri = Uri.parse('$_baseUrl?_page=$page&_limit=$limit');
    final res = await _client.get(uri);

    if (res.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(res.body) as List<dynamic>;
      final posts = jsonList
          .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
          .toList();

      if (cacheResponse && page == 1) {
        await _cachePosts(posts);
      }

      return posts;
    } else {
      throw Exception('Error fetching posts: ${res.statusCode}');
    }
  }

  /// Save posts to Hive cache
  Future<void> _cachePosts(List<PostModel> posts) async {
    try {
      await _ensureHiveInitialized();
      if (!_isHiveInitialized) return;

      final box = await Hive.openBox('posts');
      await box.put(
        'cached_posts',
        posts.map((post) => post.toJson()).toList(),
      );
    } catch (e) {
      print('Cache save error: $e');
      // Don't throw, caching is optional
    }
  }

  /// Load posts from Hive cache
  Future<List<PostModel>?> getCachedPosts() async {
    try {
      await _ensureHiveInitialized();
      if (!_isHiveInitialized) return null;

      final box = await Hive.openBox('posts');
      final cachedData = box.get('cached_posts');

      if (cachedData != null && cachedData is List) {
        return cachedData
            .map((e) => PostModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return null;
    } catch (e) {
      print('Cache load error: $e');
      return null;
    }
  }
}
