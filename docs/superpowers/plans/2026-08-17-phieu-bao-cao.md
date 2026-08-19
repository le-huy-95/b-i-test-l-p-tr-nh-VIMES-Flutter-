# Phase 3 — Phiếu + Báo cáo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Thay placeholder tab Phiếu / Báo cáo bằng luồng thật: phiếu nhập, phiếu xuất (full workflow), báo cáo tồn kho và xuất–nhập–tồn, gọi API `/api/v1` — không mock.

**Architecture:** Feature modules `stock_receipt` / `stock_issue` / `report` + partner picker mỏng; Bloc per screen → Repository → `*ApiService` (Dio + `AuthInterceptor`). RBAC ẩn nút theo role; backend vẫn nguồn đúng. List chỉ render header (không expand `details[]`).

**Tech Stack:** Flutter, flutter_bloc, equatable, go_router, dio

**Spec:** `docs/superpowers/specs/2026-08-17-phieu-bao-cao-design.md`

**Commit:** Workspace hiện **không có `.git`**. Bỏ qua mọi bước commit trừ khi user bật git và yêu cầu commit.

---

## File map

| Path | Responsibility |
|------|----------------|
| `lib/core/auth/tenant_permissions.dart` | Role helpers phiếu |
| `lib/core/auth/stock_doc_actions.dart` | Status × role → actions; label status/issueType |
| `lib/core/error/failure.dart` | `details` thành `Object?` để nhận list `STOCK_INSUFFICIENT` |
| `lib/data/datasources/api_services/base_api_service.dart` | Parse `error.code` + `error.details` |
| `lib/data/datasources/api_failure.dart` | `throwIfApiFailed` → `Failure` |
| `lib/data/datasources/api_endpoints.dart` | Paths mới |
| `lib/data/models/partner/supplier.dart` | Supplier picker |
| `lib/data/models/partner/customer.dart` | Customer picker |
| `lib/data/models/stock_receipt/stock_receipt.dart` | Receipt + line + create payload |
| `lib/data/models/stock_issue/stock_issue.dart` | Issue + line + IssueType + create payload |
| `lib/data/models/report/stock_balance_row.dart` | Tồn kho row |
| `lib/data/models/report/stock_movement_row.dart` | Movement row |
| `lib/data/datasources/api_services/partner_api_service.dart` | GET suppliers/customers |
| `lib/data/datasources/api_services/stock_receipt_api_service.dart` | Receipt HTTP |
| `lib/data/datasources/api_services/stock_issue_api_service.dart` | Issue HTTP |
| `lib/data/datasources/api_services/report_api_service.dart` | Reports HTTP |
| `lib/domain/repositories/partner_repository.dart` | Interface |
| `lib/domain/repositories/stock_receipt_repository.dart` | Interface |
| `lib/domain/repositories/stock_issue_repository.dart` | Interface |
| `lib/domain/repositories/report_repository.dart` | Interface |
| `lib/data/repositories/*_impl.dart` | Thin wrap |
| `lib/features/stock_common/widgets/stock_status_chip.dart` | Chip status |
| `lib/features/stock_common/widgets/stock_hub_tile.dart` | Card hub |
| `lib/features/stock_common/current_tenant_role.dart` | Đọc role từ AuthBloc |
| `lib/features/stock_receipt/{bloc,pages}` | List / form / detail nhập |
| `lib/features/stock_issue/{bloc,pages}` | List / form / detail xuất |
| `lib/features/report/{bloc,pages}` | Hub + 2 báo cáo |
| `lib/app/app.dart` | DI |
| `lib/app/router/app_router.dart` | Routes + `_needsTenant` |
| `lib/features/home/pages/home_page.dart` | Hubs + quick actions |
| `test/core/auth/tenant_permissions_test.dart` | RBAC + actions |
| `test/data/models/stock_models_test.dart` | Parse JSON |

---

### Task 1: RBAC, status actions, Failure/API error code

**Files:**
- Modify: `lib/core/auth/tenant_permissions.dart`
- Create: `lib/core/auth/stock_doc_actions.dart`
- Modify: `lib/core/error/failure.dart`
- Modify: `lib/data/datasources/api_services/base_api_service.dart`
- Create: `lib/data/datasources/api_failure.dart`
- Modify: `test/core/auth/tenant_permissions_test.dart`
- Create: `test/core/error/failure_test.dart`

- [ ] **Step 1: Write failing tests**

Thêm vào `test/core/auth/tenant_permissions_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:test_y_app/core/auth/stock_doc_actions.dart';
import 'package:test_y_app/core/auth/tenant_permissions.dart';

void main() {
  group('canManageMasterData', () {
    test('admin can manage', () {
      expect(canManageMasterData('admin'), isTrue);
    });

    test('non-admin cannot manage', () {
      expect(canManageMasterData('warehouse_keeper'), isFalse);
      expect(canManageMasterData('accountant'), isFalse);
      expect(canManageMasterData('approver'), isFalse);
      expect(canManageMasterData('viewer'), isFalse);
    });
  });

  group('stock doc RBAC', () {
    test('keeper can create/submit/cancel, cannot approve', () {
      expect(canCreateOrSubmitStockDoc('warehouse_keeper'), isTrue);
      expect(canCancelStockDoc('warehouse_keeper'), isTrue);
      expect(canApproveOrCompleteStockDoc('warehouse_keeper'), isFalse);
    });

    test('accountant can approve, cannot create', () {
      expect(canApproveOrCompleteStockDoc('accountant'), isTrue);
      expect(canApproveOrCompleteStockDoc('approver'), isTrue);
      expect(canCreateOrSubmitStockDoc('accountant'), isFalse);
      expect(canCancelStockDoc('accountant'), isFalse);
    });

    test('viewer cannot write', () {
      expect(canCreateOrSubmitStockDoc('viewer'), isFalse);
      expect(canApproveOrCompleteStockDoc('viewer'), isFalse);
      expect(canCancelStockDoc('viewer'), isFalse);
    });
  });

  group('visibleReceiptActions', () {
    test('draft + keeper → submit, cancel', () {
      expect(
        visibleReceiptActions(status: 'draft', role: 'warehouse_keeper'),
        [StockDocAction.submit, StockDocAction.cancel],
      );
    });

    test('pending_approval + approver → approve, reject', () {
      expect(
        visibleReceiptActions(status: 'pending_approval', role: 'approver'),
        [StockDocAction.approve, StockDocAction.reject],
      );
    });

    test('pending_approval + keeper → cancel only', () {
      expect(
        visibleReceiptActions(status: 'pending_approval', role: 'warehouse_keeper'),
        [StockDocAction.cancel],
      );
    });

    test('approved + accountant → complete', () {
      expect(
        visibleReceiptActions(status: 'approved', role: 'accountant'),
        [StockDocAction.complete],
      );
    });

    test('rejected + keeper → clone', () {
      expect(
        visibleReceiptActions(status: 'rejected', role: 'warehouse_keeper'),
        [StockDocAction.clone],
      );
    });

    test('completed + admin → empty', () {
      expect(visibleReceiptActions(status: 'completed', role: 'admin'), isEmpty);
    });
  });

  group('visibleIssueActions', () {
    test('rejected has no clone', () {
      expect(
        visibleIssueActions(status: 'rejected', role: 'warehouse_keeper'),
        isEmpty,
      );
    });
  });
}
```

