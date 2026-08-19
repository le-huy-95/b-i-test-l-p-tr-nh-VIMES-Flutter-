import 'package:test_y_app/data/models/warehouse/warehouse.dart';

abstract class WarehouseRepository {
  Future<List<Warehouse>> list();
  Future<Warehouse> getById(String id);
  Future<Warehouse> create(Map<String, dynamic> body);
  Future<Warehouse> update(String id, Map<String, dynamic> body);
  Future<Warehouse> activate(String id);
  Future<Warehouse> deactivate(String id);
}
