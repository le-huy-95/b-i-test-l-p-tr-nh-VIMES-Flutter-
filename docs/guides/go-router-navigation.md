# GoRouter & Navigation

Hướng dẫn điều hướng trong project: `AppRoutes`, `go` / `push`, truyền `extra` / query, gắn `BlocProvider` theo route, helper trên `AppRouterConfig`.

Liên quan code: `lib/app/router/app_router.dart`, `lib/app/app.dart`.

---

## 1. Gắn router vào app

```dart
MaterialApp.router(
  routerConfig: AppRouterConfig.instance.router,
  ...
);
```

- Dùng `MaterialApp.router` (không phải `home:` + `routes:` cổ điển).
- `AppRouterConfig.instance` = singleton giữ `GoRouter` + cờ auth cho `redirect`.

---

## 2. Khai báo path bằng enum

```dart
enum AppRoutes {
  splash('/'),
  login('/login'),
  register('/register'),
  verifyOtp('/verify-otp'),
  selectTenant('/select-tenant'),
  home('/home');

  const AppRoutes(this.path);
  final String path;
}
```

**Vì sao enum?** Tránh typo string rải rác; IDE autocomplete; đổi path một chỗ.

Dùng:

```dart
context.go(AppRoutes.register.path);
router.go(AppRoutes.home.path);
```

---

## 3. `GoRoute` — map path → widget

```dart
GoRoute(
  path: AppRoutes.login.path,
  builder: (context, state) {
    // đọc tham số từ state
    return BlocProvider(
      create: (context) => LoginBloc(...),
      child: LoginPage(infoMessage: message),
    );
  },
),
```

| Tham số builder | Ý nghĩa |
|-----------------|---------|
| `context` | BuildContext của route |
| `state` | `GoRouterState` — path, query, extra, matchedLocation |

Pattern hay dùng trong project: **tạo page Bloc ngay trong `builder`** → Bloc sống/chết theo route.

---

## 4. `go` vs `push` vs `replace`

| API | Hành vi stack | Khi nào dùng trong app |
|-----|---------------|-------------------------|
| `context.go('/home')` | Thay location (không giữ stack auth) | Login → home, logout → login |
| `context.push('/x')` | Push lên stack, có thể `pop` | Chi tiết / modal-flow (ít dùng auth) |
| `context.replace('/x')` | Thay entry hiện tại | Ít dùng |

Auth flow project ưu tiên **`go`**: sau login không muốn back về form login bằng nút back hệ thống theo kiểu stack cũ.

Từ UI:

```dart
context.go(AppRoutes.register.path);
```

Từ Bloc / không có `BuildContext` widget:

```dart
AppRouterConfig.instance.goHome();
AppRouterConfig.instance.goLogin(message: '...');
```

---

## 5. Truyền dữ liệu giữa màn

### A. `extra` (object theo lần navigate)

```dart
router.go(
  AppRoutes.login.path,
  extra: {'message': 'Đăng ký thành công'},
);
```

Đọc:

```dart
final extra = state.extra;
if (extra is Map) {
  message = extra['message']?.toString();
}
```

- Không nằm trên URL → refresh web có thể mất.
- Phù hợp message tạm, object phức tạp.

### B. Query parameters (nằm trên URL)

```dart
// ví dụ: /verify-otp?email=a@b.com
state.uri.queryParameters['email']
```

Project hỗ trợ **cả hai**: ưu tiên/gộp `extra` và query (OTP, login message).

### C. Path parameters (nếu thêm sau)

```dart
GoRoute(path: '/orders/:id', ...)
state.pathParameters['id']
```

Hiện auth routes chưa dùng path param.

---

## 6. Helper trên `AppRouterConfig`

```dart
void goLogin({String? message}) { ... }
void goHome() => router.go(AppRoutes.home.path);
void goSelectTenant() => router.go(AppRoutes.selectTenant.path);
void goRegister() => router.go(AppRoutes.register.path);
void goVerifyOtp({String? email, String? phone}) { ... }
```

**Lợi ích:** Bloc gọi navigation không import từng path; truyền `extra` đúng format một chỗ.

`AuthBloc` dùng helper này sau session/logout (`_safeNavigate`).

---

## 7. `redirect` — bảo vệ route

Chi tiết đầy đủ: [AuthBloc & Redirect](./auth-bloc-and-router-redirect.md).

Tóm tắt: mỗi lần sắp vào location, `redirect` đọc `_isAuthenticated` / `_hasTenant` và có thể trả path khác hoặc `null` (cho qua).

Splash (`/`) luôn `return null` — tự điều hướng bằng code trong `SplashPage`.

---

## 8. Thêm màn mới — checklist

1. Thêm giá trị vào `AppRoutes`.
2. Thêm `GoRoute` trong `routes: [...]`.
3. Nếu cần Bloc theo page → bọc `BlocProvider` trong `builder`.
4. Nếu màn cần login/tenant → cập nhật logic `redirect`.
5. (Tuỳ chọn) thêm helper `goXxx()` trên `AppRouterConfig`.
6. Điều hướng từ UI: `context.go(AppRoutes.xxx.path)`.

---

## 9. Deep link / web

- `initialLocation: '/'` → luôn splash khi mở app.
- Query (`?message=`) hữu ích khi mở link hoặc share URL.
- `extra` không serialize lên URL — đừng dựa vào `extra` cho deep link bắt buộc.

---

## 10. So với React Router

| go_router | React Router |
|-----------|--------------|
| `GoRoute` + `builder` | `<Route element={...} />` |
| `context.go` | `navigate(..., { replace: true })` |
| `context.push` | `navigate` push |
| `state.extra` | `location.state` |
| `queryParameters` | `useSearchParams` |
| `redirect` | `loader` / `<Navigate>` trong layout |
| Enum path | constant routes object |

---

## Tài liệu liên quan

- [AuthBloc & Redirect](./auth-bloc-and-router-redirect.md)
- [Bloc Patterns](./flutter-bloc-patterns.md)
- [Cheat Sheet](./flutter-cheat-sheet.md)
