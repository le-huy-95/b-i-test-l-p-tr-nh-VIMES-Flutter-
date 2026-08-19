# Flutter Bloc Patterns (trong project)

Hướng dẫn pattern `flutter_bloc` đang dùng: Event → Bloc → State, `BlocProvider`, `read` / `BlocConsumer`, sealed class, Equatable.

Liên quan code:

- `lib/features/auth/bloc/login_bloc.dart` (+ event/state)
- `lib/features/auth/bloc/auth_bloc.dart`
- `lib/app/app.dart`, `lib/app/router/app_router.dart`

---

## 1. Công thức 3 file

```
login_event.dart   → “điều gì xảy ra” (ý định user / hệ thống)
login_state.dart   → “UI đang ở trạng thái nào”
login_bloc.dart    → nhận event, gọi repo, emit state
```

Luồng một chiều:

```
UI ──add(Event)──► Bloc ──emit(State)──► UI (builder / listener)
         │                    │
         └──── Repository / UseCase ────┘
```

UI **không** gọi API trực tiếp trong button handler (ngoại trừ bước trung gian như Google lấy `idToken`, rồi vẫn `add` event).

---

## 2. Sealed Event / State + Equatable

```dart
sealed class LoginEvent extends Equatable {
  const LoginEvent();
  @override
  List<Object?> get props => [];
}

class LoginSubmitted extends LoginEvent {
  const LoginSubmitted({required this.credentials, required this.password});
  final String credentials;
  final String password;

  @override
  List<Object?> get props => [credentials, password];
}
```

| Khái niệm | Mục đích |
|-----------|----------|
| `sealed class` | Dart biết mọi subclass → `switch` exhaustive |
| `Equatable` + `props` | So sánh state/event theo giá trị → Bloc không emit “trùng” thừa |
| `const` constructor | Tối ưu, state bất biến |

State điển hình màn form:

```
LoginInitial → LoginLoading → LoginSuccess | LoginFailure
```

---

## 3. Viết Bloc

```dart
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(const LoginInitial()) {
    on<LoginSubmitted>(_onSubmitted);
    on<LoginGoogleRequested>(_onGoogleRequested);
  }

  final AuthRepository _authRepository;

  Future<void> _onSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(const LoginLoading());
    try {
      final session = await _authRepository.login(
        credentials: event.credentials,
        password: event.password,
      );
      emit(LoginSuccess(session));
    } catch (e) {
      emit(LoginFailure(_friendlyError(e)));
    }
  }
}
```

Quy tắc:

1. `super(initialState)` bắt buộc.
2. Đăng ký `on<EventType>(handler)` trong constructor.
3. Handler nhận `event` + `emit` — **chỉ** `emit` để đổi state (không gán field lung tung cho UI).
4. Mọi nhánh async nên kết thúc bằng Success hoặc Failure.

---

## 4. Cung cấp Bloc: `BlocProvider`

### Scope toàn app

```dart
BlocProvider<AuthBloc>(
  create: (_) => AuthBloc(authRepository: _authRepository),
)
```

### Scope theo route

```dart
BlocProvider(
  create: (context) => LoginBloc(
    authRepository: context.read<AuthRepository>(),
  ),
  child: LoginPage(infoMessage: message),
);
```

- `create`: lazy tạo khi cần; tự `close()` Bloc khi Provider bị dispose (rời route).
- `.value`: dùng khi instance đã có sẵn (như `RepositoryProvider.value`).

Inject repo:

```dart
RepositoryProvider<AuthRepository>.value(value: _authRepository),
// ...
context.read<AuthRepository>()
```

---

## 5. UI lắng nghe: `read` / `watch` / widgets

| API | Rebuild khi state đổi? | Dùng khi |
|-----|------------------------|----------|
| `context.read<LoginBloc>()` | Không | `add(event)`, đọc một lần |
| `context.watch<LoginBloc>()` | Có | Trong `build` cần theo state (ít dùng trực tiếp hơn Builder) |
| `BlocBuilder` | Có (builder) | Chỉ UI |
| `BlocListener` | Không (listener) | Snackbar, navigate |
| `BlocConsumer` | Builder có, listener không | Cả hai — như `LoginPage` |