Tạo `test/core/error/failure_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:test_y_app/core/error/failure.dart';
import 'package:test_y_app/data/datasources/api_services/base_api_service.dart';

void main() {
  test('ApiResponse parses error.code and details list', () {
    final response = ApiResponse<void>.fromJson({
      'success': false,
      'error': {
        'code': 'STOCK_INSUFFICIENT',
        'message': 'Không đủ tồn kho',
        'details': [
          {'productId': 'p1', 'requested': '10', 'available': '2'},
        ],
      },
    });

    expect(response.success, isFalse);
    expect(response.errorCode, 'STOCK_INSUFFICIENT');
    expect(response.error, 'Không đủ tồn kho');
    expect(response.errorDetails, isA<List>());
  });

  test('Failure keeps list details', () {
    final failure = Failure(
      message: 'Không đủ tồn kho',
      code: 'STOCK_INSUFFICIENT',
      details: [
        {'productId': 'p1', 'requested': 10, 'available': 2},
      ],
    );
    expect(failure.code, 'STOCK_INSUFFICIENT');
    expect(failure.details, isA<List>());
  });
}
```

- [ ] **Step 2: Run tests — expect FAIL**

```bash
flutter test test/core/auth/tenant_permissions_test.dart test/core/error/failure_test.dart
```

Expected: compile/runtime fail (`canCreateOrSubmitStockDoc` / `errorCode` undefined).

- [ ] **Step 3: Implement permissions**

`lib/core/auth/tenant_permissions.dart`:

```dart
/// Tenant RBAC helpers for master-data screens (warehouse / product).
bool canManageMasterData(String role) => role == 'admin';

bool canCreateOrSubmitStockDoc(String role) =>
    role == 'admin' || role == 'warehouse_keeper';

bool canApproveOrCompleteStockDoc(String role) =>
    role == 'admin' || role == 'accountant' || role == 'approver';

bool canCancelStockDoc(String role) =>
    role == 'admin' || role == 'warehouse_keeper';
```

- [ ] **Step 4: Implement stock doc actions**

`lib/core/auth/stock_doc_actions.dart`:

```dart
import 'package:test_y_app/core/auth/tenant_permissions.dart';

enum StockDocAction { submit, approve, reject, complete, cancel, clone }

String stockDocStatusLabel(String status) {
  return switch (status) {
    'draft' => 'Nháp',
    'pending_approval' => 'Chờ duyệt',
    'approved' => 'Đã duyệt',
    'rejected' => 'Từ chối',
    'completed' => 'Hoàn tất',
    'cancelled' => 'Đã hủy',
    _ => status,
  };
}

String issueTypeLabel(String type) {
  return switch (type) {
    'sale' => 'Xuất bán',
    'internal_use' => 'Nội bộ',
    'return_to_supplier' => 'Trả NCC',
    'disposal' => 'Tiêu hủy',
    _ => type,
  };
}

List<StockDocAction> visibleReceiptActions({
  required String status,
  required String role,
}) {
  return _visible(status: status, role: role, includeClone: true);
}

List<StockDocAction> visibleIssueActions({
  required String status,
  required String role,
}) {
  return _visible(status: status, role: role, includeClone: false);
}

List<StockDocAction> _visible({
  required String status,
  required String role,
  required bool includeClone,
}) {
  final actions = <StockDocAction>[];
  switch (status) {
    case 'draft':
      if (canCreateOrSubmitStockDoc(role)) actions.add(StockDocAction.submit);
      if (canCancelStockDoc(role)) actions.add(StockDocAction.cancel);
    case 'pending_approval':
      if (canApproveOrCompleteStockDoc(role)) {
        actions.add(StockDocAction.approve);
        actions.add(StockDocAction.reject);
      }
      if (canCancelStockDoc(role)) actions.add(StockDocAction.cancel);
    case 'approved':
      if (canApproveOrCompleteStockDoc(role)) {
        actions.add(StockDocAction.complete);
      }
      if (canCancelStockDoc(role)) actions.add(StockDocAction.cancel);
    case 'rejected':
      if (includeClone && canCreateOrSubmitStockDoc(role)) {
        actions.add(StockDocAction.clone);
      }
    default:
      break;
  }
  return actions;
}
```

- [ ] **Step 5: Extend Failure + ApiResponse**

`lib/core/error/failure.dart` — đổi `details` thành `Object?`:

```dart
/// Standard Failure object to propagate API errors.
class Failure implements Exception {
  Failure({required this.message, this.code, this.details});

  final String message;
  final String? code;
  final Object? details;

  @override
  String toString() => code != null ? '[$code] $message' : message;
}
```

Trong `lib/data/datasources/api_services/base_api_service.dart`:

1. Thêm field vào `ApiResponse`:

```dart
  final String? errorCode;
  final Object? errorDetails;
```

