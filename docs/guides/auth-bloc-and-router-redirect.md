# AuthBloc & GoRouter Redirect

Tài liệu giải thích luồng xác thực toàn app: `AuthBloc` (session global) kết hợp `GoRouter.redirect` và điều hướng sau login/logout.

Liên quan code:

- `lib/features/auth/bloc/auth_bloc.dart`
- `lib/app/router/app_router.dart`
- `lib/features/splash/pages/splash_page.dart`
- `lib/app/app.dart`

---

## 1. Hai lớp “cổng” bảo vệ route

Project dùng **hai cơ chế song song**:

| Lớp | Vai trò |
|-----|---------|
| `AuthBloc` | Nguồn sự thật về session: user, tenants, đã chọn org chưa |
| `AppRouterConfig._isAuthenticated` / `_hasTenant` | Cờ nhanh cho `GoRouter.redirect` chặn URL |

`AuthBloc` **cập nhật** cờ router mỗi khi session đổi (`setAuthState`). Redirect đọc cờ đó — không đọc trực tiếp `AuthBloc.state` trong `redirect` (tránh phụ thuộc context Bloc phức tạp).

```
LoginBloc (màn login) ──success──► AuthSessionEstablished
                                         │
                                         ▼
                                   AuthBloc
                                    ├─ emit AuthAuthenticated / AuthNeedsTenant
                                    ├─ setAuthState(true, hasTenant: ...)
                                    └─ goHome() / goSelectTenant()
                                         │
                                         ▼
                              GoRouter.redirect (lần navigate sau)
```

---

## 2. Phạm vi sống (scope)

```dart
// app.dart — sống cả vòng đời app
MultiBlocProvider(
  providers: [
    BlocProvider<AuthBloc>(
      create: (_) => AuthBloc(authRepository: _authRepository),
    ),
  ],
  child: MaterialApp.router(...),
);
```

| Bloc | Scope | Khi nào tạo/hủy |
|------|-------|-----------------|
| `AuthBloc` | Toàn app | Tạo khi app start; hủy khi app tắt |
| `LoginBloc` | Chỉ route `/login` | Tạo khi vào login; hủy khi rời |

Constructor `AuthBloc` mặc định tự `add(AuthCheckRequested)` → kiểm tra phiên ngay khi app mở.

---

## 3. State machine của `AuthState`

```
AuthInitial
    │
    ▼
AuthLoading  ←── đang check / login
    │
    ├──► AuthAuthenticated   (đã login + đã có tenant)
    ├──► AuthNeedsTenant     (đã login, chưa chọn / chưa có org mặc định)
    ├──► AuthUnauthenticated (chưa login / logout / token hết hạn)
    └──► AuthError           (lỗi nghiệp vụ)
```

| State | Ý nghĩa UI / điều hướng |
|-------|-------------------------|
| `AuthAuthenticated` | Vào `/home` |
| `AuthNeedsTenant` | Vào `/select-tenant` |
| `AuthUnauthenticated` | Vào `/login` |
| `AuthLoading` | Splash chờ / hiện loading |

`sealed class` + pattern matching (`state is AuthAuthenticated`, `switch`) giúp compiler bắt thiếu nhánh.

---

## 4. Events — UI / hệ thống “ra lệnh” gì?

| Event | Ai gửi | Việc Bloc làm |
|-------|--------|---------------|
| `AuthCheckRequested` | Tự gửi khi tạo Bloc | Đọc local/API `isLoggedIn` + `getMe` |
| `AuthLoginRequested` | (ít dùng trực tiếp; login qua `LoginBloc`) | LoginUseCase rồi `_emitAfterSession` |
| `AuthSessionEstablished` | `LoginPage` sau `LoginSuccess` | Nhận session từ `LoginBloc`, route tenant |
| `AuthTenantSelected` | `SelectTenantPage` | Lưu tenant, `goHome` |
| `AuthLogoutRequested` | Home / SelectTenant | Logout, `goLogin` |

**Vì sao tách `LoginBloc` và `AuthBloc`?**

- `LoginBloc`: form loading/error của **một màn** (email/password, Google).
- `AuthBloc`: session **toàn app** + điều hướng sau khi đã có session.

Login thành công:

```dart
// login_page.dart — listener
context.read<AuthBloc>().add(AuthSessionEstablished(state.session));
```

---

## 5. `_emitAfterSession` — trái tim sau khi có session

