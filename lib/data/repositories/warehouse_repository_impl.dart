import 'package:test_y_app/data/datasources/api_services/warehouse_api_service.dart';
import 'package:test_y_app/data/models/warehouse/warehouse.dart';
import 'package:test_y_app/domain/repositories/warehouse_repository.dart';

class WarehouseRepositoryImpl implements WarehouseRepository {
  WarehouseRepositoryImpl({WarehouseApiService? apiService})
      : _api = apiService ?? WarehouseApiService();

  final WarehouseApiService _api;

  @override
  Future<List<Warehouse>> list() => _api.list();

  @override
  Future<Warehouse> getById(String id) => _api.getById(id);

  @override
  Future<Warehouse> create(Map<String, dynamic> body) => _api.create(body);

  @override
  Future<Warehouse> update(String id, Map<String, dynamic> body) =>
      _api.update(id, body);

  @override
  Future<Warehouse> activate(String id) => _api.activate(id);

  @override
  Future<Warehouse> deactivate(String id) => _api.deactivate(id);
}