Thêm vào constructor và `fromJson`.

2. Thay `_extractErrorMessage` + parse code:

```dart
class _ApiErrorParts {
  const _ApiErrorParts({this.message, this.code, this.details});
  final String? message;
  final String? code;
  final Object? details;
}

_ApiErrorParts _extractErrorParts(dynamic error) {
  if (error == null) return const _ApiErrorParts();
  if (error is Map) {
    return _ApiErrorParts(
      message: error['message']?.toString(),
      code: error['code']?.toString(),
      details: error['details'],
    );
  }
  final text = error.toString();
  return _ApiErrorParts(message: text.isEmpty ? null : text);
}
```

Trong `fromJson`:

```dart
    final parts = _extractErrorParts(json['error']);
    return ApiResponse<T>(
      success: json['success'] is bool ? json['success'] as bool : true,
      data: decodedData,
      message: json['message']?.toString(),
      error: parts.message,
      errorCode: parts.code,
      errorDetails: parts.details,
      errors: parsedErrors,
    );
```

Trong `_handleDioException`, khi `body is Map`:

```dart
    String? errorMessage;
    String? errorCode;
    Object? errorDetails;
    if (body is Map<String, dynamic>) {
      final parts = _extractErrorParts(body['error']);
      errorMessage = body['message']?.toString() ?? parts.message;
      errorCode = parts.code;
      errorDetails = parts.details;
    }
    // ... existing timeout fallbacks ...
    return ApiResponse<T>(
      success: false,
      error: displayMessage,
      errorCode: errorCode,
      errorDetails: errorDetails,
      statusCode: statusCode,
    );
```

Giữ `_extractErrorMessage` nếu còn chỗ gọi, hoặc chuyển hết sang `_extractErrorParts`.

- [ ] **Step 6: Add `throwIfApiFailed`**

`lib/data/datasources/api_failure.dart`:

```dart
import 'package:test_y_app/core/error/failure.dart';
import 'package:test_y_app/data/datasources/api_services/base_api_service.dart';

Never throwIfApiFailed(ApiResponse<dynamic> response, String fallback) {
  final message = (response.error != null &&
          response.error!.isNotEmpty &&
          !response.error!.startsWith('{'))
      ? response.error!
      : (response.message?.isNotEmpty == true ? response.message! : fallback);
  throw Failure(
    message: message,
    code: response.errorCode,
    details: response.errorDetails,
  );
}
```

- [ ] **Step 7: Run tests — expect PASS**

```bash
flutter test test/core/auth/tenant_permissions_test.dart test/core/error/failure_test.dart
```

Expected: All tests passed.

- [ ] **Step 8: Commit** — skip unless user requested and git exists.

---

### Task 2: Endpoints + partner picker (API + repo + DI)

**Files:**
- Modify: `lib/data/datasources/api_endpoints.dart`
- Create: `lib/data/models/partner/supplier.dart`
- Create: `lib/data/models/partner/customer.dart`
- Create: `lib/data/datasources/api_services/partner_api_service.dart`
- Create: `lib/domain/repositories/partner_repository.dart`
- Create: `lib/data/repositories/partner_repository_impl.dart`
- Modify: `lib/app/app.dart`

- [ ] **Step 1: Extend ApiEndpoints** — thêm vào cuối class:

```dart
  static const String suppliers = '$baseApi/suppliers';
  static const String customers = '$baseApi/customers';

  static const String stockReceipts = '$baseApi/stock-receipts';
  static String stockReceipt(String id) => '$stockReceipts/$id';
  static String stockReceiptSubmit(String id) => '${stockReceipt(id)}/submit';
  static String stockReceiptApprove(String id) => '${stockReceipt(id)}/approve';
  static String stockReceiptReject(String id) => '${stockReceipt(id)}/reject';
  static String stockReceiptComplete(String id) => '${stockReceipt(id)}/complete';
  static String stockReceiptCancel(String id) => '${stockReceipt(id)}/cancel';
  static String stockReceiptClone(String id) =>
      '${stockReceipt(id)}/clone-from-rejected';

  static const String stockIssues = '$baseApi/stock-issues';
  static String stockIssue(String id) => '$stockIssues/$id';
  static String stockIssueSubmit(String id) => '${stockIssue(id)}/submit';
  static String stockIssueApprove(String id) => '${stockIssue(id)}/approve';
  static String stockIssueReject(String id) => '${stockIssue(id)}/reject';
  static String stockIssueComplete(String id) => '${stockIssue(id)}/complete';
  static String stockIssueCancel(String id) => '${stockIssue(id)}/cancel';

  static const String reportStockBalance = '$baseApi/reports/stock-balance';
  static const String reportStockMovement = '$baseApi/reports/stock-movement';
```

- [ ] **Step 2: Partner models**

`lib/data/models/partner/supplier.dart`:

```dart
class Supplier {
  const Supplier({
    required this.id,
    required this.tenantId,
    required this.code,
    required this.name,
    this.taxCode,
    this.contact,
    this.isActive = true,
  });

  final String id;
  final String tenantId;
  final String code;
  final String name;
  final String? taxCode;
  final String? contact;
  final bool isActive;

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: (json['id'] ?? '').toString(),
      tenantId: (json['tenantId'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      taxCode: json['taxCode']?.toString(),
      contact: json['contact']?.toString(),
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
```

`lib/data/models/partner/customer.dart`:

```dart
class Customer {
  const Customer({
    required this.id,
    required this.tenantId,
    required this.code,
    required this.name,
    this.phone,
    this.email,
    this.isActive = true,
  });

  final String id;
  final String tenantId;
  final String code;
  final String name;
  final String? phone;
  final String? email;
  final bool isActive;

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: (json['id'] ?? '').toString(),
      tenantId: (json['tenantId'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
```

- [ ] **Step 3: PartnerApiService + repository**

Copy decode list pattern từ `WarehouseApiService`. Dùng `throwIfApiFailed`.

