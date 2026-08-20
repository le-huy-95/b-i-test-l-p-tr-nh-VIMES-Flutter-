# Phase 2 — Warehouse + Product Module (VIMES) Design Spec

> **Status:** Approved by product owner (2026-08-16)  
> **Sources:** Design board `VIMES-Inventory-UI-Design-Board`, Backend `test-y-Backend/docs/API.md` + `src/modules/warehouse`, `src/middlewares/tenant.ts`, app `test_y_app`, Maps keys from `ktx-app` (không có trong `ktx-be-new`)

## Goal

Implement Module 03 (Kho) và Module 04 (Sản phẩm) theo UI VIMES, gọi API thật `/api/v1`, gắn vào shell Dashboard đã có sau Auth — nền tảng master data trước các phase phiếu / báo cáo.

## Decisions

| Topic                | Choice                                                                                 |
| -------------------- | -------------------------------------------------------------------------------------- |
| Delivery             | Phased roadmap (9 module còn lại); phase này chỉ Kho + SP                              |
| Approach             | Feature modules song song Auth (`features/warehouse`, `features/product`)              |
| Data                 | Real API (`/api/v1`) theo `API.md`                                                     |
| Barcode              | Stub nhập tay → `GET /products/barcode/:code` (không camera)                           |
| Kho write            | Create + Update (API **không** có DELETE warehouse)                                    |
| SP write             | Create + Update + soft Delete                                                          |
| Map                  | Google Maps thật (`google_maps_flutter`)                                               |
| Maps keys            | Lấy từ `ktx-app` (Android Manifest + iOS `GMSServices`)                                |
| Navigation           | Tab **Kho** = warehouse list; Sản phẩm từ quick action Dashboard + routes `/products…` |
| Warehouse list scope | Theo API hiện tại: **mọi kho active trong tenant** (không client-filter theo gán kho)  |
| State                | Bloc per screen + Repository + Dio (pattern Auth)                                      |

## Out of scope (Phase 2)

- Module 05–10 (đối tác, tồn đầu kỳ, phiếu nhập/xuất, báo cáo, cá nhân/mời thành viên)
- Dashboard KPI / low-stock từ API thật
- Camera barcode / `mobile_scanner`
- Client-side filter theo `UserWarehouse` / `warehouseIds` (backend chưa enforce trên `GET /warehouses`)
- Soft-delete warehouse trên UI (route backend có `DELETE /warehouses/:id` + `softDelete`, nhưng **`API.md` chưa document** — Phase 2 không gọi; sync docs rồi mới bật)
- Cập nhật `units` qua `PUT /products` (API: không cập nhật units qua endpoint này)
- Mapbox / placeholder-only map

## Roadmap (sau Phase 2 — không implement trong cycle này)

1. Đối tác (NCC / KH)
2. Tồn đầu kỳ
3. Phiếu nhập → Phiếu xuất
4. Báo cáo
5. Cá nhân + thành viên
6. Dashboard API thật
7. (Khi backend enforce) Warehouse scope theo `UserWarehouse`

## Architecture

```
UI features/warehouse + features/product (+ Home tab / quick actions)
  → Bloc per screen
    → Use cases
      → WarehouseRepository / ProductRepository
        → WarehouseApiService / ProductApiService (Dio)
          → Backend /api/v1/warehouses|products/*
AuthInterceptor: Bearer + X-Tenant-Id (đã có từ Phase 1)
```

### Feature layout

| Path                                                           | Responsibility                                                          |
| -------------------------------------------------------------- | ----------------------------------------------------------------------- |
| `lib/data/models/warehouse/warehouse.dart`                     | Warehouse model                                                         |
| `lib/data/models/product/product.dart`                         | Product + ProductUnit                                                   |
| `lib/data/datasources/api_endpoints.dart`                      | Warehouse/product paths                                                 |
| `lib/data/datasources/api_services/warehouse_api_service.dart` | HTTP                                                                    |
| `lib/data/datasources/api_services/product_api_service.dart`   | HTTP                                                                    |
| `lib/domain/repositories/warehouse_repository.dart`            | Interface                                                               |
| `lib/domain/repositories/product_repository.dart`              | Interface                                                               |
| `lib/data/repositories/*_impl.dart`                            | Impl                                                                    |
| `lib/domain/usecases/warehouse/*`                              | list/get/create/update                                                  |
| `lib/domain/usecases/product/*`                                | list/get/create/update/delete/lookupBarcode                             |
| `lib/core/auth/tenant_permissions.dart`                        | `canManageMasterData(role)`                                             |
| `lib/features/warehouse/**`                                    | Bloc + pages + widgets                                                  |
| `lib/features/product/**`                                      | Bloc + pages + widgets                                                  |
| `lib/app/router/app_router.dart`                               | Routes                                                                  |
| `lib/features/home/pages/home_page.dart`                       | Tab Kho + quick action → products                                       |
| Android Manifest / iOS AppDelegate                             | Google Maps API keys                                                    |
| `.env` / `.env.example`                                        | Optional mirror of keys for docs; **native keys required** for Maps SDK |