```dart
Future<void> _emitAfterSession(AuthSession session, Emitter<AuthState> emit) async {
  final saved = await _authRepository.getSelectedTenantId();
  final route = resolveTenantRoute(tenants: session.tenants, savedTenantId: saved);

  if (route.destination == TenantDestination.home && route.tenantId != null) {
    await _authRepository.selectTenant(route.tenantId!);
    AppRouterConfig.instance.setAuthState(true, hasTenant: true);
    emit(AuthAuthenticated(...));
    _safeNavigate(() => AppRouterConfig.instance.goHome());
  } else {
    AppRouterConfig.instance.setAuthState(true, hasTenant: false);
    emit(AuthNeedsTenant(...));
    _safeNavigate(() => AppRouterConfig.instance.goSelectTenant());
  }
}
```

Thứ tự cố định:

1. Quyết định tenant (có org đã lưu / chỉ 1 org → home, ngược lại → chọn).
2. `setAuthState` — cập nhật cờ cho redirect.
3. `emit` state mới — UI lắng nghe được.
4. `goHome` / `goSelectTenant` — điều hướng chủ động.

`_safeNavigate` bọc try/catch: lúc test hoặc router chưa sẵn sàng thì không crash Bloc.

---

## 6. `GoRouter.redirect` — chặn URL thủ công / deep link

```dart
redirect: (context, state) {
  final location = state.matchedLocation;
  final isSplash = location == AppRoutes.splash.path;
  final isAuthFlow = location == login || register || verifyOtp;

  if (isSplash) return null; // splash tự quyết định

  // Chưa login mà vào home / select-tenant → login
  if (!_isAuthenticated && (home || selectTenant)) {
    return AppRoutes.login.path;
  }

  // Đã login nhưng chưa tenant mà vào home → chọn tenant
  if (_isAuthenticated && !_hasTenant && location == home) {
    return AppRoutes.selectTenant.path;
  }

  // Đã login + có tenant mà còn loanh quanh auth flow → home
  if (_isAuthenticated && _hasTenant && isAuthFlow) {
    return AppRoutes.home.path;
  }

  return null; // không redirect
},
```

`return null` = cho phép đi tiếp. `return '/path'` = đổi đích.

### Bảng quyết định nhanh

| Đã auth? | Có tenant? | Đang ở | Redirect tới |
|----------|------------|--------|--------------|
| Không | — | `/home`, `/select-tenant` | `/login` |
| Có | Không | `/home` | `/select-tenant` |
| Có | Có | `/login`, `/register`, `/verify-otp` | `/home` |
| — | — | `/` (splash) | không (null) |

---

## 7. Splash — chờ AuthBloc rồi mới `go`

Splash **không** dựa redirect; tự lắng nghe stream:

```dart
// initState → post-frame
_authSub = authBloc.stream.listen(_tryNavigate);
_minDelay = Timer(1500ms, () { _minDelayDone = true; _tryNavigate(...); });
```

Điều kiện mới navigate:

1. Đã chờ tối thiểu ~1.5s (branding).
2. State không còn `AuthInitial` / `AuthLoading` (hoặc timeout phụ).
3. Chỉ navigate **một lần** (`_navigated` flag).

`dispose` hủy subscription + timer — đúng lifecycle (xem guide lifecycle).

---

## 8. Truyền message sang Login (extra / query)

```dart
void goLogin({String? message}) {
  if (message != null && message.isNotEmpty) {
    router.go(AppRoutes.login.path, extra: {'message': message});
  } else {
    router.go(AppRoutes.login.path);
  }
}
```

Route builder đọc `state.extra` hoặc `queryParameters` → `LoginPage(infoMessage: message)`.

Đây là cách truyền “props” qua navigation (tương đương `location.state` / search params trên web).

---

## 9. So với React mental model

| Flutter (project) | React / SPA |
|-------------------|-------------|
| `AuthBloc` | Auth context / Zustand auth store |
| `setAuthState` + `redirect` | ProtectedRoute / loader redirect |
| `AuthSessionEstablished` | `setSession` sau login API |
| Splash chờ stream | Bootstrap screen chờ `getMe` |
| `LoginBloc` scope route | Page-level form state |

---

## 10. Checklist khi thêm màn mới cần auth

- [ ] Route thêm vào `AppRoutes` + `GoRoute`
- [ ] Nếu cần bảo vệ: cập nhật điều kiện trong `redirect`
- [ ] Đọc session: `context.read<AuthBloc>().state` hoặc `BlocBuilder`
- [ ] Logout: `add(const AuthLogoutRequested())` — để Bloc lo `setAuthState` + `goLogin`
- [ ] Không tự `setAuthState` từ UI — chỉ `AuthBloc` được quyền đó

---

## Tài liệu liên quan

- [Widget Lifecycle](./flutter-widget-lifecycle.md)
- [Bloc patterns](./flutter-bloc-patterns.md)
- [Cheat sheet](./flutter-cheat-sheet.md)