```dart
class PartnerApiService extends BaseApiService {
  List<Supplier> _decodeSuppliers(dynamic value) { /* List → Supplier.fromJson */ }
  List<Customer> _decodeCustomers(dynamic value) { /* List → Customer.fromJson */ }

  Future<List<Supplier>> listSuppliers() async {
    final response = await getRequest<List<Supplier>>(
      ApiEndpoints.suppliers,
      decode: _decodeSuppliers,
    );
    if (!response.success || response.data == null) {
      throwIfApiFailed(response, 'Không tải được nhà cung cấp');
    }
    return response.data!;
  }

  Future<List<Customer>> listCustomers() async {
    final response = await getRequest<List<Customer>>(
      ApiEndpoints.customers,
      decode: _decodeCustomers,
    );
    if (!response.success || response.data == null) {
      throwIfApiFailed(response, 'Không tải được khách hàng');
    }
    return response.data!;
  }
}
```

Interface:

```dart
abstract class PartnerRepository {
  Future<List<Supplier>> listSuppliers();
  Future<List<Customer>> listCustomers();
}
```

Impl thin-wrap `PartnerApiService`.

- [ ] **Step 4: Register DI in `lib/app/app.dart`**

Thêm field `_partnerRepository`, init `PartnerRepositoryImpl()`, và:

```dart
RepositoryProvider<PartnerRepository>.value(value: _partnerRepository),
```

---

### Task 3: Stock receipt models + parse tests

**Files:**
- Create: `lib/data/models/stock_receipt/stock_receipt.dart`
- Create: `test/data/models/stock_models_test.dart`

- [ ] **Step 1: Write failing parse test** trong `test/data/models/stock_models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:test_y_app/data/models/stock_receipt/stock_receipt.dart';

void main() {
  test('StockReceipt.fromJson parses decimals, nested warehouse/supplier, details', () {
    final receipt = StockReceipt.fromJson({
      'id': 'r1',
      'tenantId': 't1',
      'code': 'PN-2026-0001',
      'receiptDate': '2026-08-17',
      'warehouseId': 'w1',
      'supplierId': 's1',
      'status': 'draft',
      'totalAmount': '150000.00',
      'note': 'nhập',
      'warehouse': {'id': 'w1', 'code': 'WH01', 'name': 'Kho chính'},
      'supplier': {'id': 's1', 'code': 'NCC01', 'name': 'ABC'},
      'details': [
        {
          'id': 'd1',
          'receiptId': 'r1',
          'productId': 'p1',
          'unitName': 'cái',
          'expectedQty': '10.0000',
          'actualQty': '10.0000',
          'qtyBaseUnit': '10.0000',
          'unitPrice': '15000.0000',
          'lineAmount': '150000.00',
          'product': {'id': 'p1', 'sku': 'SP001', 'name': 'Sản phẩm A'},
        },
      ],
    });

    expect(receipt.code, 'PN-2026-0001');
    expect(receipt.totalAmount, 150000);
    expect(receipt.warehouseName, 'Kho chính');
    expect(receipt.supplierName, 'ABC');
    expect(receipt.details, hasLength(1));
    expect(receipt.details.first.actualQty, 10);
    expect(receipt.details.first.productName, 'Sản phẩm A');
  });
}
```

- [ ] **Step 2: Run test — expect FAIL** (`stock_receipt.dart` missing)

```bash
flutter test test/data/models/stock_models_test.dart
```

- [ ] **Step 3: Implement model**

`lib/data/models/stock_receipt/stock_receipt.dart`:

