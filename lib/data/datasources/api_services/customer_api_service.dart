import 'package:test_y_app/data/datasources/api_endpoints.dart';
import 'package:test_y_app/data/datasources/api_services/base_api_service.dart';

class CustomerOption {
  const CustomerOption({required this.id, required this.name, this.code, this.phone});

  final String id;
  final String name;
  final String? code;
  final String? phone;
}

class CustomerApiService extends BaseApiService {
  List<CustomerOption> _decodeList(dynamic value) {
    if (value is List) {
      return value.map((item) {
        final map = item is Map<String, dynamic>
            ? item
            : Map<String, dynamic>.from(item as Map);
        return CustomerOption(
          id: (map['id'] ?? '').toString(),
          name: (map['name'] ?? '').toString(),
          code: map['code']?.toString(),
          phone: map['phone']?.toString(),
        );
      }).toList();
    }
    if (value is Map && value['data'] is List) {
      return _decodeList(value['data']);
    }
    return const [];
  }

  Future<List<CustomerOption>> list() async {
    final response = await getRequest<List<CustomerOption>>(
      ApiEndpoints.customers,
      decode: _decodeList,
    );
    if (!response.success || response.data == null) {
      throw Exception(response.error ?? response.message ?? 'Không tải được khách hàng');
    }
    return response.data!;
  }

  Future<CustomerOption> create({
    required String code,
    required String name,
    String? phone,
    String? email,
  }) async {
    final response = await postRequest<CustomerOption>(
      ApiEndpoints.customers,
      body: {
        'code': code.trim(),
        'name': name.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      },
      decode: (value) {
        final map = value is Map<String, dynamic>
            ? value
            : Map<String, dynamic>.from(value as Map);
        return CustomerOption(
          id: (map['id'] ?? '').toString(),
          name: (map['name'] ?? '').toString(),
          code: map['code']?.toString(),
          phone: map['phone']?.toString(),
        );
      },
    );
    if (!response.success || response.data == null) {
      throw Exception(response.error ?? response.message ?? 'Không tạo được khách hàng');
    }
    return response.data!;
  }
}
