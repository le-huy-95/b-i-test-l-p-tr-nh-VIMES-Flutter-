class StockIssueLineForm {
  StockIssueLineForm({
    this.productId = '',
    this.unitName = '',
    this.requestedQty = '',
    this.actualQty = '',
    this.unitPrice = '',
    this.batchId,
  });

  String productId;
  String unitName;
  String requestedQty;
  String actualQty;
  String unitPrice;
  String? batchId;
}

class StockReceiptLineForm {
  StockReceiptLineForm({
    this.productId = '',
    this.unitName = '',
    this.expectedQty = '',
    this.actualQty = '',
    this.unitPrice = '',
    this.batchNo = '',
    this.expiryDate = '',
    this.manufactureDate = '',
  });

  String productId;
  String unitName;
  String expectedQty;
  String actualQty;
  String unitPrice;
  String batchNo;
  String expiryDate;
  String manufactureDate;
}

class StockIssueDocumentData {
  const StockIssueDocumentData({
    required this.id,
    required this.code,
    required this.status,
    required this.warehouseId,
    required this.issueType,
    required this.issueDate,
    required this.lines,
    this.customerId,
    this.note,
  });

  final String id;
  final String code;
  final String status;
  final String warehouseId;
  final String issueType;
  final DateTime issueDate;
  final String? customerId;
  final String? note;
  final List<StockIssueLineData> lines;

  factory StockIssueDocumentData.fromJson(Map<String, dynamic> json) {
    final rawLines = json['details'];
    return StockIssueDocumentData(
      id: '${json['id'] ?? ''}',
      code: '${json['code'] ?? ''}',
      status: '${json['status'] ?? 'draft'}',
      warehouseId: '${json['warehouseId'] ?? ''}',
      issueType: '${json['issueType'] ?? 'sale'}',
      issueDate: DateTime.tryParse('${json['issueDate'] ?? ''}') ?? DateTime.now(),
      customerId: json['customerId']?.toString(),
      note: json['note']?.toString(),
      lines: rawLines is List
          ? rawLines.whereType<Map>().map((e) => StockIssueLineData.fromJson(Map<String, dynamic>.from(e))).toList()
          : const [],
    );
  }
}

class StockIssueLineData {
  const StockIssueLineData({
    required this.productId,
    required this.unitName,
    required this.requestedQty,
    required this.actualQty,
    required this.unitPrice,
    this.batchId,
  });

  final String productId;
  final String unitName;
  final double requestedQty;
  final double actualQty;
  final double unitPrice;
  final String? batchId;

  factory StockIssueLineData.fromJson(Map<String, dynamic> json) => StockIssueLineData(
        productId: '${json['productId'] ?? ''}',
        unitName: '${json['unitName'] ?? ''}',
        requestedQty: _toDouble(json['requestedQty']),
        actualQty: _toDouble(json['actualQty']),
        unitPrice: _toDouble(json['unitPrice']),
        batchId: json['batchId']?.toString(),
      );
}

class StockReceiptDocumentData {
  const StockReceiptDocumentData({
    required this.id,
    required this.code,
    required this.status,
    required this.warehouseId,
    required this.receiptType,
    required this.receiptDate,
    required this.lines,
    this.supplierId,
    this.deliveredByName,
    this.note,
  });

  final String id;
  final String code;
  final String status;
  final String warehouseId;
  final String receiptType;
  final DateTime receiptDate;
  final String? supplierId;
  final String? deliveredByName;
  final String? note;
  final List<StockReceiptLineData> lines;

  factory StockReceiptDocumentData.fromJson(Map<String, dynamic> json) {
    final rawLines = json['details'];
    return StockReceiptDocumentData(
      id: '${json['id'] ?? ''}',
      code: '${json['code'] ?? ''}',
      status: '${json['status'] ?? 'draft'}',
      warehouseId: '${json['warehouseId'] ?? ''}',
      receiptType: '${json['receiptType'] ?? 'purchase'}',
      receiptDate: DateTime.tryParse('${json['receiptDate'] ?? ''}') ?? DateTime.now(),
      supplierId: json['supplierId']?.toString(),
      deliveredByName: json['deliveredByName']?.toString(),
      note: json['note']?.toString(),
      lines: rawLines is List
          ? rawLines.whereType<Map>().map((e) => StockReceiptLineData.fromJson(Map<String, dynamic>.from(e))).toList()
          : const [],
    );
  }
}

class StockReceiptLineData {
  const StockReceiptLineData({
    required this.productId,
    required this.unitName,
    required this.expectedQty,
    required this.actualQty,
    required this.unitPrice,
    this.batchNo,
    this.expiryDate,
    this.manufactureDate,
  });

  final String productId;
  final String unitName;
  final double expectedQty;
  final double actualQty;
  final double unitPrice;
  final String? batchNo;
  final DateTime? expiryDate;
  final DateTime? manufactureDate;

  factory StockReceiptLineData.fromJson(Map<String, dynamic> json) => StockReceiptLineData(
        productId: '${json['productId'] ?? ''}',
        unitName: '${json['unitName'] ?? ''}',
        expectedQty: _toDouble(json['expectedQty']),
        actualQty: _toDouble(json['actualQty']),
        unitPrice: _toDouble(json['unitPrice']),
        batchNo: json['batchNo']?.toString(),
        expiryDate: _parseDate(json['expiryDate']),
        manufactureDate: _parseDate(json['manufactureDate']),
      );
}

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  final text = value.toString();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}