```dart
import 'package:test_y_app/data/models/warehouse/warehouse.dart';

class StockReceiptDetail {
  const StockReceiptDetail({
    required this.id,
    required this.receiptId,
    required this.productId,
    required this.unitName,
    required this.expectedQty,
    required this.actualQty,
    required this.qtyBaseUnit,
    required this.unitPrice,
    required this.lineAmount,
    this.batchNo,
    this.expiryDate,
    this.productSku,
    this.productName,
  });

  final String id;
  final String receiptId;
  final String productId;
  final String unitName;
  final double expectedQty;
  final double actualQty;
  final double qtyBaseUnit;
  final double unitPrice;
  final double lineAmount;
  final String? batchNo;
  final String? expiryDate;
  final String? productSku;
  final String? productName;

  factory StockReceiptDetail.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? product;
    final raw = json['product'];
    if (raw is Map<String, dynamic>) product = raw;
    else if (raw is Map) product = Map<String, dynamic>.from(raw);

    return StockReceiptDetail(
      id: (json['id'] ?? '').toString(),
      receiptId: (json['receiptId'] ?? '').toString(),
      productId: (json['productId'] ?? '').toString(),
      unitName: (json['unitName'] ?? '').toString(),
      expectedQty: parseFlexibleDouble(json['expectedQty']) ?? 0,
      actualQty: parseFlexibleDouble(json['actualQty']) ?? 0,
      qtyBaseUnit: parseFlexibleDouble(json['qtyBaseUnit']) ?? 0,
      unitPrice: parseFlexibleDouble(json['unitPrice']) ?? 0,
      lineAmount: parseFlexibleDouble(json['lineAmount']) ?? 0,
      batchNo: json['batchNo']?.toString(),
      expiryDate: json['expiryDate']?.toString(),
      productSku: product?['sku']?.toString(),
      productName: product?['name']?.toString(),
    );
  }
}

class StockReceipt {
  const StockReceipt({
    required this.id,
    required this.tenantId,
    required this.code,
    required this.receiptDate,
    required this.warehouseId,
    required this.status,
    required this.totalAmount,
    this.supplierId,
    this.deliveredByName,
    this.note,
    this.rejectReason,
    this.warehouseCode,
    this.warehouseName,
    this.supplierCode,
    this.supplierName,
    this.details = const [],
  });

  final String id;
  final String tenantId;
  final String code;
  final String receiptDate;
  final String warehouseId;
  final String? supplierId;
  final String status;
  final double totalAmount;
  final String? deliveredByName;
  final String? note;
  final String? rejectReason;
  final String? warehouseCode;
  final String? warehouseName;
  final String? supplierCode;
  final String? supplierName;
  final List<StockReceiptDetail> details;

  factory StockReceipt.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? nested(dynamic raw) {
      if (raw is Map<String, dynamic>) return raw;
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return null;
    }

    final warehouse = nested(json['warehouse']);
    final supplier = nested(json['supplier']);
    final details = <StockReceiptDetail>[];
    final rawDetails = json['details'];
    if (rawDetails is List) {
      for (final item in rawDetails) {
        if (item is Map<String, dynamic>) {
          details.add(StockReceiptDetail.fromJson(item));
        } else if (item is Map) {
          details.add(StockReceiptDetail.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return StockReceipt(
      id: (json['id'] ?? '').toString(),
      tenantId: (json['tenantId'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      receiptDate: (json['receiptDate'] ?? '').toString(),
      warehouseId: (json['warehouseId'] ?? '').toString(),
      supplierId: json['supplierId']?.toString(),
      status: (json['status'] ?? '').toString(),
      totalAmount: parseFlexibleDouble(json['totalAmount']) ?? 0,
      deliveredByName: json['deliveredByName']?.toString(),
      note: json['note']?.toString(),
      rejectReason: json['rejectReason']?.toString(),
      warehouseCode: warehouse?['code']?.toString(),
      warehouseName: warehouse?['name']?.toString(),
      supplierCode: supplier?['code']?.toString(),
      supplierName: supplier?['name']?.toString(),
      details: details,
    );
  }
}

class StockReceiptLineInput {
  StockReceiptLineInput({
    required this.productId,
    required this.unitName,
    required this.expectedQty,
    required this.actualQty,
    required this.unitPrice,
    this.batchNo,
    this.expiryDate,
  });

  final String productId;
  final String unitName;
  final double expectedQty;
  final double actualQty;
  final double unitPrice;
  final String? batchNo;
  final String? expiryDate;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'unitName': unitName,
        'expectedQty': expectedQty,
        'actualQty': actualQty,
        'unitPrice': unitPrice,
        if (batchNo != null && batchNo!.isNotEmpty) 'batchNo': batchNo,
        if (expiryDate != null && expiryDate!.isNotEmpty) 'expiryDate': expiryDate,
      };
}

class StockReceiptCreateRequest {
  const StockReceiptCreateRequest({
    required this.warehouseId,
    required this.receiptDate,
    required this.lines,
    this.supplierId,
    this.deliveredByName,
    this.note,
  });

  final String warehouseId;
  final String receiptDate;
  final String? supplierId;
  final String? deliveredByName;
  final String? note;
  final List<StockReceiptLineInput> lines;

  Map<String, dynamic> toJson() => {
        'warehouseId': warehouseId,
        'receiptDate': receiptDate,
        if (supplierId != null && supplierId!.isNotEmpty) 'supplierId': supplierId,
        if (deliveredByName != null && deliveredByName!.isNotEmpty)
          'deliveredByName': deliveredByName,
        if (note != null && note!.isNotEmpty) 'note': note,
        'lines': lines.map((e) => e.toJson()).toList(),
      };
}
```

- [ ] **Step 4: Run test — expect PASS**

```bash
flutter test test/data/models/stock_models_test.dart
```

---

### Task 4: Receipt API + repository

**Files:**
- Create: `lib/data/datasources/api_services/stock_receipt_api_service.dart`
- Create: `lib/domain/repositories/stock_receipt_repository.dart`
- Create: `lib/data/repositories/stock_receipt_repository_impl.dart`
- Modify: `lib/app/app.dart`

- [ ] **Step 1: StockReceiptApiService**

Pattern `WarehouseApiService` + `throwIfApiFailed`. Methods:

```dart
Future<List<StockReceipt>> list();
Future<StockReceipt> getById(String id);
Future<StockReceipt> create(StockReceiptCreateRequest body);
Future<StockReceipt> submit(String id);
Future<StockReceipt> approve(String id);
Future<StockReceipt> reject(String id, {String? reason});
Future<StockReceipt> complete(String id);
Future<StockReceipt> cancel(String id);
Future<StockReceipt> cloneFromRejected(String id);
```

`reject` POST body: `{'reason': reason ?? 'Rejected'}`.

Action endpoints: `postRequest` không body (trừ reject). Decode one `StockReceipt`. Nếu `IDEMPOTENT_SKIP` vẫn `success: true` → trả object nếu có, không throw.

- [ ] **Step 2: Repository interface + impl** — cùng signature, thin wrap.

- [ ] **Step 3: DI** — `RepositoryProvider<StockReceiptRepository>`.

---

### Task 5: Shared widgets + receipt list

**Files:**
- Create: `lib/features/stock_common/current_tenant_role.dart`
- Create: `lib/features/stock_common/widgets/stock_status_chip.dart`
- Create: `lib/features/stock_common/widgets/stock_hub_tile.dart`
- Create: `lib/features/stock_receipt/bloc/receipt_list_bloc.dart`
- Create: `lib/features/stock_receipt/pages/receipt_list_page.dart`

- [ ] **Step 1: Role helper**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_y_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_y_app/features/auth/bloc/auth_state.dart';

