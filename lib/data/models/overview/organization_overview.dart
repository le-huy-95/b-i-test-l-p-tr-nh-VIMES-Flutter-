int parseFlexibleInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is! List) return const [];
  return value.map(_asMap).toList();
}

class OverviewNamedRef {
  const OverviewNamedRef({
    required this.id,
    required this.code,
    required this.name,
  });

  final String id;
  final String code;
  final String name;

  factory OverviewNamedRef.fromJson(Map<String, dynamic> json) {
    return OverviewNamedRef(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
    );
  }

  static OverviewNamedRef? tryParse(dynamic value) {
    if (value == null) return null;
    final map = _asMap(value);
    if (map.isEmpty) return null;
    return OverviewNamedRef.fromJson(map);
  }
}

class OverviewFilters {
  const OverviewFilters({
    this.from,
    this.to,
    this.expiryDays = 30,
    this.topLimit = 5,
    this.recentLimit = 5,
  });

  final String? from;
  final String? to;
  final int expiryDays;
  final int topLimit;
  final int recentLimit;

  factory OverviewFilters.fromJson(Map<String, dynamic> json) {
    return OverviewFilters(
      from: json['from']?.toString(),
      to: json['to']?.toString(),
      expiryDays: parseFlexibleInt(json['expiryDays'] ?? 30),
      topLimit: parseFlexibleInt(json['topLimit'] ?? 5),
      recentLimit: parseFlexibleInt(json['recentLimit'] ?? 5),
    );
  }
}

class OverviewOrganization {
  const OverviewOrganization({
    required this.warehouseCount,
    required this.warehouses,
  });

  final int warehouseCount;
  final List<OverviewNamedRef> warehouses;

  factory OverviewOrganization.fromJson(Map<String, dynamic> json) {
    return OverviewOrganization(
      warehouseCount: parseFlexibleInt(json['warehouseCount']),
      warehouses: _asMapList(
        json['warehouses'],
      ).map(OverviewNamedRef.fromJson).toList(),
    );
  }
}

class DocStatusStats {
  const DocStatusStats({
    required this.byStatus,
    required this.total,
    required this.pendingApproval,
    required this.draft,
    required this.completed,
  });

  final Map<String, int> byStatus;
  final int total;
  final int pendingApproval;
  final int draft;
  final int completed;

  factory DocStatusStats.fromJson(Map<String, dynamic> json) {
    final raw = json['byStatus'];
    final byStatus = <String, int>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        byStatus[entry.key.toString()] = parseFlexibleInt(entry.value);
      }
    }
    return DocStatusStats(
      byStatus: byStatus,
      total: parseFlexibleInt(json['total']),
      pendingApproval: parseFlexibleInt(json['pendingApproval']),
      draft: parseFlexibleInt(json['draft']),
      completed: parseFlexibleInt(json['completed']),
    );
  }
}

class PendingReceipt {
  const PendingReceipt({
    required this.id,
    required this.code,
    this.receiptDate,
    this.receiptType,
    this.totalAmount,
    this.status,
    this.createdAt,
    this.warehouse,
    this.supplier,
    this.createdById,
  });

  final String id;
  final String code;
  final String? receiptDate;
  final String? receiptType;
  final String? totalAmount;
  final String? status;
  final String? createdAt;
  final OverviewNamedRef? warehouse;
  final OverviewNamedRef? supplier;
  final String? createdById;

  factory PendingReceipt.fromJson(Map<String, dynamic> json) {
    return PendingReceipt(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      receiptDate: json['receiptDate']?.toString(),
      receiptType: json['receiptType']?.toString(),
      totalAmount: json['totalAmount']?.toString(),
      status: json['status']?.toString(),
      createdAt: json['createdAt']?.toString(),
      warehouse: OverviewNamedRef.tryParse(json['warehouse']),
      supplier: OverviewNamedRef.tryParse(json['supplier']),
      createdById: json['createdById']?.toString(),
    );
  }
}

class PendingIssue {
  const PendingIssue({
    required this.id,
    required this.code,
    this.issueDate,
    this.issueType,
    this.status,
    this.createdAt,
    this.warehouse,
    this.customer,
    this.createdById,
  });

