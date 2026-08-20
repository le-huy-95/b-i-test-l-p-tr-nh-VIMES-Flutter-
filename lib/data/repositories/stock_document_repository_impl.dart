import 'package:test_y_app/data/datasources/api_services/stock_document_api_service.dart';
import 'package:test_y_app/data/models/stock_document/stock_document.dart';
import 'package:test_y_app/domain/repositories/stock_document_repository.dart';

class StockDocumentRepositoryImpl implements StockDocumentRepository {
  StockDocumentRepositoryImpl({StockDocumentApiService? apiService})
      : _api = apiService ?? StockDocumentApiService();

  final StockDocumentApiService _api;

  @override
  Future<List<StockDocument>> list(String documentType) => _api.list(documentType);

  @override
  Future<StockDocument> getDetail(String documentType, String id) =>
      _api.detail(documentType, id);

  @override
  Future<StockDocument> action(String documentType, String id, Map<String, dynamic> body) =>
      _api.action(documentType, id, body);

  @override
  Future<List<TimelineEvent>> timeline(String documentType, String id) =>
      _api.timeline(documentType, id);

  @override
  Future<AvailableActions> availableActions(String documentType, String id) =>
      _api.availableActions(documentType, id);
}