String currentTenantRole(BuildContext context) {
  final auth = context.read<AuthBloc>().state;
  if (auth is! AuthAuthenticated) return '';
  for (final t in auth.tenants) {
    if (t.id == auth.selectedTenantId) return t.role;
  }
  return auth.tenants.isEmpty ? '' : auth.tenants.first.role;
}
```

- [ ] **Step 2: Status chip** — `FilterChip`/`Chip` với `stockDocStatusLabel(status)`.

- [ ] **Step 3: Hub tile**

```dart
class StockHubTile extends StatelessWidget {
  const StockHubTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  // ListTile in Card, ColorSkin.tealLight icon box
}
```

- [ ] **Step 4: ReceiptListBloc** — copy structure `WarehouseListBloc`:

Events: `ReceiptListStarted`, `ReceiptListRefreshed`, `ReceiptListStatusFilterChanged(String? status)` (`null` = all).

State `ReceiptListLoaded`: `items`, `statusFilter`; getter `filtered` lọc `status` client-side.

- [ ] **Step 5: ReceiptListPage**

- `RefreshIndicator` + `ListView`
- Filter chips: Tất cả / Nháp / Chờ duyệt / Đã duyệt / Từ chối / Hoàn tất / Đã hủy
- Row: `code`, `StockStatusChip`, warehouse name/id, date (cắt `T` nếu ISO), `totalAmount` (không render `details`)
- Tap → `context.push('/receipts/${item.id}')`
- Empty / error + Thử lại
- FAB `+` nếu `canCreateOrSubmitStockDoc(currentTenantRole(context))` → `/receipts/new`

---

### Task 6: Receipt create form

**Files:**
- Create: `lib/features/stock_receipt/bloc/receipt_form_bloc.dart`
- Create: `lib/features/stock_receipt/pages/receipt_form_page.dart`

- [ ] **Step 1: ReceiptFormBloc**

Dependencies: `StockReceiptRepository`, `WarehouseRepository`, `ProductRepository`, `PartnerRepository`.

Events:
- `ReceiptFormStarted` — `Future.wait([warehouses.list(), products.list(), partners.listSuppliers()])`
- `ReceiptFormSubmitted` với fields + lines

States:
- `ReceiptFormLoading`
- `ReceiptFormReady({warehouses, products, suppliers})`
- `ReceiptFormSubmitting`
- `ReceiptFormSuccess(StockReceipt receipt)`
- `ReceiptFormFailure(String message)` — **không** xóa `Ready` data: emit failure rồi page snackbar; hoặc `Ready` + `errorMessage`. Dùng `ReceiptFormFailure` + listener; sau snackbar user vẫn ở form (bloc nên giữ cache và emit `Ready` lại kèm message, hoặc page không rebuild form khi Failure).

Khuyến nghị state:

```dart
class ReceiptFormReady extends ReceiptFormState {
  const ReceiptFormReady({
    required this.warehouses,
    required this.products,
    required this.suppliers,
    this.submitting = false,
    this.errorMessage,
  });
}
class ReceiptFormSuccess extends ReceiptFormState {
  const ReceiptFormSuccess(this.receipt);
}
```

Submit: validate `lines.isNotEmpty`; `receiptDate` ISO date `yyyy-MM-dd`; gọi `create`.

- [ ] **Step 2: ReceiptFormPage**

Form fields:
- Dropdown kho (bắt buộc)
- Date picker ngày nhập (bắt buộc, default today)
- Optional: bottom sheet search NCC (`suppliers`)
- Optional: người giao, ghi chú
- Lines: list cards — chọn SP (modal search sku/name), unit dropdown từ `product.units` (fallback `baseUnitName`), `expectedQty` ≥ 0, `actualQty` > 0, `unitPrice` ≥ 0, optional batch/HSD
- Nút thêm dòng / xóa dòng
- Submit → `ReceiptFormSubmitted`
- Success listener: `context.go('/receipts/${state.receipt.id}')` (không `setState` sau dispose)

Không gửi `details` rỗng. Disable submit khi `submitting`.

---

### Task 7: Receipt detail + workflow actions

**Files:**
- Create: `lib/features/stock_receipt/bloc/receipt_detail_bloc.dart`
- Create: `lib/features/stock_receipt/pages/receipt_detail_page.dart`

- [ ] **Step 1: ReceiptDetailBloc**

Events: `ReceiptDetailStarted(id)`, `ReceiptDetailActionRequested(StockDocAction action, {String? reason})`.

States: Loading / Loaded(receipt, {acting}) / Failure(message).

On action:
- emit Loaded với `acting: true` (disable nút)
- call matching repo method
- on success: `getById` lại (hoặc dùng response) → Loaded
- on `Failure`: nếu code `INVALID_STATUS_TRANSITION` hoặc `VERSION_CONFLICT` → reload rồi Loaded + `actionError`; còn lại Loaded + `actionError`
- Parse `STOCK_INSUFFICIENT` details thành message nhiều dòng (receipt complete ít gặp hơn issue)

- [ ] **Step 2: Detail page**

Header: code, chip status, kho, NCC, ngày, tổng, note, rejectReason nếu có.

Lines table/list: SP name/sku, unit, expected/actual, price, lineAmount.

Bottom buttons từ `visibleReceiptActions(status: receipt.status, role: role)`:

| Action | Confirm | Extra |
|--------|---------|-------|
| submit | “Gửi duyệt phiếu này?” | |
| approve | “Duyệt phiếu?” | |
| reject | dialog TextField lý do | reason default `Rejected` |
| complete | “Hoàn tất và cập nhật tồn?” | |
| cancel | “Hủy phiếu?” | |
| clone | “Tạo phiếu nháp từ phiếu bị từ chối?” | success → `go` id mới |

`acting` → disable nút + small progress.

Error snackbar từ `actionError`.

---

### Task 8: Issue models + API + repo + tests

**Files:**
- Create: `lib/data/models/stock_issue/stock_issue.dart`
- Modify: `test/data/models/stock_models_test.dart`
- Create: `lib/data/datasources/api_services/stock_issue_api_service.dart`
- Create: `lib/domain/repositories/stock_issue_repository.dart`
- Create: `lib/data/repositories/stock_issue_repository_impl.dart`
- Modify: `lib/app/app.dart`

- [ ] **Step 1: Add parse test**

```dart
  test('StockIssue.fromJson parses issueType, customer, lines', () {
    final issue = StockIssue.fromJson({
      'id': 'i1',
      'tenantId': 't1',
      'code': 'PX-2026-0001',
      'issueDate': '2026-08-17',
      'warehouseId': 'w1',
      'issueType': 'sale',
      'customerId': 'c1',
      'status': 'draft',
      'warehouse': {'id': 'w1', 'code': 'WH01', 'name': 'Kho chính'},
      'customer': {'id': 'c1', 'code': 'KH01', 'name': 'Bệnh viện A'},
      'details': [
        {
          'id': 'd1',
          'issueId': 'i1',
          'productId': 'p1',
          'unitName': 'cái',
          'requestedQty': '5.0000',
          'actualQty': '5.0000',
          'qtyBaseUnit': '5.0000',
          'unitPrice': '0',
          'product': {'sku': 'SP001', 'name': 'Sản phẩm A'},
        },
      ],
    });
    expect(issue.issueType, 'sale');
    expect(issue.customerName, 'Bệnh viện A');
    expect(issue.details.first.requestedQty, 5);
  });
