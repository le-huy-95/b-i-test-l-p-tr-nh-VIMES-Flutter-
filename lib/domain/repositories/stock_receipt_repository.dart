import 'package:test_y_app/data/models/stock_document/stock_document_forms.dart';

abstract class StockReceiptRepository {
  Future<StockReceiptDocumentData> getById(String id);
  Future<StockReceiptDocumentData> create(Map<String, dynamic> body);
  Future<StockReceiptDocumentData> update(String id, Map<String, dynamic> body);
}