## Authorization (đọc từ API trước khi UI)

### TenantRole

`admin` | `warehouse_keeper` | `accountant` | `approver` | `viewer`

### Phase 2 matrix

| Action                       | Endpoint                                 | Allowed roles       |
| ---------------------------- | ---------------------------------------- | ------------------- |
| List/detail warehouses       | `GET /warehouses`, `GET /warehouses/:id` | **any** (in tenant) |
| Create/update warehouse      | `POST` / `PUT /warehouses`               | **admin** only      |
| List/detail/barcode products | `GET /products…`                         | **any**             |
| Create/update/delete product | `POST` / `PUT` / `DELETE`                | **admin** only      |

`warehouse_keeper` / `accountant` / `approver` / `viewer`: **read-only** master data.  
(Ghi phiếu nhập/xuất thuộc phase sau — không mở rộng ghi kho/SP cho thủ kho ở phase này.)

### UI RBAC

- `canManageMasterData(role) => role == 'admin'`
- Role từ `AuthBloc` → selected `TenantMembership.role`
- Non-admin: ẩn `+`, edit, delete; vẫn xem detail + map + barcode lookup
- Deep-link vào form khi không đủ quyền → redirect list + toast “Không đủ quyền”
- API 403 vẫn map toast (defense in depth)

### Warehouse assignment (`UserWarehouse`) — note quan trọng

Backend:

- `POST /tenants/current/users` có `warehouseIds` → ghi `UserWarehouse`
- Middleware set `req.tenant.warehouseIds`: admin → `'all'`, else → assigned IDs
- **`WarehouseService.list/get` hiện không filter theo `warehouseIds`** — mọi role trong tenant thấy mọi kho `isActive`

**Phase 2 decision:** App hiển thị đúng response API (toàn bộ kho active). Không client-filter. Ghi rõ dependency backend nếu sau này enforce scope.

## User flows

### Kho

1. Tab Kho → `GET /warehouses` → list (search local hoặc query `search` nếu pagination)
2. Tap item → `GET /warehouses/:id` → detail + Google Map marker (lat/long)
3. Admin: `+` → form → `POST /warehouses` → pop + refresh
4. Admin: edit → form → `PUT /warehouses/:id` → pop + refresh
5. Thiếu lat/long: map camera mặc định (HCM ~10.7769, 106.7009) + banner “Chưa có toạ độ”

### Sản phẩm

1. Dashboard quick action “Sản phẩm” → `/products` → `GET /products`
2. Detail → `GET /products/:id` (SKU, barcode, units, costing, min stock, flags batch/HSD)
3. Admin CRUD form → `POST` / `PUT` / `DELETE` (confirm trước delete)
4. Lookup stub: nhập barcode → `GET /products/barcode/:code` → navigate detail hoặc empty “Không tìm thấy”
5. Validation: FIFO/FEFO yêu cầu `trackBatch=true` — hiện lỗi API `VALIDATION_ERROR` trên form

## Routes

Yêu cầu: authenticated + đã chọn tenant (giống `/home`).

| Path                    | Page                              |
| ----------------------- | --------------------------------- |
| `/home` (tab index Kho) | `WarehouseListPage` embedded      |
| `/warehouses/new`       | `WarehouseFormPage` (create)      |
| `/warehouses/:id`       | `WarehouseDetailPage`             |
| `/warehouses/:id/edit`  | `WarehouseFormPage` (edit)        |
| `/products`             | `ProductListPage`                 |
| `/products/lookup`      | `ProductBarcodeLookupPage` (stub) |
| `/products/new`         | `ProductFormPage` (create)        |
| `/products/:id`         | `ProductDetailPage`               |
| `/products/:id/edit`    | `ProductFormPage` (edit)          |

Quick action Dashboard: navigate `/products` (và optional `/products/lookup`).

## API contract (Phase 2)

Base: `API_DEV_URL` + `/api/v1`

