import 'package:test_y_app/data/datasources/api_endpoints.dart';
import 'package:test_y_app/data/datasources/api_services/base_api_service.dart';
import 'package:test_y_app/data/models/stock_document/stock_document_forms.dart';
import 'package:uuid/uuid.dart';

class StockIssueApiService extends BaseApiService {
  static const _uuid = Uuid();

  StockIssueDocumentData _decodeOne(dynamic value) {
    if (value is Map<String, dynamic>) return StockIssueDocumentData.fromJson(value);
    return StockIssueDocumentData.fromJson(Map<String, dynamic>.from(value as Map));
  }

  Future<StockIssueDocumentData> getById(String id) async {
    final response = await getRequest<StockIssueDocumentData>(
      ApiEndpoints.stockIssue(id),
      decode: _decodeOne,
    );
    if (!response.success || response.data == null) {
      throw Exception(response.error ?? response.message ?? 'Không tải được phiếu xuất hàng');
    }
    return response.data!;
  }

  Future<StockIssueDocumentData> create(Map<String, dynamic> body) async {
    final response = await postRequest<StockIssueDocumentData>(
      ApiEndpoints.stockIssues,
      headers: {'Idempotency-Key': _uuid.v4()},
      body: body,
      decode: _decodeOne,
    );
    if (!response.success || response.data == null) {
      throw Exception(response.error ?? response.message ?? 'Tạo phiếu xuất hàng thất bại');
    }
    return response.data!;
  }

  Future<StockIssueDocumentData> update(String id, Map<String, dynamic> body) async {
    final response = await putRequest<StockIssueDocumentData>(
      ApiEndpoints.stockIssue(id),
      headers: {'Idempotency-Key': _uuid.v4()},
      body: body,
      decode: _decodeOne,
    );
    if (!response.success || response.data == null) {
      throw Exception(response.error ?? response.message ?? 'Cập nhật phiếu xuất hàng thất bại');
    }
    return response.data!;
  }
}
