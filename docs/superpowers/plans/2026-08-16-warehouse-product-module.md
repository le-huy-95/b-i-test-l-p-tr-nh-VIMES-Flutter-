# Phase 2 Warehouse + Product Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement VIMES Module 03 (Kho) + Module 04 (Sản phẩm) against real Inventory Backend API, with Google Maps on warehouse detail and admin-only master-data writes.

**Architecture:** Feature modules `warehouse` / `product` with Bloc per screen; repositories + Dio via existing `BaseApiService` + `AuthInterceptor`; Home tab Kho + Dashboard quick action → products; RBAC via `canManageMasterData(role)`.

**Tech Stack:** Flutter, flutter_bloc, go_router, dio, google_maps_flutter, equatable

**Spec:** `docs/superpowers/specs/2026-08-16-warehouse-product-module-design.md`

---

## File map

| Path | Responsibility |
|------|----------------|
| `lib/core/auth/tenant_permissions.dart` | `canManageMasterData` |
| `lib/data/models/warehouse/warehouse.dart` | Warehouse model |
| `lib/data/models/product/product.dart` | Product + ProductUnit |
| `lib/data/datasources/api_endpoints.dart` | Paths |
| `lib/data/datasources/api_services/warehouse_api_service.dart` | HTTP warehouses |
| `lib/data/datasources/api_services/product_api_service.dart` | HTTP products |
| `lib/domain/repositories/warehouse_repository.dart` | Interface |
| `lib/domain/repositories/product_repository.dart` | Interface |
| `lib/data/repositories/warehouse_repository_impl.dart` | Impl |
| `lib/data/repositories/product_repository_impl.dart` | Impl |
| `lib/features/warehouse/bloc/*` | List / Detail / Form blocs |
| `lib/features/warehouse/pages/*` | List, detail, form pages |
| `lib/features/product/bloc/*` | List / Detail / Form / Lookup blocs |
| `lib/features/product/pages/*` | List, detail, form, lookup pages |
| `lib/app/router/app_router.dart` | Routes |
| `lib/app/app.dart` | Repository providers |
| `lib/features/home/pages/home_page.dart` | Tab Kho + quick actions |
| `android/.../AndroidManifest.xml` | Maps API key |
| `ios/Runner/AppDelegate.swift` | `GMSServices.provideAPIKey` |
| `pubspec.yaml` | `google_maps_flutter` |
| `test/core/auth/tenant_permissions_test.dart` | RBAC unit |
| `test/data/models/warehouse_product_test.dart` | Model parse |

---

### Task 1: Permissions + models + endpoints + tests

**Files:**
- Create: `lib/core/auth/tenant_permissions.dart`
- Create: `lib/data/models/warehouse/warehouse.dart`
- Create: `lib/data/models/product/product.dart`
- Modify: `lib/data/datasources/api_endpoints.dart`
- Create: `test/core/auth/tenant_permissions_test.dart`
- Create: `test/data/models/warehouse_product_test.dart`

- [x] **Step 1: Add `canManageMasterData`**

```dart
bool canManageMasterData(String role) => role == 'admin';
```

- [x] **Step 2: Add Warehouse / Product models with `fromJson` that parse lat/long / decimals as string or num**

- [x] **Step 3: Extend ApiEndpoints**

```dart
static const String warehouses = '$baseApi/warehouses';
static String warehouse(String id) => '$warehouses/$id';
static const String products = '$baseApi/products';
static String product(String id) => '$products/$id';
static String productByBarcode(String code) => '$products/barcode/$code';
```

- [x] **Step 4: Unit tests for permissions + model parse; run `flutter test test/core/auth test/data/models/warehouse_product_test.dart`**

- [ ] **Step 5: Commit** (only if user requested commits)

---

### Task 2: API services + repositories + DI

**Files:**
- Create warehouse/product api services + repository interfaces/impls
- Modify: `lib/app/app.dart`

- [x] **Step 1: WarehouseApiService** — list/get/create/update (no delete)
- [x] **Step 2: ProductApiService** — list/get/create/update/delete/getByBarcode
- [x] **Step 3: Repositories thin wrap services**
- [x] **Step 4: Register in `BaseApp` MultiRepositoryProvider**

---

### Task 3: Warehouse feature (list / detail+map / form)

**Files:** `lib/features/warehouse/**`

- [x] **Step 1: WarehouseListBloc + page** (search filter client-side; admin `+`)
- [x] **Step 2: WarehouseDetailBloc + page with GoogleMap**
- [x] **Step 3: WarehouseFormBloc + page** (create/edit; admin-only route guard)
- [x] **Step 4: Embed list in Home tab Kho**

---

### Task 4: Product feature (list / detail / form / barcode stub)

**Files:** `lib/features/product/**`

- [x] **Step 1: ProductListBloc + page**
- [x] **Step 2: ProductDetailBloc + page** (admin edit/delete)
- [x] **Step 3: ProductFormBloc + page**
- [x] **Step 4: ProductBarcodeLookupBloc + page** (text field stub)

---

### Task 5: Router + Maps keys + Home wiring + verify

**Files:**
- Modify: `lib/app/router/app_router.dart`
- Modify: `lib/features/home/pages/home_page.dart`
- Modify: Android Manifest, iOS AppDelegate
- Modify: `pubspec.yaml` (`flutter pub add google_maps_flutter`)

- [x] **Step 1: Add routes** `/warehouses/...`, `/products/...` with BlocProviders
- [x] **Step 2: Wire Home tab + quick actions with `go_router` / `context.push`**
- [x] **Step 3: Inject Maps keys from ktx-app**
- [x] **Step 4: `flutter analyze` on changed paths; run unit tests**

---

## Spec coverage

| Spec item | Task |
|-----------|------|
| RBAC admin-only write | 1, 3, 4 |
| Warehouse CRUD (no delete UI) | 2, 3 |
| Product CRUD + soft delete | 2, 4 |
| Barcode stub | 4 |
| Google Maps + keys | 3, 5 |
| Navigation tab Kho + QA products | 5 |
| List all warehouses (no client scope filter) | 3 |

## Placeholder scan

No TBD steps; warehouse DELETE intentionally omitted from app.