```

- [ ] **Step 2: Implement StockIssue / StockIssueDetail / StockIssueLineInput / StockIssueCreateRequest**

`IssueType` values API: `sale`, `internal_use`, `return_to_supplier`, `disposal`.

Create JSON:

```dart
{
  'warehouseId': warehouseId,
  'issueType': issueType,
  'issueDate': issueDate,
  if (customerId != null) 'customerId': customerId,
  if (note != null) 'note': note,
  'lines': [
    {
      'productId': ...,
      'unitName': ...,
      'requestedQty': ...,
      'actualQty': ...,
      if (unitPrice != null) 'unitPrice': unitPrice,
    }
  ],
}
```

- [ ] **Step 3: StockIssueApiService** — list/get/create/submit/approve/reject/complete/cancel. **Không** clone.

- [ ] **Step 4: Repo + DI `StockIssueRepository`.**

- [ ] **Step 5: `flutter test test/data/models/stock_models_test.dart`** — PASS.

---

### Task 9: Issue list / form / detail

**Files:**
- Create: `lib/features/stock_issue/bloc/issue_list_bloc.dart`
- Create: `lib/features/stock_issue/pages/issue_list_page.dart`
- Create: `lib/features/stock_issue/bloc/issue_form_bloc.dart`
- Create: `lib/features/stock_issue/pages/issue_form_page.dart`
- Create: `lib/features/stock_issue/bloc/issue_detail_bloc.dart`
- Create: `lib/features/stock_issue/pages/issue_detail_page.dart`

- [ ] **Step 1: List** — như receipt; row hiện `issueTypeLabel(issue.issueType)` thay totalAmount; route `/issues`, `/issues/:id`, FAB `/issues/new`. Filter status giống receipt. Dùng `visibleIssueActions` không liên quan list.

- [ ] **Step 2: Form**

Load `Future.wait` warehouses, products, customers.

Fields:
- kho, ngày, `issueType` dropdown (4 giá trị)
- nếu `issueType == 'sale'` → bắt buộc chọn KH (picker `listCustomers`); validate trước submit: snackbar “Xuất bán cần chọn khách hàng”
- note
- lines: product, unit, `requestedQty` > 0, `actualQty` > 0, `unitPrice` optional ≥ 0

Success → `context.go('/issues/${id}')`.

- [ ] **Step 3: Detail**

Actions từ `visibleIssueActions`. Submit/complete: nếu `Failure.code == 'STOCK_INSUFFICIENT'`, hiện dialog:

```
Không đủ tồn kho
SP {productId}: cần {requested}, còn {available}
```

Parse `details` list of maps. Reload sau `INVALID_STATUS_TRANSITION` / `VERSION_CONFLICT`.

Helper format (đặt `lib/features/stock_common/stock_insufficient_message.dart`):

```dart
String formatStockInsufficient(Object? details) {
  if (details is! List) return 'Không đủ tồn kho';
  final lines = <String>[];
  for (final item in details) {
    if (item is Map) {
      lines.add(
        'SP ${item['productId']}: cần ${item['requested']}, còn ${item['available']}',
      );
    }
  }
  return lines.isEmpty ? 'Không đủ tồn kho' : 'Không đủ tồn kho\n${lines.join('\n')}';
}
```

Thêm unit test nhỏ trong `test/core/auth/` hoặc `test/features/stock_insufficient_message_test.dart`.

---

### Task 10: Reports

**Files:**
- Create: `lib/data/models/report/stock_balance_row.dart`
- Create: `lib/data/models/report/stock_movement_row.dart`
- Create: `lib/data/datasources/api_services/report_api_service.dart`
- Create: `lib/domain/repositories/report_repository.dart`
- Create: `lib/data/repositories/report_repository_impl.dart`
- Modify: `lib/app/app.dart`
- Create: `lib/features/report/pages/report_hub_page.dart`
- Create: `lib/features/report/bloc/stock_balance_bloc.dart`
- Create: `lib/features/report/pages/stock_balance_page.dart`
- Create: `lib/features/report/bloc/stock_movement_bloc.dart`
- Create: `lib/features/report/pages/stock_movement_page.dart`
- Modify: `test/data/models/stock_models_test.dart`

- [ ] **Step 1: Models + parse tests** theo JSON spec:

Balance: `onhandQty`, nested `product.{sku,name,baseUnitName}`, `warehouse.{code,name}`.

Movement: `transactionType`, `refDocType`, `refDocId`, `qtyChange`, `qtyBalanceAfter`, `unitCost`, `createdAt`, nested product/warehouse.

- [ ] **Step 2: ReportApiService**

```dart
Future<List<StockBalanceRow>> stockBalance({String? warehouseId});
Future<List<StockMovementRow>> stockMovement({
  String? warehouseId,
  String? from,
  String? to,
});
```

`getRequest` với `queryParameters` bỏ key null.

- [ ] **Step 3: Repo + DI `ReportRepository`.**

- [ ] **Step 4: ReportHubPage** (Stateless, 2 `StockHubTile`):
  - Tồn kho → `/reports/stock-balance`
  - Xuất–Nhập–Tồn → `/reports/stock-movement`

- [ ] **Step 5: StockBalanceBloc**

Events: `StockBalanceStarted` (load warehouses only, **chưa** gọi report), `StockBalanceApplied({String? warehouseId})`.

Initial: warehouses loaded, `rows` empty, `hasQueried: false`.

Apply → GET report.

Page: dropdown kho (Tất cả = null), nút **Áp dụng**, list: sku, name, warehouse, onhandQty + unit. Empty: “Bấm Áp dụng để tải” nếu `!hasQueried`.

- [ ] **Step 6: StockMovementBloc**

Started: load warehouses. Applied: warehouseId + from + to (ISO datetime).

Page: kho, date range (from 00:00, to 23:59:59 local → ISO), **Áp dụng**.

Caption: “Tối đa 500 bản ghi theo máy chủ.”

Row: createdAt, transactionType, product, qtyChange, qtyBalanceAfter. **Không** bắt buộc deep-link phiếu.

---

### Task 11: Router + Home hubs + quick actions

**Files:**
- Modify: `lib/app/router/app_router.dart`
- Modify: `lib/features/home/pages/home_page.dart`
- Create: `lib/features/stock_receipt/pages/receipt_hub_page.dart` (optional — hub có thể nằm trong home)

- [ ] **Step 1: AppRoutes** thêm:

```dart
  receipts('/receipts'),
  receiptsNew('/receipts/new'),
  receiptDetail('/receipts/:id'),
  issues('/issues'),
  issuesNew('/issues/new'),
  issueDetail('/issues/:id'),
  reportStockBalance('/reports/stock-balance'),
  reportStockMovement('/reports/stock-movement'),
