# Phase 1 Auth Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement VIMES Auth Module 01 + Dashboard shell against real Inventory Backend API.

**Architecture:** `AuthBloc` session at root; per-screen Cubits; repository + Dio API aligned with `docs/API.md`; tenant auto-select when exactly one org.

**Tech Stack:** Flutter, flutter_bloc, go_router, dio, firebase_auth + google_sign_in, pinput

**Spec:** `docs/superpowers/specs/2026-08-16-auth-module-design.md`

---

## File map

| Path | Responsibility |
|------|----------------|
| `lib/core/skin/color_skin.dart` | VIMES palette |
| `lib/core/storage/storage_manager.dart` | tenantId, deviceId |
| `lib/core/network/auth_interceptor.dart` | Bearer + X-Tenant-Id + refresh contract |
| `lib/data/datasources/api_endpoints.dart` | Auth paths |
| `lib/data/models/user/user.dart` | Extended user |
| `lib/data/models/tenant/tenant_membership.dart` | Tenant list item |
| `lib/data/models/auth/auth_session.dart` | Login response |
| `lib/data/datasources/api_services/auth_api_service.dart` | HTTP calls |
| `lib/domain/repositories/auth_repository.dart` | Interface |
| `lib/data/repositories/auth_repository_impl.dart` | Impl |
| `lib/domain/usecases/auth/*` | Login, register, otp, google, tenants, device |
| `lib/features/auth/bloc/*` | AuthBloc session |
| `lib/features/auth/cubit/*` | Login/Register/Otp/Tenant cubits |
| `lib/features/auth/pages/*` | UI pages |
| `lib/features/auth/widgets/*` | Shared auth widgets |
| `lib/features/splash/pages/splash_page.dart` | VIMES splash + session resolve |
| `lib/features/home/pages/home_page.dart` | Dashboard shell mock |
| `lib/app/router/app_router.dart` | Routes + redirects |
| `lib/app/app.dart` | Providers |
| `.env` / `.env.example` | Backend URL |
| `test/features/auth/*` | Unit + bloc tests |
| `pubspec.yaml` | Add `firebase_auth` |

---

### Task 1: Theme + env + firebase_auth dependency

**Files:**
- Modify: `lib/core/skin/color_skin.dart`
- Modify: `.env.example`, `.env`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Update ColorSkin primary tokens to VIMES**

Set at minimum:

```dart
static const Color primary = Color(0xFF0E7C86);
static const Color primarySub = Color(0xFF0A5C64);
static const Color secondary1 = Color(0xFFF5A028);
static const Color title = Color(0xFF132B2E);
static const Color subtitle = Color(0xFF5C7478);
static const Color tealLight = Color(0xFFE4F2F1);
static const Color orangeLight = Color(0xFFFDF0DC);
```

Keep other tokens if still used; align `AppTheme` if it hardcodes old green.

- [ ] **Step 2: Point env to local backend**

`.env.example` / `.env`:

```env
APP_ENV=dev
API_DEV_URL=http://localhost:3000
API_PROD_URL=http://localhost:3000
```

Note in README comment: Android emulator → `http://10.0.2.2:3000`.

- [ ] **Step 3: Add firebase_auth**

```bash
cd /Users/huy/Documents/code/test-y-te-flutter && flutter pub add firebase_auth
```

Expected: `pubspec.yaml` contains `firebase_auth`, `flutter pub get` succeeds.

- [ ] **Step 4: Commit**

```bash
git add lib/core/skin/color_skin.dart .env.example pubspec.yaml pubspec.lock
git commit -m "$(cat <<'EOF'
chore: align VIMES theme and add firebase_auth for Google login

EOF
)"
```

Do not commit `.env` if it contains secrets; committing URL-only `.env` is OK if repo already tracks it.

---

### Task 2: Models + storage + endpoints

**Files:**
- Create: `lib/data/models/tenant/tenant_membership.dart`
- Create: `lib/data/models/auth/auth_session.dart`
- Modify: `lib/data/models/user/user.dart`
- Modify: `lib/core/storage/storage_manager.dart`
- Modify: `lib/data/datasources/api_endpoints.dart`
- Test: `test/data/models/auth_session_test.dart`

