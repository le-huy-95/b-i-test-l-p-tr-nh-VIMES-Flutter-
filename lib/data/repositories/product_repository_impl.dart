import 'package:test_y_app/data/datasources/api_services/product_api_service.dart';
import 'package:test_y_app/data/models/product/product.dart';
import 'package:test_y_app/domain/repositories/product_repository.dart';

class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl({ProductApiService? apiService})
      : _api = apiService ?? ProductApiService();

  final ProductApiService _api;

  @override
  Future<List<Product>> list() => _api.list();

  @override
  Future<List<Product>> search(String query, {int limit = 20}) =>
      _api.search(query, limit: limit);

  @override
  Future<Product> getById(String id) => _api.getById(id);

  @override
  Future<ProductAvailability> getAvailability(String id) =>
      _api.getAvailability(id);

  @override
  Future<Product> create(Map<String, dynamic> body) => _api.create(body);

  @override
  Future<Product> update(String id, Map<String, dynamic> body) =>
      _api.update(id, body);

  @override
  Future<void> delete(String id) => _api.delete(id);
}
