import 'package:test_y_app/data/datasources/api_services/stock_issue_api_service.dart';
import 'package:test_y_app/data/models/stock_document/stock_document_forms.dart';
import 'package:test_y_app/domain/repositories/stock_issue_repository.dart';

class StockIssueRepositoryImpl implements StockIssueRepository {
  StockIssueRepositoryImpl({StockIssueApiService? apiService})
      : _api = apiService ?? StockIssueApiService();

  final StockIssueApiService _api;

  @override
  Future<StockIssueDocumentData> getById(String id) => _api.getById(id);

  @override
  Future<StockIssueDocumentData> create(Map<String, dynamic> body) => _api.create(body);

  @override
  Future<StockIssueDocumentData> update(String id, Map<String, dynamic> body) =>
      _api.update(id, body);
}