- [ ] **Step 1: Write failing test for AuthSession / User parsing**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:test_y_app/data/models/auth/auth_session.dart';

void main() {
  test('parses login data with tenants', () {
    final session = AuthSession.fromJson({
      'user': {
        'id': 'u1',
        'email': 'a@b.com',
        'phone': null,
        'name': 'A',
        'emailVerified': true,
        'phoneVerified': false,
        'isPlatformAdmin': false,
      },
      'tenants': [
        {
          'id': 't1',
          'code': 'ACME',
          'name': 'Acme',
          'role': 'admin',
          'status': 'active',
        }
      ],
      'accessToken': 'at',
      'refreshToken': 'rt',
    });
    expect(session.user.email, 'a@b.com');
    expect(session.tenants.single.code, 'ACME');
    expect(session.accessToken, 'at');
  });
}
```

- [ ] **Step 2: Run test — expect FAIL (missing types)**

```bash
flutter test test/data/models/auth_session_test.dart
```

- [ ] **Step 3: Implement models**

`TenantMembership`: `id`, `code`, `name`, `role`, `status?` + `fromJson`.

`User`: add `emailVerified`, `phoneVerified`, `isPlatformAdmin` with defaults in `fromJson`.

`AuthSession`: `user`, `tenants`, `accessToken`, `refreshToken`, `isNewUser?`.

- [ ] **Step 4: Extend StorageManager**

```dart
static const String _tenantIdKey = 'tenant_id';
static const String _deviceIdKey = 'device_id';

Future<void> saveTenantId(String id) async => _storage.write(key: _tenantIdKey, value: id);
Future<String?> getTenantId() async => _storage.read(key: _tenantIdKey);
Future<void> deleteTenantId() async => _storage.delete(key: _tenantIdKey);

Future<String> getOrCreateDeviceId() async {
  final existing = await _storage.read(key: _deviceIdKey);
  if (existing != null && existing.isNotEmpty) return existing;
  final id = /* uuid v4 — use a simple Uuid or DateTime-based unique string */;
  await _storage.write(key: _deviceIdKey, value: id);
  return id;
}
```

Ensure `clearAuthData` also clears `tenant_id` (keep `device_id`).

- [ ] **Step 5: Fix ApiEndpoints**

```dart
static const String authVerifyOtp = '$authBase/verify-otp';
static const String authResendOtp = '$authBase/resend-otp';
static const String authLoginGoogle = '$authBase/login/google';
static const String authRefresh = '$authBase/refresh'; // replace authRefreshToken usages
static const String authMe = '$authBase/me';
static const String authTenants = '$authBase/tenants';
// remove or stop using usersMe = customers/me for auth
```

- [ ] **Step 6: Re-run test — PASS; commit**

```bash
flutter test test/data/models/auth_session_test.dart
git add lib/data/models lib/core/storage/storage_manager.dart lib/data/datasources/api_endpoints.dart test/data/models
git commit -m "$(cat <<'EOF'
feat: add auth session models, tenant storage, and API paths

EOF
)"
```

---

### Task 3: Auth API service + repository + interceptor

**Files:**
- Modify: `lib/data/datasources/api_services/auth_api_service.dart`
- Modify: `lib/domain/repositories/auth_repository.dart`
- Modify: `lib/data/repositories/auth_repository_impl.dart`
- Modify: `lib/core/network/auth_interceptor.dart`
- Modify: `lib/domain/usecases/auth/login_usecase.dart` (+ new use cases)
- Test: `test/features/auth/tenant_routing_test.dart`

- [ ] **Step 1: Write tenant routing unit test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:test_y_app/features/auth/utils/tenant_routing.dart';

void main() {
  test('one tenant -> home with that id', () {
    final r = resolveTenantRoute(
      tenants: [fakeTenant('t1')],
      savedTenantId: null,
    );
    expect(r.destination, TenantDestination.home);
    expect(r.tenantId, 't1');
  });

  test('many without saved -> select', () {
    final r = resolveTenantRoute(
      tenants: [fakeTenant('t1'), fakeTenant('t2')],
      savedTenantId: null,
    );
    expect(r.destination, TenantDestination.selectTenant);
  });

  test('many with valid saved -> home', () {
    final r = resolveTenantRoute(
      tenants: [fakeTenant('t1'), fakeTenant('t2')],
      savedTenantId: 't2',
    );
    expect(r.destination, TenantDestination.home);
    expect(r.tenantId, 't2');
  });

  test('zero -> select', () {
    final r = resolveTenantRoute(tenants: [], savedTenantId: null);
    expect(r.destination, TenantDestination.selectTenant);
  });
}
```

