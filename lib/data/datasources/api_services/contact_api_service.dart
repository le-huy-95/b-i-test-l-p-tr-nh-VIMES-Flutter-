import 'package:test_y_app/data/datasources/api_endpoints.dart';
import 'package:test_y_app/data/datasources/api_services/base_api_service.dart';

class DeliveryContact {
  const DeliveryContact({
    required this.id,
    required this.fullName,
    this.kind = 'external',
    this.phone,
    this.email,
    this.companyName,
    this.note,
    this.isActive = true,
  });

  final String id;
  final String kind;
  final String fullName;
  final String? phone;
  final String? email;
  final String? companyName;
  final String? note;
  final bool isActive;

  factory DeliveryContact.fromJson(Map<String, dynamic> json) {
    return DeliveryContact(
      id: (json['id'] ?? '').toString(),
      kind: (json['kind'] ?? 'external').toString(),
      fullName: (json['fullName'] ?? '').toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      companyName: json['companyName']?.toString(),
      note: json['note']?.toString(),
      isActive: json['isActive'] == false ? false : true,
    );
  }
}

class ContactApiService extends BaseApiService {
  List<DeliveryContact> _decodeList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => DeliveryContact.fromJson(Map<String, dynamic>.from(item)))
          .where((contact) => contact.fullName.isNotEmpty)
          .toList();
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      if (map['data'] is List) return _decodeList(map['data']);
      if (map['items'] is List) return _decodeList(map['items']);
    }
    return const [];
  }

  DeliveryContact _decodeOne(dynamic value) {
    final map = value is Map<String, dynamic>
        ? value
        : value is Map
            ? Map<String, dynamic>.from(value)
            : <String, dynamic>{};
    final payload = map['data'] is Map ? map['data'] : map;
    return DeliveryContact.fromJson(
      payload is Map<String, dynamic>
          ? payload
          : Map<String, dynamic>.from(payload as Map),
    );
  }

  Future<List<DeliveryContact>> listDeliveryPersons({
    int limit = 200,
  }) async {
    final response = await getRequest<List<DeliveryContact>>(
      ApiEndpoints.tenantContacts,
      queryParameters: {
        'relationType': 'delivery_person',
        'limit': limit,
      },
      decode: _decodeList,
    );
    if (!response.success || response.data == null) {
      throw Exception(
        response.error ?? response.message ?? 'Không tải được người giao hàng',
      );
    }
    return response.data!;
  }

  Future<DeliveryContact> createDeliveryPerson({
    required String fullName,
    String? phone,
    String? email,
    String? companyName,
    String? taxCode,
    String? note,
  }) async {
    final response = await postRequest<DeliveryContact>(
      ApiEndpoints.tenantContacts,
      body: {
        'fullName': fullName.trim(),
        'relationType': 'delivery_person',
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (companyName != null && companyName.trim().isNotEmpty)
          'companyName': companyName.trim(),
        if (taxCode != null && taxCode.trim().isNotEmpty)
          'taxCode': taxCode.trim(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
      decode: _decodeOne,
    );
    if (!response.success || response.data == null) {
      throw Exception(
        response.error ?? response.message ?? 'Không tạo được người giao hàng',
      );
    }
    return response.data!;
  }
}
