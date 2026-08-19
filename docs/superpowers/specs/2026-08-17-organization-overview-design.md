# Organization Overview — Tab Tổng quan Design Spec

> **Status:** Approved in brainstorm (Hướng 1) — implement immediately per product owner  
> **Date:** 2026-08-17  
> **Sources:** Backend `test-y-Backend/docs/ORGANIZATION_OVERVIEW.md`, Flutter `lib/features/home/pages/home_page.dart`, warehouse/product feature patterns

## Goal

Xóa toàn bộ mock trên tab **Tổng quan** (`_OverviewTab`) và thay bằng dashboard thật từ `GET /api/v1/reports/organization-overview`, layout theo `visibilityScope`, không date picker, không warehouse-overview, không quick actions.

## Decisions

| Topic | Choice |
|-------|--------|
| Scope | Chỉ tab Tổng quan + 1 API organization-overview |
| Approach | Feature module `overview` (Hướng 1) |
| Kỳ dữ liệu | 30 ngày gần nhất (`from` = now−30d, `to` = now); không UI lọc ngày |
| Org layout | KPI + phiếu chờ + top SP nhập/xuất + `warehousesBreakdown` (không tap kho) |
| Own-docs layout | Ẩn inventory + breakdown; phiếu của tôi + top SP của tôi |
| Quick actions | Gỡ hết khỏi Tổng quan |
| Tenant switch | `OverviewRefreshed` giống `WarehouseListRefreshed`; loading, không giữ số tenant cũ |
| State | Bloc → Repository → ApiService (không use-case layer) |
| Pending phiếu tap | Không điều hướng (tab Phiếu chưa có màn) |

## Out of scope

- `GET /reports/warehouse-overview` và màn chi tiết kho
- Date picker / đổi kỳ trên UI
- Quick actions (Quét mã / Nhập / Xuất / Sản phẩm)
- Danh sách SKU sắp hết hàng (API chỉ trả `lowStockCount`, không list tên)
- Module Phiếu / Báo cáo
- Pagination pending list (API `recentLimit` mặc định 5)

## Architecture

```
OverviewPage (Home tab 0)
  → OverviewBloc
    → OverviewRepository
      → OverviewApiService
        → GET /api/v1/reports/organization-overview
AuthInterceptor: Bearer + X-Tenant-Id (đã có)
```

`HomePage` giữ AppBar, 5 tab, tenant switcher. Tạo `OverviewBloc` cùng vòng đời `WarehouseListBloc`. Đổi `selectedTenantId` → `OverviewRefreshed` + `WarehouseListRefreshed`.

Storage tenant được ghi **trước** `emit` (`selectTenant` await) nên interceptor đọc đúng `X-Tenant-Id` trên GET mới.

## API

```
GET /api/v1/reports/organization-overview
  ?from=<ISO>
  &to=<ISO>
  &expiryDays=30
  &topLimit=5
  &recentLimit=5
```

Headers: `Authorization`, `X-Tenant-Id` (interceptor).

`visibilityScope`:

- `organization` — admin / accountant / approver: `inventory` có data, `warehousesBreakdown` có phần tử
- `own_documents` — warehouse_keeper / viewer: `inventory = null`, `warehousesBreakdown = []`

## Models

Parse đúng JSON backend (`organization-overview.service.ts`):

- `OrganizationOverview`: `generatedAt`, `visibilityScope`, `role`, `filters`, `organization`, `documents`, `productMovement`, `inventory?`, `warehousesBreakdown`
- `inventory` nullable; qty / money là **string**
- `DocStatusStats`: `byStatus`, `total`, `pendingApproval`, `draft`, `completed`
- Receipt pending: `id`, `code`, `receiptDate`, `receiptType`, `totalAmount`, `status`, `createdAt`, `warehouse`, `supplier?`, `createdById`
- Issue pending: `id`, `code`, `issueDate`, `issueType`, `status`, `createdAt`, `warehouse`, `customer?`, `createdById`
- Top product: `productId`, `sku`, `name`, `baseUnitName`, `totalQty`, `documentCount`
- Warehouse breakdown: `warehouse` + `productMovement` + `stockReceipts` + `stockIssues`

Getter UI: `isOrganizationScope`, `pendingDocuments` (gộp nhập+xuất, sort `createdAt` tăng dần), `pendingApprovalCount`, `alertCount` (`lowStockCount + expiryAlertCount`).

## UI mapping

Chung (mọi scope):

1. Xin chào + subtitle **30 ngày gần nhất**
2. Pull-to-refresh
3. Phiếu chờ duyệt: số + list (`pendingDocuments`). Empty: “Không có phiếu chờ duyệt”
4. Top SP nhập / Top SP xuất (`name`, `sku`, `totalQty` + `baseUnitName`, `documentCount` phiếu)

`visibilityScope = organization` thêm:

- KPI: giá trị tồn (`estimatedStockValue`), cảnh báo (`alertCount`), số kho, SKU còn tồn
- Breakdown từng kho: tên/mã, SL nhập/xuất, số phiếu nhập/xuất — **không** `onTap`

`visibilityScope = own_documents`:

- Không KPI tồn / cảnh báo / số kho / breakdown
- KPI phiếu: chờ duyệt, nháp, hoàn tất, tổng SL nhập/xuất (từ `productMovement`)

Loading: spinner full tab (không giữ data cũ).  
Error: message + **Thử lại**.  
List rỗng: text empty, không mock.

Format: `intl` locale `vi_VN` — tiền `₫`, qty bỏ zero thừa.

## Error / refresh

| Sự kiện | Hành vi |
|---------|---------|
| Lần đầu `OverviewStarted` | Loading → Loaded / Failure |
| Pull-to-refresh | `OverviewRefreshed` → Loading → Loaded |
| Đổi tenant | Listener → `OverviewRefreshed`; interceptor header mới |
| API lỗi | Failure + retry; không hiện số tenant trước |

## Testing

- `OrganizationOverview.fromJson`: org đầy đủ; `inventory: null` + breakdown rỗng
- `OverviewBloc`: success Loading→Loaded; failure; refresh gọi repo với `from`/`to` ~ 30 ngày (inject clock)
- Không bắt widget test AppBar (đã cover gián tiếp qua bloc + parse)

## File layout

| Path | Việc |
|------|------|
| `lib/data/models/overview/organization_overview.dart` | Models + fromJson |
| `lib/data/datasources/api_endpoints.dart` | Path |
| `lib/data/datasources/api_services/overview_api_service.dart` | GET |
| `lib/domain/repositories/overview_repository.dart` | Contract |
| `lib/data/repositories/overview_repository_impl.dart` | Impl |
| `lib/features/overview/bloc/overview_bloc.dart` | Events/states/bloc |
| `lib/features/overview/pages/overview_page.dart` | UI |
| `lib/features/overview/overview_formatters.dart` | Money / qty |
| `lib/app/app.dart` | DI |
| `lib/features/home/pages/home_page.dart` | Gỡ mock; embed OverviewPage |
| `test/data/models/organization_overview_test.dart` | Parse |
| `test/features/overview/overview_bloc_test.dart` | Bloc |
| `test/features/overview/overview_formatters_test.dart` | Format |