- [ ] **Step 2: Implement `lib/features/auth/utils/tenant_routing.dart` until tests pass**

- [ ] **Step 3: Rewrite AuthApiService methods**

- `login({String? email, String? phone, required String password})` → `AuthSession`
- `loginWithGoogle(String idToken)` → `AuthSession`
- `register(...)` → register result
- `verifyOtp` / `resendOtp`
- `getMe()` → user + tenants (parse `GET /auth/me`)
- `createTenant({code, name})`
- `registerDevice(...)`
- `logout({refreshToken, deviceId?})`
- `refresh({refreshToken})` → new tokens

Parse envelope: if `success == false` throw with `error.message` / code.

- [ ] **Step 4: Update AuthRepository interface + impl**

Replace `credentials` with email/phone detection helper:

```dart
({String? email, String? phone}) splitCredentials(String raw) {
  final v = raw.trim();
  if (v.contains('@')) return (email: v, phone: null);
  return (email: null, phone: v);
}
```

After login: save tokens, user, optionally tenants cache; call `registerDevice`.

- [ ] **Step 5: Fix AuthInterceptor**

- Public paths include verify-otp, resend-otp, login, login/google, refresh, logout, register.
- On request: add `X-Tenant-Id` from storage when present.
- On 401 refresh: `POST /auth/refresh` body `{ "refreshToken": ... }`, read `data.accessToken` / `data.refreshToken` from envelope.

- [ ] **Step 6: Commit**

```bash
git add lib test
git commit -m "$(cat <<'EOF'
feat: wire auth API, repository, tenant routing, and interceptor

EOF
)"
```

---

### Task 4: AuthBloc session + Cubits

**Files:**
- Modify: `lib/features/auth/bloc/auth_bloc.dart`, `auth_event.dart`, `auth_state.dart`
- Create: `lib/features/auth/cubit/login_cubit.dart` (+ state)
- Create: `lib/features/auth/cubit/register_cubit.dart`
- Create: `lib/features/auth/cubit/otp_cubit.dart`
- Create: `lib/features/auth/cubit/tenant_select_cubit.dart`
- Test: `test/features/auth/auth_bloc_test.dart`

- [ ] **Step 1: Expand AuthState**

States such as: `AuthInitial`, `AuthLoading`, `AuthUnauthenticated`, `AuthAuthenticated { user, tenants, selectedTenantId? }`, `AuthNeedsTenant { user, tenants }`, `AuthError`.

- [ ] **Step 2: AuthBloc events**

`AuthCheckRequested`, `AuthSessionEstablished(AuthSession)`, `AuthTenantSelected(String tenantId)`, `AuthLogoutRequested`.

On check: if logged in → `getMe` → `resolveTenantRoute` → emit Authenticated or NeedsTenant; set `AppRouterConfig` auth flags + tenant.

- [ ] **Step 3: Cubits call repository then notify session**

LoginCubit success → `authBloc.add(AuthSessionEstablished(session))`.

- [ ] **Step 4: bloc_test for single-tenant auto home path**

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat: add AuthBloc session and auth flow cubits