```

`_needsTenant`:

```dart
    return location == AppRoutes.home.path ||
        location.startsWith('/warehouses') ||
        location.startsWith('/products') ||
        location.startsWith('/receipts') ||
        location.startsWith('/issues') ||
        location.startsWith('/reports');
```

GoRoutes (BlocProvider create như warehouse):

| path | bloc + page |
|------|-------------|
| `/receipts` | ReceiptListBloc..Started + ReceiptListPage |
| `/receipts/new` | ReceiptFormBloc..Started + ReceiptFormPage |
| `/receipts/:id` | ReceiptDetailBloc..Started(id) + page |
| `/issues` | IssueListBloc + IssueListPage |
| `/issues/new` | IssueFormBloc + IssueFormPage |
| `/issues/:id` | IssueDetailBloc + page |
| `/reports/stock-balance` | StockBalanceBloc..Started + page |
| `/reports/stock-movement` | StockMovementBloc..Started + page |

Hub Phiếu/Báo cáo **không** cần route riêng — nằm trong Home tab.

- [ ] **Step 2: Receipt hub widget** trong `lib/features/stock_receipt/pages/receipt_hub_page.dart`:

```dart
class ReceiptHubPage extends StatelessWidget {
  const ReceiptHubPage({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StockHubTile(
          icon: Icons.move_to_inbox_outlined,
          title: 'Phiếu nhập',
          subtitle: 'Nhập kho từ nhà cung cấp',
          onTap: () => context.push(AppRoutes.receipts.path),
        ),
        const SizedBox(height: 12),
        StockHubTile(
          icon: Icons.outbox_outlined,
          title: 'Phiếu xuất',
          subtitle: 'Xuất bán, nội bộ, trả NCC, tiêu hủy',
          onTap: () => context.push(AppRoutes.issues.path),
        ),
      ],
    );
  }
}
```

`ReportHubPage` tương tự (đã tạo Task 10) dùng trong Home.

- [ ] **Step 3: HomePage**

Thay:

```dart
              const _PlaceholderTab(title: 'Phiếu', subtitle: 'Sắp ra mắt'),
              const _PlaceholderTab(title: 'Báo cáo', subtitle: 'Sắp ra mắt'),
```

bằng:

```dart
              const ReceiptHubPage(),
              const ReportHubPage(),
```

Xóa `_PlaceholderTab` nếu không còn dùng.

Quick actions Overview — `_QuickAction` Nhập kho / Xuất kho thêm `onTap`:

```dart
onTap: () => context.push(AppRoutes.receiptsNew.path),
onTap: () => context.push(AppRoutes.issuesNew.path),
```

Bỏ `const` trên những `Expanded` đó.

**Không** đổi KPI mock (“Phiếu chờ duyệt” = 5) — đúng spec out of scope.

---

### Task 12: Analyze, remaining tests, manual QA

**Files:** changed Dart files from Tasks 1–11

- [ ] **Step 1: Unit tests**

```bash
flutter test test/core/auth test/core/error test/data/models
```

Expected: All tests passed.

- [ ] **Step 2: Analyzer**

```bash
flutter analyze lib/core/auth lib/core/error lib/data lib/domain lib/features/stock_common lib/features/stock_receipt lib/features/stock_issue lib/features/report lib/features/home lib/app
```

Expected: No issues (hoặc chỉ info pre-existing).

- [ ] **Step 3: Manual QA checklist** (device/simulator, backend + tenant + warehouse + product + tồn sẵn)

- [ ] Tab Phiếu / Báo cáo không còn “Sắp ra mắt”
- [ ] Quick action Nhập kho / Xuất kho mở form
- [ ] Tạo phiếu nhập (có ≥1 dòng) → detail status `draft`
- [ ] Submit → `pending_approval`; Approve → `approved`; Complete → `completed`
- [ ] Reject (có lý do) → Clone → phiếu draft mới
- [ ] Xuất `sale` thiếu KH → blocked client
- [ ] Submit/complete xuất thiếu tồn → dialog `STOCK_INSUFFICIENT`
- [ ] Báo cáo tồn + movement, có/không filter kho; movement hiện caption 500
- [ ] Role viewer: không FAB, không nút action ghi
- [ ] List phiếu không expand lines (chỉ header)

---

## Spec coverage

| Spec item | Task |
|-----------|------|
| Partner picker GET only | 2, 6, 9 |
| Receipt full workflow + clone | 3–7 |
| Issue full workflow, sale+customer, STOCK_INSUFFICIENT | 8–9 |
| Reports both + filter on Áp dụng | 10 |
| Home hubs + quick actions | 11 |
| RBAC helpers + status×role buttons | 1, 5, 7, 9 |
| List header-only | 5, 9 |
| Error mapping codes | 1, 7, 9 |
| No KPI dashboard API / no partner CRUD / no opening balance | — omitted |
| Unit tests models + RBAC | 1, 3, 8, 10, 12 |

## Placeholder scan

Không còn TBD. Clone chỉ phiếu nhập. Deep-link movement → phiếu **không** làm. Commit steps skip nếu không có git.
