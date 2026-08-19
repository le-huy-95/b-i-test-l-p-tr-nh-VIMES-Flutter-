import 'package:test_y_app/data/datasources/api_endpoints.dart';
import 'package:test_y_app/data/datasources/api_services/base_api_service.dart';
import 'package:test_y_app/data/models/product/product.dart';

class ProductApiService extends BaseApiService {
  String _errorMessage(ApiResponse<dynamic> response, String fallback) {
    final err = response.error;
    if (err != null && err.isNotEmpty && !err.startsWith('{')) {
      return err;
    }
    return response.message?.isNotEmpty == true ? response.message! : fallback;
  }

  Never _throwFailed(ApiResponse<dynamic> response, String fallback) {
    throw Exception(_errorMessage(response, fallback));
  }

  List<Product> _decodeList(dynamic value) {
    if (value is List) {
      return value.map((item) {
        if (item is Map<String, dynamic>) return Product.fromJson(item);
        return Product.fromJson(Map<String, dynamic>.from(item as Map));
      }).toList();
    }
    if (value is Map && value['data'] is List) {
      return _decodeList(value['data']);
    }
    return const [];
  }

  Product _decodeOne(dynamic value) {
    if (value is Map<String, dynamic>) return Product.fromJson(value);
    return Product.fromJson(Map<String, dynamic>.from(value as Map));
  }

  Future<List<Product>> list() async {
    final response = await getRequest<List<Product>>(
      ApiEndpoints.products,
      decode: _decodeList,
    );
    if (!response.success || response.data == null) {
      _throwFailed(response, 'Không tải được danh sách sản phẩm');
    }
    return response.data!;
  }

  /// Tra cứu theo `search` (sku/name/barcode), trả về trang đầu tiên.
  Future<List<Product>> search(String query, {int limit = 20}) async {
    final response = await getRequest<List<Product>>(
      ApiEndpoints.products,
      queryParameters: {'search': query.trim(), 'limit': limit},
      decode: _decodeList,
    );
    if (!response.success || response.data == null) {
      _throwFailed(response, 'Không tìm thấy sản phẩm');
    }
    return response.data!;
  }

  Future<Product> getById(String id) async {
    final response = await getRequest<Product>(
      ApiEndpoints.product(id),
      decode: _decodeOne,
    );
    if (!response.success || response.data == null) {
      _throwFailed(response, 'Không tìm thấy sản phẩm');
    }
    return response.data!;
  }

  Future<ProductAvailability> getAvailability(String id) async {
    final response = await getRequest<ProductAvailability>(
      ApiEndpoints.productAvailability(id),
      decode: (value) {
        if (value is Map<String, dynamic>) {
          return ProductAvailability.fromJson(value);
        }
        return ProductAvailability.fromJson(
          Map<String, dynamic>.from(value as Map),
        );
      },
    );
    if (!response.success || response.data == null) {
      _throwFailed(response, 'Không tải được tồn kho của sản phẩm');
    }
    return response.data!;
  }

  Future<Product> create(Map<String, dynamic> body) async {
    final response = await postRequest<Product>(
      ApiEndpoints.products,
      body: body,
      decode: _decodeOne,
    );
    if (!response.success || response.data == null) {
      _throwFailed(response, 'Tạo sản phẩm thất bại');
    }
    return response.data!;
  }

  Future<Product> update(String id, Map<String, dynamic> body) async {
    final response = await putRequest<Product>(
      ApiEndpoints.product(id),
      body: body,
      decode: _decodeOne,
    );
    if (!response.success || response.data == null) {
      _throwFailed(response, 'Cập nhật sản phẩm thất bại');
    }
    return response.data!;
  }

  Future<void> delete(String id) async {
    final response = await deleteRequest<dynamic>(
      ApiEndpoints.product(id),
    );
    if (!response.success) {
      _throwFailed(response, 'Xóa sản phẩm thất bại');
    }
  }
}
