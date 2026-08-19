double? parseFlexibleDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return double.tryParse(text);
}

class Warehouse {
  const Warehouse({
    required this.id,
    required this.tenantId,
    required this.code,
    required this.name,
    this.address,
    this.phone,
    this.isActive = true,
    this.latitude,
    this.longitude,
    this.geoSource,
    this.geocodeStatus,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String code;
  final String name;
  final String? address;
  final String? phone;
  final bool isActive;
  final double? latitude;
  final double? longitude;
  final String? geoSource;
  final String? geocodeStatus;
  final String? createdAt;
  final String? updatedAt;

  String get statusText => isActive ? 'Đang hoạt động' : 'Ngừng hoạt động';

  bool get hasCoordinates => latitude != null && longitude != null;

  factory Warehouse.fromJson(Map<String, dynamic> json) {
    return Warehouse(
      id: (json['id'] ?? '').toString(),
      tenantId: (json['tenantId'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      address: json['address']?.toString(),
      phone: json['phone']?.toString(),
      isActive: json['isActive'] as bool? ?? true,
      latitude: parseFlexibleDouble(json['latitude']),
      longitude: parseFlexibleDouble(json['longitude']),
      geoSource: json['geoSource']?.toString(),
      geocodeStatus: json['geocodeStatus']?.toString(),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenantId': tenantId,
    'code': code,
    'name': name,
    if (address != null) 'address': address,
    if (phone != null) 'phone': phone,
    'isActive': isActive,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (geoSource != null) 'geoSource': geoSource,
    if (geocodeStatus != null) 'geocodeStatus': geocodeStatus,
    if (createdAt != null) 'createdAt': createdAt,
    if (updatedAt != null) 'updatedAt': updatedAt,
  };
}
