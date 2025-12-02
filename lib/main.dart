import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'logic/posts_bloc/posts_event.dart';
import 'data/repositories/posts_repository.dart';
import 'logic/posts_bloc/posts_bloc.dart';
import 'presentation/screens/posts_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();
  await Hive.openBox('posts');

  final postsRepository = PostsRepository();
  runApp(MyApp(postsRepository: postsRepository));
}

class MyApp extends StatelessWidget {
  final PostsRepository postsRepository;
  const MyApp({Key? key, required this.postsRepository}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Posts',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: RepositoryProvider.value(
        value: postsRepository,
        child: BlocProvider(
          create: (context) =>
              PostsBloc(postsRepository: postsRepository)
                ..add(LoadInitialPosts()),
          child: const PostsScreen(),
        ),
      ),
    );
  }
}
