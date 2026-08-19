import 'package:test_y_app/data/models/post/post.dart';

abstract class DemoRepository {
  Future<List<Post>> getPosts({int limit = 10});
}