EOF
)"
```

---

### Task 5: Router + Splash + Auth UI pages

**Files:**
- Modify: `lib/app/router/app_router.dart`
- Modify: `lib/features/splash/pages/splash_page.dart`
- Modify: `lib/features/auth/pages/login_page.dart`
- Create: `lib/features/auth/pages/register_page.dart`
- Create: `lib/features/auth/pages/verify_otp_page.dart`
- Create: `lib/features/auth/pages/select_tenant_page.dart`
- Create: shared widgets under `lib/features/auth/widgets/` as needed
- Modify: `lib/app/app.dart` if extra providers needed

- [ ] **Step 1: Add routes**

`AppRoutes`: splash, login, register, verifyOtp, selectTenant, home.

Redirect rules from spec.

- [ ] **Step 2: Splash**

VIMES gradient + logo + title; after 1.5s and/or AuthBloc resolved → go login / select-tenant / home.

- [ ] **Step 3: Login UI**

Match design: fields, remember (local prefer), forgot password link = snackbar “Sắp hỗ trợ”, Google button → LoginCubit.google(), link to register.

- [ ] **Step 4: Register + OTP**

Register step 1/2 UI; navigate to OTP with email/phone; `pinput` 6 digits; resend countdown; on success → login page or auto login if product later adds tokens (per spec: go login).

- [ ] **Step 5: Select tenant**

List cards from AuthBloc tenants; on tap → `AuthTenantSelected`; button create org → dialog code+name → API → select new tenant.

- [ ] **Step 6: Manual smoke against backend**

```bash
# terminal 1: backend on :3000
# terminal 2:
flutter run
```

Register → OTP (check email/logs) → login → home or select.

- [ ] **Step 7: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat: build VIMES auth screens and session routing

EOF
)"
```

---

### Task 6: Google Sign-In + register-device

**Files:**
- Create: `lib/features/auth/services/google_auth_service.dart`
- Modify: login cubit / page
- Modify: auth repository post-login device registration

- [ ] **Step 1: GoogleAuthService**

```dart
// GoogleSignIn → GoogleAuthProvider.credential → FirebaseAuth.signInWithCredential → idToken
```

Handle cancel / error.

- [ ] **Step 2: Ensure Firebase.initializeApp in main** (already if messaging used).

- [ ] **Step 3: register-device after every successful session**

Body: `deviceId`, `deviceType` (ios/android), `deviceModel`, `osVersion`, `appVersion`, optional `fcmToken`.

- [ ] **Step 4: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat: enable Google login and device registration after auth

EOF
)"
```

---

### Task 7: Dashboard shell (mock) ✅ DONE

**Files:**
- Modify: `lib/features/home/pages/home_page.dart`
- Optional: `lib/features/home/widgets/*`

- [ ] **Step 1: Replace HomePage with shell**

Scaffold + bottom navigation (5 tabs). Tab 0: mock KPI, quick actions, low-stock list. Other tabs: centered placeholder text.

AppBar/header: tenant name + role from AuthBloc; logout action → `AuthLogoutRequested`.

- [ ] **Step 2: Visual check on device/simulator**

- [ ] **Step 3: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat: add dashboard shell with mock KPIs after tenant select

EOF
)"
```

---

### Task 8: Verification checklist ✅ DONE (analyze info-only; unit tests pass)

- [ ] **Step 1: Analyze**

```bash
flutter analyze
```

Expected: no errors in changed files.

- [ ] **Step 2: Run unit/bloc tests**

```bash
flutter test test/data/models test/features/auth
```

Expected: all pass.

- [ ] **Step 3: End-to-end manual**

1. Backend up on configured URL  
2. Register new user → OTP → login  
3. Create org if 0 tenants → lands Home  
4. Second org (invite or create another account path) → select screen when ≥2  
5. Single-tenant user → skip select  
6. Google login (if Firebase configured)  
7. Kill app → reopen → restores tenant session  

- [ ] **Step 4: Final commit if fixes needed**

---

## Spec coverage check

| Spec item | Task |
|-----------|------|
| VIMES theme | 1 |
| Models / storage / endpoints | 2 |
| API + interceptor + tenant rules | 3 |
| AuthBloc + Cubits | 4 |
| Screens + router + splash | 5 |
| Google + register-device | 6 |
| Dashboard shell | 7 |
| Verify | 8 |
| 1-tenant auto home | 3 + 4 + 5 |
| Forgot password | Out of scope (UI stub only in Task 5) |

## Placeholder scan

No TBD steps; Google requires local Firebase config files (operator action if missing).
