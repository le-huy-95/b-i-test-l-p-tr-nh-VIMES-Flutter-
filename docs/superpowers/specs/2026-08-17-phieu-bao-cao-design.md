# Phase 3 — Phiếu + Báo cáo (VIMES) Design Spec

> **Status:** Approved by product owner (2026-08-17)  
> **Note:** Workspace hiện chưa có `.git`; spec chưa commit được.  
> **Sources:** Brainstorm session; Backend `test-y-Backend/docs/API.md` (stock-receipts, stock-issues, reports, suppliers, customers); Flutter patterns from Phase 2 warehouse/product; Home shell placeholders in `lib/features/home/pages/home_page.dart`

## Goal

Thay placeholder tab **Phiếu** / **Báo cáo** bằng luồng thật gọi API `/api/v1`: phiếu nhập, phiếu xuất (full workflow trạng thái), báo cáo tồn kho và xuất–nhập–tồn — mirror kiến trúc feature Kho/Sản phẩm, **không mock data**.

## Decisions

| Topic | Choice |
|-------|--------|
| Scope delivery | Chỉ **Phiếu + Báo cáo** (+ partner picker mỏng); không CRUD đối tác / tồn đầu kỳ |
| Approach | **Hướng 1** — feature modules tách: `stock_receipt`, `stock_issue`, `report` |
| Data | Real API theo `API.md` |
| Workflow phiếu | Full: tạo → submit → approve/reject → complete/cancel (+ clone-from-rejected cho nhập) |
| Tab Phiếu UX | Hub menu → màn **Phiếu nhập** / **Phiếu xuất** riêng |
| Tab Báo cáo UX | Hub → **Tồn kho** + **Xuất–Nhập–Tồn** (cả hai API) |
| Đối tác | Chỉ **picker** `GET /suppliers`, `GET /customers` (không POST/PUT UI) |
| State | Bloc per screen → Repository → `*ApiService` (Dio + AuthInterceptor) |
| List performance | List render **header only** (không expand toàn bộ `details[]`) |
| Report fetch | Chỉ gọi API khi bấm **Áp dụng** filter |
| RBAC | Ẩn/hiện nút theo role; backend vẫn nguồn đúng |
| Dashboard KPI | **Không** thay mock KPI trong phase này |

## Out of scope

- Module Đối tác đầy đủ (CRUD NCC/KH)
- Tồn đầu kỳ (`/stock-opening-balances`)
- Phiếu chuyển kho (backend chưa có REST module)
- Dashboard KPI / low-stock / “phiếu chờ duyệt” từ API thật
- Camera barcode / `mobile_scanner`
- Pagination / infinite scroll / server-side list summary (chờ backend)
- Export PDF/CSV báo cáo
- Deep-link bắt buộc từ dòng movement → detail phiếu (optional nếu effort thấp; không bắt buộc)
- Use-case layer bắt buộc (Kho/SP thường Bloc → Repo; giữ nhất quán trừ logic phức tạp)

## Architecture

```
UI features/stock_receipt + stock_issue + report (+ Home hubs + quick actions)
  → Bloc per screen
    → StockReceiptRepository / StockIssueRepository / ReportRepository / PartnerRepository
      → *ApiService (Dio)
        → Backend /api/v1/stock-receipts|stock-issues|reports|suppliers|customers
AuthInterceptor: Bearer + X-Tenant-Id (đã có)
```

### Feature layout

