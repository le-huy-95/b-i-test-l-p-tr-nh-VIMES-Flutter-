# Select Tenant — Refresh List & Logo Upload Design Spec

> **Status:** Draft — pending product review  
> **Date:** 2026-08-17  
> **Sources:** Backend `test-y-Backend/docs/API.md`, Flutter `select_tenant_page.dart`, auth module spec

## Goal

Cải thiện màn **Chọn tổ chức**:

1. Khi vào màn, gọi API lấy danh sách tổ chức mà user đang có vai trò (membership).
2. Form **Tạo tổ chức** thêm trường chọn logo (chỉ thư viện ảnh).
3. Nếu user không chọn logo → upload logo mặc định `lib/assets/image/app_icon_foreground.png`.
4. Hiển thị logo trên card danh sách tổ chức.

## Decisions

| Topic | Choice |
|-------|--------|
| Nguồn danh sách tenants | `GET /auth/me` khi vào màn (refresh), fallback dữ liệu từ `AuthBloc` lúc khởi tạo |
| Kiến trúc | `TenantSelectBloc` gọi repository trực tiếp (Cách A) |
| Chọn logo | **Chỉ thư viện ảnh** (`ImagePicker` + `ImageSource.gallery`) |
| Logo mặc định | Asset `lib/assets/image/app_icon_foreground.png` — copy bytes ra temp file rồi multipart upload |
| Tạo tenant API | `POST /auth/tenants` `{ code, name }` |
| Upload logo API | `POST /tenants/current/logo` sau khi tạo, cần `X-Tenant-Id` |
| Upload logo lỗi | Tenant vẫn được tạo; snackbar cảnh báo; vẫn auto-select tenant mới |
| Hiển thị logo list | `logoUrl` từ API → `Image.network`; null → asset mặc định |

## Backend API Reference

### Lấy danh sách tổ chức

`GET /api/v1/auth/me` — Bearer token

Response `data.tenants[]`:

```json
{
  "id": "tenant-id",
  "code": "ACME",
  "name": "Acme Corp",
  "logoUrl": "http://.../logo.png",
  "role": "admin"
}
```

### Tạo tổ chức

`POST /api/v1/auth/tenants` — Bearer token, email/phone đã verify

Body: `{ "code": "...", "name": "..." }`

Response 201: Tenant object (`logoUrl: null` ban đầu).

### Upload logo

`POST /api/v1/tenants/current/logo` — Bearer + `X-Tenant-Id`

- Content-Type: `multipart/form-data`
- Field: `logo` (JPEG, PNG, WebP, GIF — max 2MB)
- Role: `admin` (user tạo tenant là admin)

## Architecture

```
SelectTenantPage
  → TenantSelectBloc
    → AuthRepository
      → AuthApiService.getMe()           // refresh list
      → AuthApiService.createTenant()    // step 1
      → StorageManager.saveTenantId()    // set X-Tenant-Id
      → TenantApiService.uploadLogo()    // step 2 multipart
```

### Luồng tạo tổ chức có logo

```
User nhập code + name (+ optional logo từ gallery)
  → POST /auth/tenants
  → saveTenantId(newTenant.id)
  → resolve logo file:
       user picked? → XFile path
       else         → copy asset app_icon_foreground.png → temp file
  → POST /tenants/current/logo (multipart)
  → emit TenantSelectCreated
  → AuthBloc AuthTenantSelected(newTenant.id)
```

## Data Model Changes

### `TenantMembership`

Thêm field:

```dart
final String? logoUrl;
```

Parse từ JSON `logoUrl`. Cập nhật `fromJson` / `toJson` / `props` nếu có Equatable.

## Repository & API Layer

### `ApiEndpoints`

```dart
static const String tenantsCurrentLogo = '$baseApi/tenants/current/logo';
```

### `TenantApiService` (mới) hoặc method trong `AuthApiService`

```dart
Future<TenantMembership> uploadTenantLogo({required String filePath});
```

- Dùng `FormData` + `MultipartFile.fromFile`
- Field name: `logo`
- Decode response → `TenantMembership` (có `logoUrl`)

### `BaseApiService`

Thêm `postMultipartRequest<T>()` tái sử dụng error handling hiện có.

### `AuthRepository`

```dart
Future<List<TenantMembership>> fetchMyTenants();
Future<TenantMembership> createTenantWithLogo({
  required String code,
  required String name,
  String? logoFilePath, // null → dùng asset mặc định
});
```

`createTenantWithLogo` implementation:

1. `createTenant(code, name)`
2. `selectTenant(created.id)` — persist tenantId cho interceptor
3. Resolve file path (user hoặc default asset via `rootBundle` + temp dir)
4. `uploadTenantLogo(filePath)`
5. On upload failure: log + return `created` (logoUrl null), caller shows warning
6. On upload success: return tenant with `logoUrl`

### Default logo helper

```dart
// core/assets/default_tenant_logo.dart
Future<String> resolveDefaultTenantLogoPath();
```

