import 'package:test_y_app/data/datasources/api_endpoints.dart';
import 'package:test_y_app/data/datasources/api_services/base_api_service.dart';
import 'package:test_y_app/data/models/stock_document/stock_document.dart';
import 'package:uuid/uuid.dart';

class StockDocumentApiService extends BaseApiService {
  static const _uuid = Uuid();

  Future<List<StockDocument>> list(String type) async {
    final response = await getRequest<dynamic>(
      ApiEndpoints.workflowList,
      queryParameters: {'documentType': type, 'limit': 100},
    );
    if (!response.success) _throw(response, 'Không tải được danh sách phiếu');
    final raw = response.data;
    final rows = raw is Map ? raw['data'] : raw;
    return rows is List
        ? rows
            .whereType<Map>()
            .map((e) => StockDocument.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const [];
  }

  Future<StockDocument> detail(String type, String id) async {
    final response = await getRequest<StockDocument>(
      ApiEndpoints.workflowDetail(type, id),
      decode: (value) =>
          StockDocument.fromJson(Map<String, dynamic>.from(value as Map)),
    );
    if (!response.success || response.data == null) {
      _throw(response, 'Không tải được chi tiết phiếu');
    }
    return response.data!;
  }

  Future<StockDocument> action(
    String type,
    String id,
    Map<String, dynamic> body,
  ) async {
    final response = await postRequest<StockDocument>(
      ApiEndpoints.workflowActions(type, id),
      headers: {'Idempotency-Key': _uuid.v4()},
      body: body,
      decode: (value) =>
          StockDocument.fromJson(Map<String, dynamic>.from(value as Map)),
    );
    if (!response.success || response.data == null) {
      _throw(response, 'Thao tác phiếu thất bại');
    }
    return response.data!;
  }

  Future<List<TimelineEvent>> timeline(String type, String id) async {
    final response = await getRequest<dynamic>(ApiEndpoints.workflowTimeline(type, id));
    if (!response.success) _throw(response, 'Không tải được lịch sử phiếu');
    final raw = response.data;
    return raw is List
        ? raw
            .whereType<Map>()
            .map((e) => TimelineEvent.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const [];
  }

  Future<AvailableActions> availableActions(String type, String id) async {
    final response = await getRequest<AvailableActions>(
      ApiEndpoints.workflowAvailableActions(type, id),
      decode: (value) =>
          AvailableActions.fromJson(Map<String, dynamic>.from(value as Map)),
    );
    if (!response.success || response.data == null) {
      _throw(response, 'Không tải được actions');
    }
    return response.data!;
  }

  Never _throw(ApiResponse<dynamic> response, String fallback) {
    throw Exception(response.error ?? response.message ?? fallback);
  }
}
