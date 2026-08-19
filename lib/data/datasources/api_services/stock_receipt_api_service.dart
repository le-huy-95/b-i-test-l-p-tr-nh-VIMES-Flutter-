import 'package:test_y_app/data/datasources/api_endpoints.dart';
import 'package:test_y_app/data/datasources/api_services/base_api_service.dart';
import 'package:test_y_app/data/models/stock_document/stock_document_forms.dart';
import 'package:uuid/uuid.dart';

class StockReceiptApiService extends BaseApiService {
  static const _uuid = Uuid();

  StockReceiptDocumentData _decodeOne(dynamic value) {
    if (value is Map<String, dynamic>) return StockReceiptDocumentData.fromJson(value);
    return StockReceiptDocumentData.fromJson(Map<String, dynamic>.from(value as Map));
  }

  Future<StockReceiptDocumentData> getById(String id) async {
    final response = await getRequest<StockReceiptDocumentData>(
      ApiEndpoints.stockReceipt(id),
      decode: _decodeOne,
    );
    if (!response.success || response.data == null) {
      throw Exception(response.error ?? response.message ?? 'Không tải được phiếu nhập hàng');
    }
    return response.data!;
  }

  Future<StockReceiptDocumentData> create(Map<String, dynamic> body) async {
    final response = await postRequest<StockReceiptDocumentData>(
      ApiEndpoints.stockReceipts,
      headers: {'Idempotency-Key': _uuid.v4()},
      body: body,
      decode: _decodeOne,
    );
    if (!response.success || response.data == null) {
      throw Exception(response.error ?? response.message ?? 'Tạo phiếu nhập hàng thất bại');
    }
    return response.data!;
  }

  Future<StockReceiptDocumentData> update(String id, Map<String, dynamic> body) async {
    final response = await putRequest<StockReceiptDocumentData>(
      ApiEndpoints.stockReceipt(id),
      headers: {'Idempotency-Key': _uuid.v4()},
      body: body,
      decode: _decodeOne,
    );
    if (!response.success || response.data == null) {
      throw Exception(response.error ?? response.message ?? 'Cập nhật phiếu nhập hàng thất bại');
    }
    return response.data!;
  }
}