- Load `lib/assets/image/app_icon_foreground.png` từ asset bundle
- Ghi vào `Directory.systemTemp` với tên `default_tenant_logo.png`
- Trả path cho multipart upload

## Bloc Changes

### Events

| Event | Mô tả |
|-------|--------|
| `TenantSelectRefreshRequested` | Gọi khi page mount — fetch `GET /auth/me` |
| `TenantSelectCreateRequested` | Thêm `String? logoFilePath` |

### States

Giữ pattern hiện tại, thêm phân biệt loading:

| State | UI |
|-------|-----|
| `TenantSelectInitial` | Có thể có tenants từ AuthBloc |
| `TenantSelectRefreshing` | Spinner toàn màn hoặc overlay list |
| `TenantSelectLoading` | Đang tạo tenant (disable nút + list) |
| `TenantSelectCreated` | Success → listener chọn tenant |
| `TenantSelectFailure` | Snackbar lỗi |

### Handler `_onRefreshRequested`

1. `emit(TenantSelectRefreshing(tenants: current))`
2. `fetchMyTenants()`
3. Success → `emit(TenantSelectInitial(tenants: fresh))`
4. Failure → `emit(TenantSelectFailure(...))` + giữ list cũ

### Page init

```dart
TenantSelectBloc(...)..add(const TenantSelectRefreshRequested())
```

## UI Changes

### Danh sách `_TenantCard`

- Thay icon `Icons.apartment_outlined` bằng avatar 48×48:
  - `tenant.logoUrl != null` → `ClipRRect` + `Image.network` + `errorBuilder` fallback asset
  - else → `Image.asset('lib/assets/image/app_icon_foreground.png')`

### Form tạo tổ chức `_CreateTenantFormFields`

Thêm vùng logo phía trên form:

```
┌──────────────────────────────┐
│  [preview 72×72]  Chọn logo  │  tap → ImagePicker gallery
│                   (Tuỳ chọn) │
└──────────────────────────────┘
```

- Preview mặc định: asset ViMES
- User chọn ảnh → preview cập nhật, lưu `XFile.path` nội bộ state
- Validate kích thước ≤ 2MB trước khi submit (client-side)
- Return record: `({ String code, String name, String? logoFilePath })`

### Loading UX

- Lần đầu vào màn: hiện `CircularProgressIndicator` centered nếu `TenantSelectRefreshing` và list rỗng
- Có data cũ: giữ list, hiện indicator nhỏ trên AppBar hoặc overlay mờ (optional — ưu tiên giữ list + disable tap)

## Error Handling

| Case | Hành vi |
|------|---------|
| Refresh fail | Snackbar + giữ tenants từ AuthBloc |
| Create fail (409 code trùng) | Snackbar message từ API |
| Create OK, upload fail | Snackbar "Tạo tổ chức thành công nhưng chưa upload được logo" |
| Logo quá lớn / sai định dạng | Validate client + hiển thị lỗi API nếu server reject |

## Out of Scope

- Chụp camera chọn logo
- Chỉnh sửa/crop ảnh trước upload
- Xóa/thay logo sau khi tạo (màn settings tenant)
- Pull-to-refresh (có thể thêm sau)

## Testing

| Test | Mô tả |
|------|--------|
| `TenantMembership.fromJson` | Parse `logoUrl` |
| `TenantSelectBloc` refresh | Mock repo → emit Initial với list mới |
| `TenantSelectBloc` create | Mock create + upload → TenantSelectCreated |
| `createTenantWithLogo` | Upload fail vẫn trả tenant created |
| Widget (optional) | Card hiển thị network vs asset fallback |

## Files to Change (implementation)

| File | Change |
|------|--------|
| `tenant_membership.dart` | + `logoUrl` |
| `api_endpoints.dart` | + logo endpoint |
| `base_api_service.dart` | + multipart POST |
| `tenant_api_service.dart` | new |
| `auth_repository.dart` / `auth_repository_impl.dart` | fetch + createWithLogo |
| `tenant_select_event.dart` | refresh event, logo path |
| `tenant_select_state.dart` | refreshing state |
| `tenant_select_bloc.dart` | handlers |
| `select_tenant_page.dart` | UI logo picker + card avatar |
| `core/assets/default_tenant_logo.dart` | helper (new) |

## Acceptance Criteria

1. Vào màn Chọn tổ chức → gọi `GET /auth/me`, hiển thị danh sách tenants + role.
2. Card hiển thị logo từ `logoUrl` hoặc logo ViMES mặc định.
3. Tạo tổ chức không chọn ảnh → upload asset `app_icon_foreground.png` lên API.
4. Tạo tổ chức có chọn ảnh từ gallery → upload ảnh user.
5. Sau tạo thành công → auto chọn tenant mới, vào Home (giữ hành vi hiện tại).
6. Không crash bottom sheet / TextEditingController (fix trước đó giữ nguyên).
