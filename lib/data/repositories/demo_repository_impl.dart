import 'package:test_y_app/data/datasources/api_services/auth_api_service.dart';
import 'package:test_y_app/data/models/post/post.dart';
import 'package:test_y_app/domain/repositories/demo_repository.dart';

class DemoRepositoryImpl implements DemoRepository {
  DemoRepositoryImpl({DemoApiService? apiService}) : _apiService = apiService ?? DemoApiService();

  final DemoApiService _apiService;

  @override
  Future<List<Post>> getPosts({int limit = 10}) => _apiService.getPosts(limit: limit);
}
