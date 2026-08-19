# Phase 1 — Auth Module (VIMES) Design Spec

> **Status:** Approved by product owner (2026-08-16)  
> **Sources:** Design board `VIMES-Inventory-UI-Design-Board`, Backend `test-y-Backend/docs/API.md`, app `test_y_app`

## Goal

Xây dựng Module 01 (Xác thực & Khởi động) theo UI VIMES, gọi API thật của Inventory Backend, kèm shell Dashboard (mock) sau khi chọn tổ chức — nền tảng cho các phase kho sau.

## Decisions

| Topic | Choice |
|-------|--------|
| Scope | Module 01 Auth + Dashboard shell |
| Data | Real API (`/api/v1`) theo `API.md` |
| Google login | Full: Google Sign-In → Firebase ID token → `POST /auth/login/google` |
| After tenant | Dashboard shell (bottom nav + KPI mock) |
| 1 tenant | Auto-select → Dashboard (skip select screen) |
| 0 tenants | Select screen + create org |
| ≥2 tenants | Select screen required |
| Approach | `AuthBloc` (session) + Cubits per flow |

## Out of scope (Phase 1)

- Module 03–10 (warehouse, products, receipts, reports, …) real APIs
- Forgot password (không có trong API)
- Accept invitation deep-link flow đầy đủ
- Platform-admin tenant APIs
- Dashboard KPI / phiếu chờ duyệt từ API thật

## Architecture

```
UI (features/auth, splash, home shell)
  → Cubit / AuthBloc
    → Use cases
      → AuthRepository
        → AuthApiService (Dio)
          → Backend /api/v1/auth/*
StorageManager: accessToken, refreshToken, user, tenantId, deviceId
AuthInterceptor: Bearer + X-Tenant-Id (khi có tenant)
```

### Session vs flow state

- **`AuthBloc` (root `BlocProvider`):** check session, authenticated user, selected tenant, logout, post-login device register, navigate after auth success.
- **`LoginBloc` / `RegisterBloc` / `OtpBloc` / `TenantSelectBloc`:** UI state + API cho từng màn (Event/State); success thì emit event lên `AuthBloc` hoặc router quyết định.

### Tenant routing rules

Sau khi có `accessToken` + danh sách `tenants`:

1. `tenants.isEmpty` → `/select-tenant` (hiện nút tạo tổ chức)
2. `tenants.length == 1` → lưu `tenantId`, set auth state → `/home`
3. `tenants.length >= 2` → nếu `tenantId` đã lưu vẫn nằm trong list → `/home`; ngược lại → `/select-tenant`

Splash / cold start: nếu đã login, gọi `GET /auth/me` để refresh tenants rồi áp dụng cùng rules.

## User flows

### Register → OTP → Login → Tenant → Home

1. `POST /auth/register` `{ email|phone, password, name? }` → `requiresVerification: true`
2. Navigate `/verify-otp` với email/phone
3. `POST /auth/verify-otp` `{ email|phone, code }` → verified
4. User đăng nhập (`POST /auth/login`) nếu chưa có token từ bước trước (API verify-otp hiện chỉ trả `{ verified: true }` → **bắt buộc login sau OTP**)
5. Lưu tokens → `POST /auth/register-device` → resolve tenant → Home / Select

### Login (email/phone)

1. Parse input: chứa `@` → `email`, else → `phone`
2. `POST /auth/login` `{ email|phone, password }`
3. Lưu `accessToken`, `refreshToken`, user, tenants
4. `register-device` → tenant rules → Home / Select

### Google

1. Google Sign-In + Firebase Auth → `idToken`
2. `POST /auth/login/google` `{ idToken }`
3. Giống login password từ bước lưu token trở đi

### Create organization

Trên `/select-tenant`: `POST /auth/tenants` `{ code, name }` (yêu cầu đã verify) → refresh me/tenants → auto vào Home (vì vừa tạo, thường chỉ có 1 hoặc tenant mới được chọn).

## Routes

| Path | Page |
|------|------|
| `/` | `SplashPage` (VIMES branding, ~1.5s rồi resolve session) |
| `/login` | `LoginPage` |
| `/register` | `RegisterPage` |
| `/verify-otp` | `VerifyOtpPage` (extra: email/phone) |
| `/select-tenant` | `SelectTenantPage` |
| `/home` | `HomeShellPage` (Dashboard skeleton) |

Redirect: chưa auth mà vào `/home` hoặc `/select-tenant` → `/login`. Đã auth + đã tenant mà vào `/login` → `/home`.

