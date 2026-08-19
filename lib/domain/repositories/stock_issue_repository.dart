import 'package:test_y_app/data/models/stock_document/stock_document_forms.dart';

abstract class StockIssueRepository {
  Future<StockIssueDocumentData> getById(String id);
  Future<StockIssueDocumentData> create(Map<String, dynamic> body);
  Future<StockIssueDocumentData> update(String id, Map<String, dynamic> body);
}
