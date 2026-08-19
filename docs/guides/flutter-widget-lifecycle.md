# Hướng dẫn Flutter Widget Lifecycle

Tài liệu này giải thích vòng đời (lifecycle) của widget Flutter, cách dùng đúng từng hook, và map sang ví dụ thực tế trong project (`LoginPage`).

Đối tượng: developer quen React/web muốn nắm Flutter nhanh.

---

## 1. Ba loại “component” cần phân biệt

| Loại | Khi nào dùng | Có lifecycle riêng? |
|------|--------------|---------------------|
| `StatelessWidget` | UI chỉ phụ thuộc props, không giữ state | Chỉ có `build` |
| `StatefulWidget` + `State` | Có state đổi theo thời gian (form, toggle, loading local…) | Đầy đủ: `initState` → `build` → `dispose`… |
| `InheritedWidget` / Provider / Bloc | Chia sẻ dữ liệu xuống cây con | Lifecycle gắn với provider (tạo/hủy khi mount/unmount) |

**Lưu ý quan trọng:** Lifecycle “đầy đủ” nằm ở class `State`, **không** nằm ở `StatefulWidget`.

```
LoginPage (StatefulWidget)     ← cấu hình / props (bất biến theo lần tạo)
    └── _LoginPageState        ← state + lifecycle methods
```

Tương đương mental model React:

| Flutter | React |
|---------|-------|
| `StatefulWidget` fields (`infoMessage`) | props |
| `State` fields + `setState` | `useState` |
| `initState` / `dispose` | `useEffect(..., [])` + cleanup |
| `build` | phần `return` của function component |

---

## 2. Sơ đồ vòng đời `StatefulWidget`

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Framework tạo StatefulWidget (vd. LoginPage(...))        │
│ 2. Gọi createState() → tạo _LoginPageState                  │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ initState()                                                 │
│   • Chạy đúng 1 lần khi State được gắn vào cây              │
│   • Khởi tạo controller, lắng nghe, schedule post-frame…    │
│   • Bắt buộc gọi super.initState()                          │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ didChangeDependencies()  (tuỳ chọn, có thể gọi lại)         │
│   • Sau initState, và mỗi khi InheritedWidget phụ thuộc đổi │
│   • Nơi an toàn để dùng context.read / Theme.of lần đầu     │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ build(context)                                              │
│   • Mô tả UI theo state hiện tại                            │
│   • Có thể gọi rất nhiều lần                                │
│   • PHẢI thuần: không side-effect nặng (API, snackbar…)     │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
          ┌────────────────┴────────────────┐
          │ setState / parent rebuild /     │
          │ InheritedWidget đổi             │
          └────────────────┬────────────────┘
                           ▼
                     build() lại …
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ (Nếu widget cấu hình đổi nhưng State được giữ)              │
│ didUpdateWidget(oldWidget)                                  │
│   • Props mới nằm ở widget, props cũ ở oldWidget            │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ deactivate() → dispose()                                    │
│   • Hủy listener, controller, timer, stream…                │
│   • Bắt buộc gọi super.dispose() cuối cùng                  │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Từng method — dùng thế nào?

### 3.1. `createState()`

```dart
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.infoMessage});
  final String? infoMessage;

  @override
  State<LoginPage> createState() => _LoginPageState();
}
```

- Framework gọi khi cần tạo State mới.
- Bạn hầu như chỉ `return _XxxState();`, không viết logic ở đây.

---

### 3.2. `initState()` — setup một lần khi mount

**Dùng cho:**

- Tạo / gắn `TextEditingController`, `AnimationController`, `ScrollController`
- Đăng ký listener (nhưng nhớ gỡ ở `dispose`)
- Đọc props ban đầu: `widget.infoMessage`
- Schedule việc phải chạy **sau frame đầu** (snackbar, dialog)

**Không dùng cho:**

- Gọi `ScaffoldMessenger`, `showDialog`, `Navigator` trực tiếp (cây chưa build xong)
- Phụ thuộc `InheritedWidget` phức tạp → ưu tiên `didChangeDependencies`

**Mẫu chuẩn trong project:**

```dart
@override
void initState() {
  super.initState();

  final message = widget.infoMessage;
  if (message != null && message.isNotEmpty) {
    // Chạy SAU khi frame đầu build xong
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // đã unmount thì bỏ
      SimpleSnackbarService.showSuccess(message);
    });
  }
}
```

**So với React:**

```tsx
useEffect(() => {
  if (infoMessage) showSuccess(infoMessage);
}, []); // mount once
```

`addPostFrameCallback` ≈ đợi paint xong rồi mới show toast (tránh lỗi “không có Scaffold” / context chưa sẵn sàng).