  final String id;
  final String code;
  final String? issueDate;
  final String? issueType;
  final String? status;
  final String? createdAt;
  final OverviewNamedRef? warehouse;
  final OverviewNamedRef? customer;
  final String? createdById;

  factory PendingIssue.fromJson(Map<String, dynamic> json) {
    return PendingIssue(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      issueDate: json['issueDate']?.toString(),
      issueType: json['issueType']?.toString(),
      status: json['status']?.toString(),
      createdAt: json['createdAt']?.toString(),
      warehouse: OverviewNamedRef.tryParse(json['warehouse']),
      customer: OverviewNamedRef.tryParse(json['customer']),
      createdById: json['createdById']?.toString(),
    );
  }
}

class ReceiptDocumentStats extends DocStatusStats {
  const ReceiptDocumentStats({
    required super.byStatus,
    required super.total,
    required super.pendingApproval,
    required super.draft,
    required super.completed,
    required this.pendingApprovalList,
  });

  final List<PendingReceipt> pendingApprovalList;

  factory ReceiptDocumentStats.fromJson(Map<String, dynamic> json) {
    final base = DocStatusStats.fromJson(json);
    return ReceiptDocumentStats(
      byStatus: base.byStatus,
      total: base.total,
      pendingApproval: base.pendingApproval,
      draft: base.draft,
      completed: base.completed,
      pendingApprovalList: _asMapList(
        json['pendingApprovalList'],
      ).map(PendingReceipt.fromJson).toList(),
    );
  }
}

class IssueDocumentStats extends DocStatusStats {
  const IssueDocumentStats({
    required super.byStatus,
    required super.total,
    required super.pendingApproval,
    required super.draft,
    required super.completed,
    required this.pendingApprovalList,
  });

  final List<PendingIssue> pendingApprovalList;

  factory IssueDocumentStats.fromJson(Map<String, dynamic> json) {
    final base = DocStatusStats.fromJson(json);
    return IssueDocumentStats(
      byStatus: base.byStatus,
      total: base.total,
      pendingApproval: base.pendingApproval,
      draft: base.draft,
      completed: base.completed,
      pendingApprovalList: _asMapList(
        json['pendingApprovalList'],
      ).map(PendingIssue.fromJson).toList(),
    );
  }
}

class OverviewDocuments {
  const OverviewDocuments({
    required this.stockReceipts,
    required this.stockIssues,
    required this.stockOpenings,
  });

  final ReceiptDocumentStats stockReceipts;
  final IssueDocumentStats stockIssues;
  final DocStatusStats stockOpenings;

  factory OverviewDocuments.fromJson(Map<String, dynamic> json) {
    return OverviewDocuments(
      stockReceipts: ReceiptDocumentStats.fromJson(
        _asMap(json['stockReceipts']),
      ),
      stockIssues: IssueDocumentStats.fromJson(_asMap(json['stockIssues'])),
      stockOpenings: DocStatusStats.fromJson(_asMap(json['stockOpenings'])),
    );
  }
}

class TopProduct {
  const TopProduct({
    required this.productId,
    required this.sku,
    required this.name,
    required this.baseUnitName,
    required this.totalQty,
    required this.documentCount,
  });

  final String productId;
  final String sku;
  final String name;
  final String baseUnitName;
  final String totalQty;
  final int documentCount;