### `BlocConsumer` trên LoginPage

```dart
BlocConsumer<LoginBloc, LoginState>(
  listener: (context, state) {
    if (state is LoginFailure) {
      SimpleSnackbarService.showError(state.message);
    } else if (state is LoginSuccess) {
      context.read<AuthBloc>().add(AuthSessionEstablished(state.session));
    }
  },
  builder: (context, state) {
    final isLoading = state is LoginLoading || _googleInProgress;
    return Form(...);
  },
);
```

**Vàng:** side-effect → `listener`; UI → `builder`.

---

## 6. Gửi event từ UI

```dart
context.read<LoginBloc>().add(
  LoginSubmitted(
    credentials: _credentialsController.text.trim(),
    password: _passwordController.text,
  ),
);
```

- Không `await` `add` — kết quả đến qua state mới.
- Có thể `bloc.add` nhiều event; Bloc xử lý tuần tự theo cấu hình (mặc định tuần tự từng event).

---

## 7. Hai tầng Bloc (feature + app)

```
┌─────────────────────────────────────────┐
│ AuthBloc (app)                          │
│  session, tenant, logout, setAuthState  │
└─────────────────────────────────────────┘
          ▲
          │ AuthSessionEstablished
┌─────────────────────────────────────────┐
│ LoginBloc (page)                        │
│  form loading / API login / Google      │
└─────────────────────────────────────────┘
```

Khi nào tạo Bloc mới:

| Câu hỏi | Có → page Bloc | Không → dùng AuthBloc / shared |
|---------|----------------|--------------------------------|
| State chỉ phục vụ 1 màn? | ✓ | |
| Cần reset khi vào lại màn? | ✓ | |
| Nhiều màn cần cùng data? | | ✓ |

---

## 8. Local UI state vs Bloc state

| Giữ ở `State` + `setState` | Giữ ở Bloc |
|----------------------------|------------|
| `_obscurePassword` | `LoginLoading` |
| `_rememberMe` | `LoginSuccess` / `Failure` |
| `_googleInProgress` (trước khi có token) | Session / user |
| Text trong controller | Kết quả API |

Đừng đẩy mọi thứ vào Bloc — toggle mắt hiện mật khẩu không cần event.

---

## 9. Testing nhanh (ý tưởng)

Project có `test/features/auth/auth_bloc_test.dart` dùng `blocTest`:

```dart
blocTest<AuthBloc, AuthState>(
  'emits authenticated when session has tenant',
  build: () => AuthBloc(..., checkOnCreate: false),
  act: (bloc) => bloc.add(AuthSessionEstablished(session)),
  expect: () => [isA<AuthAuthenticated>()],
);
```

`checkOnCreate: false` tránh auto `AuthCheckRequested` làm nhiễu test.

---

## 10. Anti-patterns cần tránh

1. Gọi repository trong `build`.
2. `emit` sau khi Bloc đã `close` (thường do quên `mounted`/hủy async — framework Bloc cũng có guard).
3. Dùng `BlocProvider.value` với Bloc tạo trong `build` của parent mà không quản lý close → leak.
4. Nhét navigate + snackbar vào `builder`.
5. State mutable (sửa field của state đã emit) — luôn tạo state mới.

---

## 11. So với Redux / Zustand

| Bloc | Redux | Zustand |
|------|-------|---------|
| `add(Event)` | `dispatch(action)` | `set` / action fn |
| `on<Event>(handler)` | reducer + thunk/saga | action trong store |
| `emit(State)` | return new state | `set({ ... })` |
| `BlocProvider` | Provider store | thường module singleton |
| `BlocBuilder` | `useSelector` | hook store |

---

## Tài liệu liên quan

- [AuthBloc & Redirect](./auth-bloc-and-router-redirect.md)
- [Form & Validator](./flutter-form-validation.md)
- [Widget Lifecycle](./flutter-widget-lifecycle.md)
- [Cheat sheet](./flutter-cheat-sheet.md)