---

### 3.3. `didChangeDependencies()`

**Dùng cho:**

- `ModalRoute.of(context)`, `Theme.of(context)`, `context.read<SomeBloc>()` lần đầu khi cần
- Logic phụ thuộc InheritedWidget có thể đổi

**Đặc điểm:** có thể được gọi **nhiều lần** (không chỉ một lần như `initState`).

```dart
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  // Ví dụ: chỉ fetch 1 lần dù method này gọi lại
  if (!_didFetch) {
    _didFetch = true;
    context.read<SomeBloc>().add(LoadRequested());
  }
}
```

Với màn login hiện tại, logic snackbar đặt ở `initState` + post-frame là đủ; không bắt buộc dùng method này.

---

### 3.4. `build(BuildContext context)` — vẽ UI

**Quy tắc vàng:**

1. **Thuần (pure):** cùng state → cùng mô tả UI.
2. **Không** gọi API, không `setState`, không show snackbar trong `build`.
3. Có thể đọc Bloc qua `BlocBuilder` / `context.watch` — chúng kích hoạt rebuild có kiểm soát.

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: BlocConsumer<LoginBloc, LoginState>(
      listener: (context, state) {
        // Side-effect Ở ĐÂY (snackbar, điều hướng) — không nằm trong build thuần
      },
      builder: (context, state) {
        final isLoading = state is LoginLoading;
        return Form(/* UI theo isLoading */);
      },
    ),
  );
}
```

**Tách side-effect khỏi `build`:**

| Việc | Đặt ở đâu |
|------|-----------|
| Vẽ nút loading | `builder` / `build` |
| Hiện lỗi toast | `BlocConsumer.listener` hoặc callback sau event |
| Điều hướng sau login | `listener` |
| Toggle hiện mật khẩu | `setState` rồi để `build` vẽ lại |

---

### 3.5. `setState` — kích hoạt rebuild

```dart
setState(() {
  _obscurePassword = !_obscurePassword;
});
```

- Chỉ gọi khi State **còn mounted**.
- Sau `await`, luôn kiểm tra:

```dart
final token = await service.signIn();
if (!mounted) return;
setState(() => _googleInProgress = false);
```

`mounted == false` nghĩa là `dispose` đã chạy (user đã pop màn) → tiếp tục `setState` sẽ crash.

**So với React:** flag `let cancelled = false` trong `useEffect` cleanup, hoặc AbortController.

---

### 3.6. `didUpdateWidget(covariant OldWidget oldWidget)`

Chạy khi **parent rebuild** và tạo `StatefulWidget` mới **cùng runtimeType + key**, nên Flutter **giữ nguyên State**, chỉ cập nhật `widget`.

```dart
@override
void didUpdateWidget(covariant LoginPage oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (oldWidget.infoMessage != widget.infoMessage) {
    // props đổi — phản ứng tại đây nếu cần
  }
}
```

**Khi nào cần:** đồng bộ state nội bộ với props mới (kiểu “controlled” một phần).

**Khi nào không cần:** props chỉ dùng trong `build` / đọc một lần ở `initState`.

---

### 3.7. `deactivate()` và `dispose()`

- `deactivate`: State tạm thời ra khỏi cây (hiếm khi bạn override).
- `dispose`: **chắc chắn** hủy tài nguyên.

```dart
@override
void dispose() {
  _credentialsController.dispose();
  _passwordController.dispose();
  // _animationController.dispose();
  // _subscription.cancel();
  super.dispose(); // gọi cuối
}
```

**Phải dispose:**

- `TextEditingController`
- `AnimationController` / `TabController`
- `FocusNode`
- `StreamSubscription`
- `Timer` / periodic callback

Không dispose → rò memory, đôi khi warning trong debug.

---

## 4. `StatelessWidget` thì sao?

```dart
class AuthTextField extends StatelessWidget {
  const AuthTextField({super.key, required this.controller, required this.label});
  // ...

