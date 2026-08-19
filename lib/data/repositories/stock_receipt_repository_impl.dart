import 'package:test_y_app/data/datasources/api_services/stock_receipt_api_service.dart';
import 'package:test_y_app/data/models/stock_document/stock_document_forms.dart';
import 'package:test_y_app/domain/repositories/stock_receipt_repository.dart';

class StockReceiptRepositoryImpl implements StockReceiptRepository {
  StockReceiptRepositoryImpl({StockReceiptApiService? apiService})
      : _api = apiService ?? StockReceiptApiService();

  final StockReceiptApiService _api;

  @override
  Future<StockReceiptDocumentData> getById(String id) => _api.getById(id);

  @override
  Future<StockReceiptDocumentData> create(Map<String, dynamic> body) => _api.create(body);

  @override
  Future<StockReceiptDocumentData> update(String id, Map<String, dynamic> body) =>
      _api.update(id, body);
}