| Path | Responsibility |
|------|----------------|
| `lib/data/models/partner/supplier.dart` | Supplier (picker) |
| `lib/data/models/partner/customer.dart` | Customer (picker) |
| `lib/data/models/stock_receipt/*` | Receipt + detail lines + create payload |
| `lib/data/models/stock_issue/*` | Issue + detail lines + create payload; `IssueType` |
| `lib/data/models/report/stock_balance_row.dart` | Tồn kho row |
| `lib/data/models/report/stock_movement_row.dart` | Movement row |
| `lib/data/datasources/api_endpoints.dart` | Paths mới |
| `lib/data/datasources/api_services/partner_api_service.dart` | GET list suppliers/customers |
| `lib/data/datasources/api_services/stock_receipt_api_service.dart` | CRUD-ish + workflow actions |
| `lib/data/datasources/api_services/stock_issue_api_service.dart` | Tương tự xuất |
| `lib/data/datasources/api_services/report_api_service.dart` | stock-balance, stock-movement |
| `lib/domain/repositories/*.dart` + `lib/data/repositories/*_impl.dart` | Contracts + impl |
| `lib/core/auth/tenant_permissions.dart` | Helpers phiếu (mở rộng) |
| `lib/features/stock_receipt/{pages,bloc}` | Hub entry via Home; list/form/detail |
| `lib/features/stock_issue/{pages,bloc}` | List/form/detail |
| `lib/features/report/{pages,bloc}` | Hub + 2 report screens |
| `lib/app/app.dart` | DI RepositoryProvider |
| `lib/app/router/app_router.dart` | Routes + `_needsTenant` |
| `lib/features/home/pages/home_page.dart` | Replace placeholders; wire quick actions |

## API surface (Flutter phải gọi)

### Partners (picker only)

- `GET /api/v1/suppliers`
- `GET /api/v1/customers`

### Stock receipts

- `GET /api/v1/stock-receipts`
- `POST /api/v1/stock-receipts`
- `GET /api/v1/stock-receipts/:id`
- `POST .../submit` · `approve` · `reject` · `complete` · `cancel` · `clone-from-rejected`

**Create body (required):** `warehouseId`, `receiptDate`, `lines[]` (min 1) với `productId`, `unitName`, `expectedQty` (≥0), `actualQty` (>0), `unitPrice` (≥0).  
**Optional:** `supplierId`, `deliveredByName`, `note`, `lines[].batchNo`, `lines[].expiryDate`.

### Stock issues

- `GET /api/v1/stock-issues`
- `POST /api/v1/stock-issues`
- `GET /api/v1/stock-issues/:id`
- `POST .../submit` · `approve` · `reject` · `complete` · `cancel`

**Create body (required):** `warehouseId`, `issueType`, `issueDate`, `lines[]` với `productId`, `unitName`, `requestedQty` (>0), `actualQty` (>0).  
**Conditional:** `customerId` bắt buộc khi `issueType = sale`.  
**Optional:** `note`, `lines[].unitPrice`.

**IssueType enum:** `sale`, `internal_use`, `return_to_supplier`, `disposal`.

### Reports

- `GET /api/v1/reports/stock-balance?warehouseId=`
- `GET /api/v1/reports/stock-movement?warehouseId=&from=&to=` (max 500 rows)

## Authorization (UI helpers)

Đồng bộ bảng role trong `API.md`:

| Helper | Roles |
|--------|-------|
| `canCreateOrSubmitStockDoc(role)` | `admin`, `warehouse_keeper` |
| `canApproveOrCompleteStockDoc(role)` | `admin`, `accountant`, `approver` |
| `canCancelStockDoc(role)` | `admin`, `warehouse_keeper` |
| View lists / reports / detail | any authenticated tenant member |

Nút action chỉ hiện khi **status cho phép** và **role cho phép**. 403 từ API → snackbar lỗi thân thiện.

## Navigation & screens

### Routes

| Path | Screen |
|------|--------|
| (Home tab index 2) | Phiếu hub |
| `/receipts` | Receipt list |
| `/receipts/new` | Receipt create form |
| `/receipts/:id` | Receipt detail + actions |
| `/issues` | Issue list |
| `/issues/new` | Issue create form |
| `/issues/:id` | Issue detail + actions |
| (Home tab index 3) | Báo cáo hub |
| `/reports/stock-balance` | Tồn kho |
| `/reports/stock-movement` | Xuất–Nhập–Tồn |

Tất cả trừ splash/auth flow: yêu cầu authenticated + tenant (cùng `_needsTenant` / redirect hiện có).

### Home wiring

