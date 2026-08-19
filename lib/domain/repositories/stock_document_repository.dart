import 'package:test_y_app/data/models/stock_document/stock_document.dart';

abstract class StockDocumentRepository {
  Future<List<StockDocument>> list(String documentType);
  Future<StockDocument> getDetail(String documentType, String id);
  Future<StockDocument> action(String documentType, String id, Map<String, dynamic> body);
  Future<List<TimelineEvent>> timeline(String documentType, String id);
}
