import 'package:test_y_app/data/models/product/product.dart';

abstract class ProductRepository {
  Future<List<Product>> list();
  Future<List<Product>> search(String query, {int limit = 20});
  Future<Product> getById(String id);
  Future<ProductAvailability> getAvailability(String id);
  Future<Product> create(Map<String, dynamic> body);
  Future<Product> update(String id, Map<String, dynamic> body);
  Future<void> delete(String id);
}