  factory TopProduct.fromJson(Map<String, dynamic> json) {
    return TopProduct(
      productId: (json['productId'] ?? '').toString(),
      sku: (json['sku'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      baseUnitName: (json['baseUnitName'] ?? '').toString(),
      totalQty: (json['totalQty'] ?? '0').toString(),
      documentCount: parseFlexibleInt(json['documentCount']),
    );
  }
}

class ProductMovement {
  ProductMovement({
    required this.totalImportedQty,
    required this.totalExportedQty,
    required this.topImportedProducts,
    required this.topExportedProducts,
    List<DailyMovementPoint>? dailyMovement,
  }) : dailyMovement = dailyMovement ?? const [];

  final String totalImportedQty;
  final String totalExportedQty;
  final List<TopProduct> topImportedProducts;
  final List<TopProduct> topExportedProducts;
  final List<DailyMovementPoint> dailyMovement;

  /// Safe access when API omits the field or after hot reload with stale state.
  List<DailyMovementPoint> get resolvedDailyMovement {
    try {
      return dailyMovement;
    } on TypeError {
      return const [];
    }
  }

  factory ProductMovement.fromJson(Map<String, dynamic> json) {
    final dailyRaw = json['dailyMovement'];
    final daily = dailyRaw == null
        ? const <DailyMovementPoint>[]
        : _asMapList(dailyRaw).map(DailyMovementPoint.fromJson).toList();

    return ProductMovement(
      totalImportedQty: (json['totalImportedQty'] ?? '0').toString(),
      totalExportedQty: (json['totalExportedQty'] ?? '0').toString(),
      topImportedProducts: _asMapList(
        json['topImportedProducts'],
      ).map(TopProduct.fromJson).toList(),
      topExportedProducts: _asMapList(
        json['topExportedProducts'],
      ).map(TopProduct.fromJson).toList(),
      dailyMovement: daily,
    );
  }
}

class DailyMovementPoint {
  const DailyMovementPoint({
    required this.date,
    required this.importedQty,
    required this.exportedQty,
  });

  final String date;
  final String importedQty;
  final String exportedQty;

  factory DailyMovementPoint.fromJson(Map<String, dynamic> json) {
    return DailyMovementPoint(
      date: (json['date'] ?? '').toString(),
      importedQty: (json['importedQty'] ?? '0').toString(),
      exportedQty: (json['exportedQty'] ?? '0').toString(),
    );
  }
}

class InventoryOverview {
  const InventoryOverview({
    required this.skuCount,
    required this.totalOnhandQty,
    required this.totalReservedQty,
    required this.totalAvailableQty,
    required this.estimatedStockValue,
    required this.lowStockCount,
    required this.expiryAlertCount,
    required this.activeReservationCount,
  });

  final int skuCount;
  final String totalOnhandQty;
  final String totalReservedQty;
  final String totalAvailableQty;
  final String estimatedStockValue;
  final int lowStockCount;
  final int expiryAlertCount;
  final int activeReservationCount;

  factory InventoryOverview.fromJson(Map<String, dynamic> json) {
    return InventoryOverview(
      skuCount: parseFlexibleInt(json['skuCount']),
      totalOnhandQty: (json['totalOnhandQty'] ?? '0').toString(),
      totalReservedQty: (json['totalReservedQty'] ?? '0').toString(),
      totalAvailableQty: (json['totalAvailableQty'] ?? '0').toString(),
      estimatedStockValue: (json['estimatedStockValue'] ?? '0').toString(),
      lowStockCount: parseFlexibleInt(json['lowStockCount']),
      expiryAlertCount: parseFlexibleInt(json['expiryAlertCount']),
      activeReservationCount: parseFlexibleInt(json['activeReservationCount']),
    );
  }
}

class WarehouseBreakdown {
  const WarehouseBreakdown({
    required this.warehouse,
    required this.productMovement,
    required this.stockReceipts,
    required this.stockIssues,
  });

  final OverviewNamedRef warehouse;
  final WarehouseMovement productMovement;
  final DocStatusStats stockReceipts;
  final DocStatusStats stockIssues;

  factory WarehouseBreakdown.fromJson(Map<String, dynamic> json) {
    return WarehouseBreakdown(
      warehouse: OverviewNamedRef.fromJson(_asMap(json['warehouse'])),
      productMovement: WarehouseMovement.fromJson(
        _asMap(json['productMovement']),
      ),
      stockReceipts: DocStatusStats.fromJson(_asMap(json['stockReceipts'])),
      stockIssues: DocStatusStats.fromJson(_asMap(json['stockIssues'])),
    );
  }
}

class WarehouseMovement {
  const WarehouseMovement({
    required this.totalImportedQty,
    required this.totalExportedQty,
  });

  final String totalImportedQty;
  final String totalExportedQty;

  factory WarehouseMovement.fromJson(Map<String, dynamic> json) {
    return WarehouseMovement(
      totalImportedQty: (json['totalImportedQty'] ?? '0').toString(),
      totalExportedQty: (json['totalExportedQty'] ?? '0').toString(),
    );
  }
}

enum PendingDocumentKind { receipt, issue }

class PendingDocument {
  const PendingDocument({
    required this.kind,
    required this.id,
    required this.code,
    required this.createdAt,
    this.date,
    this.type,
    this.totalAmount,
    this.warehouseName,
    this.partnerName,
  });

  final PendingDocumentKind kind;
  final String id;
  final String code;
  final String createdAt;
  final String? date;
  final String? type;
  final String? totalAmount;
  final String? warehouseName;
  final String? partnerName;

  factory PendingDocument.fromReceipt(PendingReceipt receipt) {
    return PendingDocument(
      kind: PendingDocumentKind.receipt,
      id: receipt.id,
      code: receipt.code,
      createdAt: receipt.createdAt ?? '',
      date: receipt.receiptDate,
      type: receipt.receiptType,
      totalAmount: receipt.totalAmount,
      warehouseName: receipt.warehouse?.name,
      partnerName: receipt.supplier?.name,
    );
  }

  factory PendingDocument.fromIssue(PendingIssue issue) {
    return PendingDocument(
      kind: PendingDocumentKind.issue,
      id: issue.id,
      code: issue.code,
      createdAt: issue.createdAt ?? '',
      date: issue.issueDate,
      type: issue.issueType,
      warehouseName: issue.warehouse?.name,
      partnerName: issue.customer?.name,
    );
  }
}

class OrganizationOverview {
  const OrganizationOverview({
    required this.generatedAt,
    required this.visibilityScope,
    required this.role,
    required this.filters,
    required this.organization,
    required this.documents,
    required this.productMovement,
    required this.warehousesBreakdown,
    this.inventory,
  });

  final String generatedAt;
  final String visibilityScope;
  final String role;
  final OverviewFilters filters;
  final OverviewOrganization organization;
  final OverviewDocuments documents;
  final ProductMovement productMovement;
  final InventoryOverview? inventory;
  final List<WarehouseBreakdown> warehousesBreakdown;

  bool get isOrganizationScope => visibilityScope == 'organization';

  bool get hasVisibleData {
    final inv = inventory;
    return inv != null ||
        documents.stockReceipts.total > 0 ||
        documents.stockIssues.total > 0 ||
        documents.stockOpenings.total > 0 ||
        productMovement.topImportedProducts.isNotEmpty ||
        productMovement.topExportedProducts.isNotEmpty ||
        productMovement.resolvedDailyMovement.isNotEmpty ||
        warehousesBreakdown.isNotEmpty;
  }

  int get alertCount {
    final inv = inventory;
    if (inv == null) return 0;
    return inv.lowStockCount + inv.expiryAlertCount;
  }

  int get pendingApprovalCount =>
      documents.stockReceipts.pendingApproval +
      documents.stockIssues.pendingApproval;

  List<PendingDocument> get pendingDocuments {
    final items = <PendingDocument>[
      ...documents.stockReceipts.pendingApprovalList.map(
        PendingDocument.fromReceipt,
      ),
      ...documents.stockIssues.pendingApprovalList.map(
        PendingDocument.fromIssue,
      ),
    ];
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  factory OrganizationOverview.fromJson(Map<String, dynamic> json) {
    final inventoryRaw = json['inventory'];
    return OrganizationOverview(
      generatedAt: (json['generatedAt'] ?? '').toString(),
      visibilityScope: (json['visibilityScope'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      filters: OverviewFilters.fromJson(_asMap(json['filters'])),
      organization: OverviewOrganization.fromJson(_asMap(json['organization'])),
      documents: OverviewDocuments.fromJson(_asMap(json['documents'])),
      productMovement: ProductMovement.fromJson(
        _asMap(json['productMovement']),
      ),
      inventory: inventoryRaw == null
          ? null
          : InventoryOverview.fromJson(_asMap(inventoryRaw)),
      warehousesBreakdown: _asMapList(
        json['warehousesBreakdown'],
      ).map(WarehouseBreakdown.fromJson).toList(),
    );
  }
}
