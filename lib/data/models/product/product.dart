import 'package:test_y_app/data/models/warehouse/warehouse.dart';

class ProductUnit {
  const ProductUnit({
    required this.id,
    required this.productId,
    required this.unitName,
    required this.conversionRate,
  });

  final String id;
  final String productId;
  final String unitName;
  final double conversionRate;

  factory ProductUnit.fromJson(Map<String, dynamic> json) {
    return ProductUnit(
      id: (json['id'] ?? '').toString(),
      productId: (json['productId'] ?? '').toString(),
      unitName: (json['unitName'] ?? '').toString(),
      conversionRate: parseFlexibleDouble(json['conversionRate']) ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'unitName': unitName,
        'conversionRate': conversionRate,
      };
}

class Product {
  const Product({
    required this.id,
    required this.tenantId,
    required this.sku,
    required this.name,
    this.barcode,
    this.imageUrl,
    this.baseUnitName = 'cái',
    this.minStockLevel = 0,
    this.maxStockLevel,
    this.reorderPoint,
    this.averageCost = 0,
    this.isActive = true,
    this.units = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String sku;
  final String name;
  final String? barcode;
  final String? imageUrl;
  final String baseUnitName;
  final double minStockLevel;
  final double? maxStockLevel;
  final double? reorderPoint;
  final double averageCost;
  final bool isActive;
  final List<ProductUnit> units;
  final String? createdAt;
  final String? updatedAt;

  String get statusText => isActive ? 'Đang bán' : 'Ngừng bán';

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawUnits = json['units'];
    final units = <ProductUnit>[];
    if (rawUnits is List) {
      for (final item in rawUnits) {
        if (item is Map<String, dynamic>) {
          units.add(ProductUnit.fromJson(item));
        } else if (item is Map) {
          units.add(ProductUnit.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return Product(
      id: (json['id'] ?? '').toString(),
      tenantId: (json['tenantId'] ?? '').toString(),
      sku: (json['sku'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      barcode: json['barcode']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      baseUnitName: (json['baseUnitName'] ?? 'cái').toString(),
      minStockLevel: parseFlexibleDouble(json['minStockLevel']) ?? 0,
      maxStockLevel: parseFlexibleDouble(json['maxStockLevel']),
      reorderPoint: parseFlexibleDouble(json['reorderPoint']),
      averageCost: parseFlexibleDouble(json['averageCost']) ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      units: units,
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenantId': tenantId,
        'sku': sku,
        'name': name,
        if (barcode != null) 'barcode': barcode,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'baseUnitName': baseUnitName,
        'minStockLevel': minStockLevel,
        if (maxStockLevel != null) 'maxStockLevel': maxStockLevel,
        if (reorderPoint != null) 'reorderPoint': reorderPoint,
        'averageCost': averageCost,
        'isActive': isActive,
        'units': units.map((u) => u.toJson()).toList(),
        if (createdAt != null) 'createdAt': createdAt,
        if (updatedAt != null) 'updatedAt': updatedAt,
      };
}

/// Thông tin kho gọn (id/code/name) dùng trong response availability.
class ProductWarehouseRef {
  const ProductWarehouseRef({this.id, this.code, this.name});

  final String? id;
  final String? code;
  final String? name;

  factory ProductWarehouseRef.fromJson(dynamic json) {
    if (json is! Map) return const ProductWarehouseRef();
    return ProductWarehouseRef(
      id: json['id']?.toString(),
      code: json['code']?.toString(),
      name: json['name']?.toString(),
    );
  }
}

class ProductLot {
  const ProductLot({
    required this.warehouseId,
    this.warehouse,
    this.batchId,
    this.batchNo,
    this.expiryDate,
    this.onhandQty = 0,
    this.reservedQty = 0,
    this.availableQty = 0,
  });

  final String warehouseId;
  final ProductWarehouseRef? warehouse;
  final String? batchId;
  final String? batchNo;
  final String? expiryDate;
  final double onhandQty;
  final double reservedQty;
  final double availableQty;

  factory ProductLot.fromJson(Map<String, dynamic> json) {
    return ProductLot(
      warehouseId: (json['warehouseId'] ?? '').toString(),
      warehouse: ProductWarehouseRef.fromJson(json['warehouse']),
      batchId: json['batchId']?.toString(),
      batchNo: json['batchNo']?.toString(),
      expiryDate: json['expiryDate']?.toString(),
      onhandQty: parseFlexibleDouble(json['onhandQty']) ?? 0,
      reservedQty: parseFlexibleDouble(json['reservedQty']) ?? 0,
      availableQty: parseFlexibleDouble(json['availableQty']) ?? 0,
    );
  }
}

class ProductWarehouseStock {
  const ProductWarehouseStock({
    required this.warehouseId,
    this.warehouse,
    this.onhandQty = 0,
    this.reservedQty = 0,
    this.availableQty = 0,
    this.lots = const [],
  });

  final String warehouseId;
  final ProductWarehouseRef? warehouse;
  final double onhandQty;
  final double reservedQty;
  final double availableQty;
  final List<ProductLot> lots;

  String get warehouseName => warehouse?.name ?? warehouseId;

  factory ProductWarehouseStock.fromJson(Map<String, dynamic> json) {
    final rawLots = json['lots'];
    final lots = <ProductLot>[];
    if (rawLots is List) {
      for (final item in rawLots) {
        if (item is Map<String, dynamic>) {
          lots.add(ProductLot.fromJson(item));
        } else if (item is Map) {
          lots.add(ProductLot.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return ProductWarehouseStock(
      warehouseId: (json['warehouseId'] ?? '').toString(),
      warehouse: ProductWarehouseRef.fromJson(json['warehouse']),
      onhandQty: parseFlexibleDouble(json['onhandQty']) ?? 0,
      reservedQty: parseFlexibleDouble(json['reservedQty']) ?? 0,
      availableQty: parseFlexibleDouble(json['availableQty']) ?? 0,
      lots: lots,
    );
  }
}

class ProductAvailability {
  const ProductAvailability({
    required this.productId,
    this.warehouses = const [],
  });

  final String productId;
  final List<ProductWarehouseStock> warehouses;

  double get totalOnhand =>
      warehouses.fold(0, (sum, w) => sum + w.onhandQty);
  double get totalReserved =>
      warehouses.fold(0, (sum, w) => sum + w.reservedQty);
  double get totalAvailable =>
      warehouses.fold(0, (sum, w) => sum + w.availableQty);

  factory ProductAvailability.fromJson(Map<String, dynamic> json) {
    final raw = json['warehouses'];
    final warehouses = <ProductWarehouseStock>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          warehouses.add(ProductWarehouseStock.fromJson(item));
        } else if (item is Map) {
          warehouses.add(
            ProductWarehouseStock.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return ProductAvailability(
      productId: (json['productId'] ?? '').toString(),
      warehouses: warehouses,
    );
  }
}