- Tab Phiếu / Báo cáo: thay `_PlaceholderTab` bằng hub widgets.
- Overview quick actions “Nhập kho” / “Xuất kho”: `context.push` create routes.

### Screen behavior

**List (receipt/issue)**

- Load `GET` collection; pull-to-refresh.
- Row: code, status chip, warehouse, date, totalAmount (receipt) hoặc issueType (issue).
- Client-side status filter chips.
- FAB create nếu `canCreateOrSubmitStockDoc`.

**Create form**

- Parallel load warehouses + products (+ suppliers hoặc customers khi cần) qua `Future.wait`.
- Validate client trước POST; on 201 → navigate detail.
- Issue: nếu `sale` mà thiếu `customerId` → validation UI (khớp `VALIDATION_ERROR`).

**Detail**

- `GET :id` (header + lines + warehouse + partner).
- Actions:

| Status | Receipt actions (nếu đủ role) | Issue actions |
|--------|------------------------------|---------------|
| `draft` | submit, cancel | submit, cancel |
| `pending_approval` | approve, reject (+ reason), cancel | approve, reject, cancel |
| `approved` | complete, cancel | complete, cancel |
| `rejected` | clone-from-rejected | (xem only) |
| `completed` / `cancelled` | view only | view only |

- Confirm dialog trước approve / reject / complete / cancel.
- After success: reload detail (hoặc dùng body nếu API trả object đủ).

**Reports**

- Filters: warehouse optional; movement thêm from/to.
- Fetch on **Áp dụng** only.
- UI note: movement capped at 500.

## Error mapping

| API signal | UX |
|------------|-----|
| `STOCK_INSUFFICIENT` (+ `details[]`) | Dialog/snackbar: productId / requested / available |
| `INVALID_STATUS_TRANSITION` | Message + reload detail |
| `VERSION_CONFLICT` | Message + reload / retry |
| `VALIDATION_ERROR` | Field-level hoặc snackbar |
| `IDEMPOTENT_SKIP` (200) | Treat as success; reload detail |
| Network / 5xx | Error state + Thử lại |
| 401 / missing tenant | Existing AuthInterceptor / router behavior |

## Performance & scale notes

**Phase này**

- Không expand `details` trên list.
- Không poll; không fetch report mỗi keystroke filter.
- IndexedStack Home giữ như hiện tại (hub nhẹ).

**Khi hệ thống lớn hơn (không implement ngay)**

- Backend list summary + pagination; server filter `status`/`date`.
- Report aggregate / export khi vượt 500.
- Lazy dispose tab blocs nếu tab ngày càng nặng.
- Warehouse scope theo `UserWarehouse` khi backend enforce.

## Testing

1. **Unit:** JSON parse models (fixtures từ `API.md`); RBAC helpers × status matrix.
2. **Manual QA:**  
   - Receipt: create → submit → approve → complete  
   - Receipt: reject → clone → draft mới  
   - Issue `sale` thiếu customer → blocked  
   - Issue submit/complete với thiếu tồn → `STOCK_INSUFFICIENT` UI  
   - Both reports với/không filter  
   - Role viewer: không thấy FAB/action ghi  
3. Không bắt buộc Appium/E2E trong phase này.

## Success criteria

- [ ] Tab Phiếu / Báo cáo không còn “Sắp ra mắt”
- [ ] Tạo và chạy full workflow phiếu nhập & xuất trên API thật
- [ ] Picker NCC/KH hoạt động (list API); không có màn CRUD đối tác
- [ ] Hai báo cáo hiển thị data thật với filter
- [ ] Quick actions Nhập/Xuất kho điều hướng đúng
- [ ] RBAC nút khớp `API.md`; lỗi tồn/conflict hiện rõ cho user

## Implementation order (suggested for plan)

1. Endpoints + partner models/api/repo (list only)  
2. Receipt models/api/repo + list/detail/create + actions  
3. Issue models/api/repo + list/detail/create + actions  
4. Report models/api/repo + 2 screens  
5. Home hubs + quick actions + router/DI  
6. Permissions helpers + error mapping polish + manual QA  