## API contract (Phase 1)

Base: `API_DEV_URL` (local mặc định `http://localhost:3000`) + paths `/api/v1/...`

| Method | Path | Notes |
|--------|------|-------|
| POST | `/auth/register` | Public |
| POST | `/auth/verify-otp` | Public |
| POST | `/auth/resend-otp` | Public |
| POST | `/auth/login` | Public; body email\|phone |
| POST | `/auth/login/google` | Public |
| POST | `/auth/register-device` | Bearer |
| POST | `/auth/refresh` | Public; body `{ refreshToken }` — **đổi từ** `auth/refresh-token` cũ |
| POST | `/auth/logout` | Body `{ refreshToken, deviceId? }` |
| GET | `/auth/me` | Bearer — **đổi từ** `/customers/me` |
| POST | `/auth/tenants` | Bearer; create org |

Response envelope: `{ success, data }` / `{ success: false, error: { code, message } }`.

## Models

### `User`

Fields: `id`, `email?`, `phone?`, `name?`, `emailVerified`, `phoneVerified`, `isPlatformAdmin`.

### `TenantMembership`

Fields: `id`, `code`, `name`, `role` (`TenantRole`), `status?`.

### `AuthSession` (login response data)

`user`, `tenants`, `accessToken`, `refreshToken`, `isNewUser?` (Google).

## Storage keys (add)

- `tenant_id`
- `device_id` (UUID sinh 1 lần / install)
- Keep: `access_token`, `refresh_token`, `user_info`

## Network

- `AuthInterceptor`: gắn `Authorization: Bearer` trừ public auth paths; gắn `X-Tenant-Id` khi đã chọn tenant.
- Refresh: `POST /auth/refresh` với body `refreshToken` (sửa interceptor hiện đang lệch contract).
- Public paths: register, verify-otp, resend-otp, login, login/google, refresh, logout.

## UI / Theme

Cập nhật `ColorSkin` theo VIMES:

| Token | Hex |
|-------|-----|
| primary / teal | `#0E7C86` |
| primary dark | `#0A5C64` |
| teal light | `#E4F2F1` |
| secondary / orange | `#F5A028` |
| orange light | `#FDF0DC` |
| ink | `#132B2E` |
| ink soft | `#5C7478` |

Màn hình bám layout design board (logo splash, form login, progress register, OTP 6 ô `pinput`, list card tenant, tabbar shell).

## Dashboard shell (mock)

- Bottom nav: Tổng quan / Kho / Phiếu / Báo cáo / Tôi (labels theo design; tab nội dung ngoài “Tổng quan” có thể placeholder text).
- Tab Tổng quan: KPI cards + quick actions + list “sắp hết hàng” **mock cứng** (không gọi API).
- Header hiện tên tenant đang chọn + role badge.

## Dependencies

Đã có: `flutter_bloc`, `go_router`, `dio`, `google_sign_in`, `firebase_core`, `pinput`, `device_info_plus`, `package_info_plus`.

Cần thêm: `firebase_auth` (lấy Firebase ID token cho Google).

Cấu hình Firebase: `google-services.json` / `GoogleService-Info.plist` + `flutterfire configure` nếu chưa.

## Error UX

- Map `error.code` → snackbar / inline message (`INVALID_CREDENTIALS`, `EMAIL_EXISTS`, `INVALID_OTP`, `EMAIL_NOT_VERIFIED`, `GOOGLE_AUTH_DISABLED`, …).
- Loading: disable button + spinner theo design (teal–orange).

## Testing (tối thiểu Phase 1)

- Unit: parse email vs phone; tenant routing rules (0/1/many + cached tenant).
- Bloc/Cubit tests: login success/fail; OTP verify; auto-select single tenant.
- Không bắt buộc golden UI tests trong phase này.

## Env

```env
APP_ENV=dev
API_DEV_URL=http://localhost:3000
API_PROD_URL=https://<prod-host>
```

iOS simulator → Mac localhost OK; Android emulator dùng `http://10.0.2.2:3000`.

## Success criteria

1. Splash VIMES → login theo design.
2. Register → OTP → login → đúng tenant rules.
3. Google login hoạt động khi Firebase + backend Google auth bật.
4. Multi-tenant chọn được; 1 tenant vào Home luôn.
5. `X-Tenant-Id` được gửi sau khi chọn tenant.
6. Dashboard shell hiển thị mock + có thể logout về login.
7. `.env` trỏ backend thật; không còn phụ thuộc JSONPlaceholder cho auth.
