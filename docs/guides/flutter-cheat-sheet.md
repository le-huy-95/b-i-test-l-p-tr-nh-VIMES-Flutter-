# Flutter Cheat Sheet (1 trang)

Tra cứu nhanh — chi tiết xem các guide đầy đủ trong thư mục này.

---

## Lifecycle (`State`)

| Hook | Dùng để |
|------|---------|
| `initState` | Setup 1 lần; `super.initState()` đầu |
| `addPostFrameCallback` | Snackbar/dialog sau frame đầu |
| `build` | Chỉ mô tả UI — không API/snackbar |
| `setState` | Đổi local state → rebuild |
| `didUpdateWidget` | Props đổi, State được giữ |
| `dispose` | Hủy controller/timer/sub; `super.dispose()` cuối |
| `mounted` | Check sau `await` trước `setState`/`context` |

```dart
await doWork();
if (!mounted) return;
setState(() => ...);
```

---

## Stateless vs Stateful

| | Stateless | Stateful |
|-|-----------|----------|
| State nội bộ | Không | Có |
| Props | `final` fields | trên `Widget`, đọc `widget.x` |
| Ví dụ | `AuthTextField` | `LoginPage` |

---

## Form

```dart
final key = GlobalKey<FormState>();
// ...
Form(key: key, child: TextFormField(validator: (v) => v!.isEmpty ? 'Lỗi' : null));
// submit:
if (!key.currentState!.validate()) return;
```

- `validator` → `null` = OK, `String` = lỗi  
- `dispose` mọi `TextEditingController`

---

## Bloc

```dart
// gửi
context.read<LoginBloc>().add(LoginSubmitted(...));

// UI + side-effect
BlocConsumer<LoginBloc, LoginState>(
  listener: (c, s) { /* toast / navigate */ },
  builder: (c, s) { /* UI */ },
);
```

| | `read` | `BlocBuilder` / `builder` | `listener` |
|-|--------|---------------------------|------------|
| Rebuild | Không | Có | Không |
| Side-effect | OK (add) | Không | Có |

**Scope:** `AuthBloc` = app; `LoginBloc` = route `/login`.

---

## Auth + Router (project)

```
LoginSuccess → AuthSessionEstablished → AuthBloc
  → setAuthState + emit + goHome/goSelectTenant
GoRouter.redirect đọc _isAuthenticated / _hasTenant
```

| Cờ | Chặn |
|----|------|
| Chưa auth → `/home` | → `/login` |
| Auth, chưa tenant → `/home` | → `/select-tenant` |
| Auth + tenant → auth flow | → `/home` |

---

## Props / Navigation

```dart
LoginPage(infoMessage: message)           // props widget
router.go('/login', extra: {'message': m}) // “props” qua route
context.go(AppRoutes.register.path)
```

`go` = thay location (auth). Chi tiết: [GoRouter](./go-router-navigation.md).

---

## Repository / DI

```dart
RepositoryProvider<AuthRepository>.value(value: impl);
context.read<AuthRepository>(); // interface, không phải Impl
LoginBloc(authRepository: context.read<AuthRepository>());
```

Chi tiết: [Repository & DI](./repository-and-di.md).

---

## Test Bloc (rút gọn)

```dart
blocTest<AuthBloc, AuthState>(
  'mô tả',
  build: () => AuthBloc(authRepository: mock, checkOnCreate: false),
  act: (b) => b.add(...),
  expect: () => [isA<AuthAuthenticated>()],
  verify: (_) => verify(() => mock.selectTenant('t1')).called(1),
);
```

Chi tiết: [Testing](./flutter-bloc-testing.md).

---

## React map nhanh

| React | Flutter |
|-------|---------|
| props | fields trên Widget |
| `useState` | field + `setState` |
| `useEffect([])` | `initState` / `dispose` |
| `useRef` | `GlobalKey` / `Controller` |
| Redux dispatch | `bloc.add` |
| `useSelector` | `BlocBuilder` |
| ProtectedRoute | `GoRouter.redirect` |

---

## Checklist trước khi merge màn mới

- [ ] `dispose` controllers / subscriptions  
- [ ] `mounted` sau async  
- [ ] Side-effect không nằm trong `build`  
- [ ] Form `validate()` trước submit  
- [ ] Bloc scope đúng (page vs app)  
- [ ] Route bảo vệ cập nhật `redirect` nếu cần  

---

Xem đầy đủ: [README guides](./README.md) · [GoRouter](./go-router-navigation.md) · [DI](./repository-and-di.md) · [Test](./flutter-bloc-testing.md)