  @override
  Widget build(BuildContext context) { ... }
}
```

- Không có `initState` / `dispose`.
- Mỗi lần parent rebuild với props mới → `build` chạy lại.
- Tài nguyên sống lâu (controller) phải do **cha** sở hữu và dispose.

---

## 5. Lifecycle của Bloc / Provider (liên quan màn hình)

Không phải lifecycle của `State`, nhưng gắn với mount/unmount route:

```dart
// app_router.dart — khi vào /login
return BlocProvider(
  create: (context) => LoginBloc(
    authRepository: context.read<AuthRepository>(),
  ),
  child: LoginPage(infoMessage: message),
);
```

| Sự kiện | Điều gì xảy ra |
|---------|----------------|
| Vào route `/login` | `create` → `LoginBloc` mới |
| Ở trong màn | `LoginPage` `initState` → `build`… |
| Rời `/login` | `BlocProvider` dispose Bloc; `LoginPage` `dispose` |

`AuthBloc` ở `app.dart` sống cả app → không bị hủy khi rời login.

---

## 6. Checklist thực hành

### Khi tạo màn `StatefulWidget`

- [ ] Props bất biến để trên `StatefulWidget` (`final`)
- [ ] State UI / controller để trong `State`
- [ ] `initState`: setup + `super.initState()`
- [ ] Side-effect cần UI sẵn: `addPostFrameCallback` + `mounted`
- [ ] `build`: chỉ mô tả UI
- [ ] Side-effect theo Bloc: `listener`, không nhét vào `build`
- [ ] Sau `await`: `if (!mounted) return;`
- [ ] `dispose`: hủy controller/subscription + `super.dispose()`

### Khi nào chọn Stateless vs Stateful

| Tình huống | Chọn |
|------------|------|
| Chỉ nhận props, vẽ UI | `StatelessWidget` (`AuthTextField`) |
| Có checkbox, obscure, flag loading local | `StatefulWidget` |
| Business state (loading API, success/fail) | `Bloc` + UI lắng nghe |

---

## 7. Ví dụ end-to-end theo `LoginPage`

```
createState
    → initState
         · đọc widget.infoMessage
         · post-frame → snackbar (nếu có)
    → build
         · BlocConsumer builder vẽ Form
    → user bấm hiện mật khẩu
         · setState(_obscurePassword)
         · build lại
    → user bấm Đăng nhập
         · LoginBloc.add(LoginSubmitted)
         · Bloc emit Loading → builder rebuild (disable UI)
         · Success → listener → AuthBloc
         · Failure → listener → snackbar
    → user rời màn
         · dispose controllers
         · LoginBloc bị Provider hủy
```

---

## 8. Bảng tra cứu nhanh (Flutter ↔ React)

| Việc cần làm | Flutter | React |
|--------------|---------|-------|
| Mount 1 lần | `initState` | `useEffect(..., [])` |
| Sau paint đầu | `addPostFrameCallback` | `requestAnimationFrame` / `queueMicrotask` |
| Cleanup | `dispose` | `useEffect` return cleanup |
| Đổi UI local | `setState` | `useState` setter |
| Props đổi, giữ State | `didUpdateWidget` | render lại với props mới (cùng component) |
| Tránh update sau unmount | `if (!mounted) return` | ignore flag / abort |
| Side-effect theo store | `BlocConsumer.listener` | `useEffect` theo selector |
| Subscribe UI theo store | `BlocBuilder` / `builder` | `useSelector` |

---

## 9. Lỗi thường gặp

1. **Snackbar / dialog trong `initState` trực tiếp**  
   → Dùng `addPostFrameCallback` hoặc `didChangeDependencies` có flag.

2. **`setState` / `context` sau `await` khi đã pop**  
   → Luôn check `mounted`.

3. **Quên `dispose` controller**  
   → Memory leak; gắn thói quen dispose ngay khi khai báo controller.

4. **Gọi API trong `build`**  
   → Gọi nhiều lần, khó đoán; đưa vào `initState`, event Bloc, hoặc `listener`.

5. **Nhầm `read` và `watch`**  
   - `context.read` / `bloc.add`: không rebuild theo state  
   - `BlocBuilder` / `watch`: rebuild khi state đổi

---

## 10. Tài liệu tham khảo chính thức

- [StatefulWidget lifecycle](https://api.flutter.dev/flutter/widgets/State-class.html)
- [Widget binding / post-frame callbacks](https://api.flutter.dev/flutter/scheduler/SchedulerBinding/addPostFrameCallback.html)
- Project liên quan: `lib/features/auth/pages/login_page.dart`, `lib/app/router/app_router.dart`

## Tài liệu liên quan trong repo

- [Form & Validator](./flutter-form-validation.md)
- [Bloc Patterns](./flutter-bloc-patterns.md)
- [AuthBloc & Router Redirect](./auth-bloc-and-router-redirect.md)
- [Cheat Sheet](./flutter-cheat-sheet.md)
- [Mục lục guides](./README.md)

---

## Tóm tắt một câu

> `initState` setup một lần, `build` chỉ vẽ, side-effect để `listener`/callback, sau async kiểm tra `mounted`, `dispose` giải phóng hết — đó là cách dùng lifecycle Flutter đúng và an toàn.
