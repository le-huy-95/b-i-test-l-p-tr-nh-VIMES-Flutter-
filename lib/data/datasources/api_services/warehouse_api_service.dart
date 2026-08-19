import 'package:test_y_app/data/datasources/api_endpoints.dart';
import 'package:test_y_app/data/datasources/api_services/base_api_service.dart';
import 'package:test_y_app/data/models/warehouse/warehouse.dart';

class WarehouseApiService extends BaseApiService {
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

  List<Warehouse> _decodeList(dynamic value) {
    if (value is List) {
      return value.map((item) {
        if (item is Map<String, dynamic>) return Warehouse.fromJson(item);
        return Warehouse.fromJson(Map<String, dynamic>.from(item as Map));
      }).toList();
    }
    if (value is Map && value['data'] is List) {
      return _decodeList(value['data']);
    }
    return const [];
  }

  Warehouse _decodeOne(dynamic value) {
    if (value is Map<String, dynamic>) return Warehouse.fromJson(value);
    return Warehouse.fromJson(Map<String, dynamic>.from(value as Map));
  }

  Future<List<Warehouse>> list() async {
    final response = await getRequest<List<Warehouse>>(
      ApiEndpoints.warehouses,
      decode: _decodeList,
    );
    if (!response.success || response.data == null) {
      _throwFailed(response, 'Không tải được danh sách kho');
    }
    return response.data!;
  }

  Future<Warehouse> getById(String id) async {
    final response = await getRequest<Warehouse>(
      ApiEndpoints.warehouse(id),
      decode: _decodeOne,
    );
    if (!response.success || response.data == null) {
      _throwFailed(response, 'Không tìm thấy kho');
    }
    return response.data!;
  }

  Future<Warehouse> create(Map<String, dynamic> body) async {
    final response = await postRequest<Warehouse>(
      ApiEndpoints.warehouses,
      body: body,
      decode: _decodeOne,
    );
    if (!response.success || response.data == null) {
      _throwFailed(response, 'Tạo kho thất bại');
    }
    return response.data!;
  }

  Future<Warehouse> activate(String id) async {
    final response = await patchRequest<Warehouse>(
      ApiEndpoints.warehouseActivate(id),
      decode: _decodeOne,
    );
    if (!response.success || response.data == null) {
      _throwFailed(response, 'Kích hoạt kho thất bại');
    }
    return response.data!;
  }

  Future<Warehouse> deactivate(String id) async {
    final response = await patchRequest<Warehouse>(
      ApiEndpoints.warehouseDeactivate(id),
      decode: _decodeOne,
    );
    if (!response.success || response.data == null) {
      _throwFailed(response, 'Ngừng hoạt động kho thất bại');
    }
    return response.data!;
  }

  Future<Warehouse> update(String id, Map<String, dynamic> body) async {
    final response = await putRequest<Warehouse>(
      ApiEndpoints.warehouse(id),
      body: body,
      decode: _decodeOne,
    );
    if (!response.success || response.data == null) {
      _throwFailed(response, 'Cập nhật kho thất bại');
    }
    return response.data!;
  }
}
