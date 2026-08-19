import 'package:test_y_app/data/datasources/api_endpoints.dart';
import 'package:test_y_app/data/datasources/api_services/base_api_service.dart';

class SupplierOption {
  const SupplierOption({required this.id, required this.name, this.code, this.phone});

  final String id;
  final String name;
  final String? code;
  final String? phone;
}

class SupplierApiService extends BaseApiService {
  List<SupplierOption> _decodeList(dynamic value) {
    if (value is List) {
      return value.map((item) {
        final map = item is Map<String, dynamic>
            ? item
            : Map<String, dynamic>.from(item as Map);
        return SupplierOption(
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

  SupplierOption _decodeOne(dynamic value) {
    final map = value is Map<String, dynamic>
        ? value
        : Map<String, dynamic>.from(value as Map);
    return SupplierOption(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      code: map['code']?.toString(),
      phone: map['phone']?.toString(),
    );
  }

  Future<List<SupplierOption>> list() async {
    final response = await getRequest<List<SupplierOption>>(
      ApiEndpoints.suppliers,
      decode: _decodeList,
    );
    if (!response.success || response.data == null) {
      throw Exception(response.error ?? response.message ?? 'Không tải được nhà cung cấp');
    }
    return response.data!;
  }

  Future<SupplierOption> create({
    required String code,
    required String name,
    String? taxCode,
    String? contact,
  }) async {
    final response = await postRequest<SupplierOption>(
      ApiEndpoints.suppliers,
      body: {
        'code': code.trim(),
        'name': name.trim(),
        if (taxCode != null && taxCode.trim().isNotEmpty) 'taxCode': taxCode.trim(),
        if (contact != null && contact.trim().isNotEmpty) 'contact': contact.trim(),
      },
      decode: _decodeOne,
    );
    if (!response.success || response.data == null) {
      throw Exception(response.error ?? response.message ?? 'Không tạo được nhà cung cấp');
    }
    return response.data!;
  }
}