| Method | Path                      | Role  | Notes                                                                                      |
| ------ | ------------------------- | ----- | ------------------------------------------------------------------------------------------ |
| GET    | `/warehouses`             | any   | Active warehouses                                                                          |
| POST   | `/warehouses`             | admin | Body: code, name, address?, latitude?, longitude?                                          |
| GET    | `/warehouses/:id`         | any   |                                                                                            |
| PUT    | `/warehouses/:id`         | admin | Partial                                                                                    |
| DELETE | `/warehouses/:id`         | admin | Soft `isActive=false` — **có trong routes, chưa trong API.md** → app Phase 2 **không gọi** |
| GET    | `/products`               | any   | + `units[]`                                                                                |
| POST   | `/products`               | admin | sku, name, … units?                                                                        |
| GET    | `/products/barcode/:code` | any   |                                                                                            |
| GET    | `/products/:id`           | any   |                                                                                            |
| PUT    | `/products/:id`           | admin | Partial; **không** cập nhật units                                                          |
| DELETE | `/products/:id`           | admin | Soft delete `isActive=false`                                                               |

Envelope: `{ success, data }` / `{ success: false, error: { code, message } }`.

## Models

### `Warehouse`

`id`, `tenantId`, `code`, `name`, `address?`, `isActive`, `latitude?`, `longitude?`, `geoSource?`, `geocodeStatus?`, `createdAt`, `updatedAt`.

Parse lat/long: API có thể trả string decimal — normalize sang `double?`.

### `Product`

`id`, `tenantId`, `sku`, `barcode?`, `name`, `baseUnitName`, `trackBatch`, `trackExpiry`, `minStockLevel`, `costingMethod` (`FIFO`\|`FEFO`\|`AVG`), `averageCost`, `isActive`, `units[]`, timestamps.

### `ProductUnit`

`id`, `productId`, `unitName`, `conversionRate`.

## Google Maps

| Platform | Source in KTX                                                                                            | Usage in VIMES                   |
| -------- | -------------------------------------------------------------------------------------------------------- | -------------------------------- |
| Android  | `ktx-app` `AndroidManifest` `com.google.android.geo.API_KEY` = `AIzaSyBKxJEVC_2auoDUoJyvb69xtOL23UfdJEE` | Same meta-data in VIMES Manifest |
| iOS      | `ktx-app` `AppDelegate` `GMSServices.provideAPIKey("AIzaSyDMwLH3wGE_dAnKgJJNfVGoAYoABCuy12a")`           | Same call in VIMES AppDelegate   |

Notes:

- `ktx-be-new` **không** chứa Maps key.
- `ktx-app` `.env` `MAPS_API_KEY` (hex) **không** phải Google Maps SDK key — không dùng cho `google_maps_flutter`.
- Restrict keys theo bundle id / package name của VIMES khi đưa production (keys đang gắn KTX).

Dependency: `google_maps_flutter`.

## UI / Theme

Giữ VIMES tokens Phase 1. List flat full-width (design board: card không boxed shadow). Search bar + badge Active. Detail: map block ~118dp + chips code/status + address/coords rows.

## Error UX

| Case                                   | UX                                        |
| -------------------------------------- | ----------------------------------------- |
| Network / 5xx                          | Snackbar + retry                          |
| 403 FORBIDDEN                          | Toast “Không đủ quyền”                    |
| 404                                    | Empty / pop                               |
| 409 `DUPLICATE_CODE` / `DUPLICATE_SKU` | Field error                               |
| 400 `VALIDATION_ERROR`                 | Form message (vd. FIFO/FEFO + trackBatch) |
| Barcode not found                      | Empty state                               |

## Testing (tối thiểu)

- Unit: Warehouse/Product `fromJson` (lat/long string); `canManageMasterData`
- Bloc: list success/fail; create success; non-admin không expose write events từ UI (guard test)
- Manual: admin CRUD; viewer chỉ đọc; map hiện marker khi có toạ độ; barcode stub

## Success criteria

1. Tab Kho hiển thị list từ API thật.
2. Detail kho + Google Map (keys KTX) hoạt động trên device/simulator có Google Play / iOS maps.
3. Admin tạo/sửa kho; non-admin không thấy nút ghi.
4. Vào `/products` từ Dashboard; list/detail/CRUD (admin) + soft delete.
5. Barcode stub tra đúng API.
6. `X-Tenant-Id` luôn gửi; 403/409 map đúng UX.
7. Không regress Auth / tenant routing.

## Spec self-review

- [x] No TBD placeholders for in-scope decisions
- [x] Warehouse DELETE: routes tồn tại nhưng UI Phase 2 bỏ qua cho đến khi `API.md` sync
- [x] Warehouse assignment: documented as not enforced server-side; client follows API
- [x] RBAC matrix matches `API.md` summary table
- [x] Scope limited to Kho + SP for one implementation plan
