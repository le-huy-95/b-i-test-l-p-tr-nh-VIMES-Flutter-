# Repository & Dependency Injection

Cách project tách tầng dữ liệu (`domain` / `data`) và inject bằng `RepositoryProvider` + constructor — không dùng get_it/injectable.

Liên quan code:

- `lib/domain/repositories/auth_repository.dart`
- `lib/data/repositories/auth_repository_impl.dart`
- `lib/domain/usecases/auth/login_usecase.dart`
- `lib/app/app.dart`

---

## 1. Kiến trúc lớp (đơn giản hóa)

```
┌─────────────────────────────────────────────┐
│ UI (Pages) + Bloc                           │
│  chỉ biết: AuthRepository, AuthBloc, ...    │
└────────────────────▲────────────────────────┘
                     │ gọi interface
┌────────────────────┴────────────────────────┐
│ Domain                                      │
│  AuthRepository (abstract)                  │
│  LoginUseCase (tuỳ chọn)                    │
└────────────────────▲────────────────────────┘
                     │ implements
┌────────────────────┴────────────────────────┐
│ Data                                        │
│  AuthRepositoryImpl                         │
│    → AuthApiService (HTTP)                  │
│    → StorageManager (local)                 │
└─────────────────────────────────────────────┘
```

**Quy tắc:** UI/Bloc phụ thuộc **abstraction** (`AuthRepository`), không import `AuthRepositoryImpl` hay API client trực tiếp (trừ chỗ wiring ở `app.dart`).

---

## 2. Interface (contract)

```dart
// domain/repositories/auth_repository.dart
abstract class AuthRepository {
  Future<AuthSession> login({
    required String credentials,
    required String password,
  });

  Future<AuthSession> loginWithGoogle({required String idToken});
  Future<bool> isLoggedIn();
  Future<void> logout({bool forceLocalOnly = false});
  Future<void> selectTenant(String tenantId);
  // ...
}
```

- Chỉ khai báo **việc cần làm**, không biết HTTP hay SharedPreferences.
- Đổi backend / mock test → implement khác, Bloc không đổi.

---

## 3. Implementation (data)

```dart
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    AuthApiService? apiService,
    StorageManager? storageManager,
  })  : _apiService = apiService ?? AuthApiService(),
        _storageManager = storageManager ?? StorageManager();

  final AuthApiService _apiService;
  final StorageManager _storageManager;

  @override
  Future<AuthSession> login({...}) async {
    final parts = splitCredentials(credentials);
    final session = await _apiService.login(...);
    await _persistSession(session);
    await _registerDeviceBestEffort();
    return session;
  }
}
```

Impl **phối hợp** nhiều nguồn: API + storage + side-effect (register device best-effort).

Constructor optional deps → dễ inject fake trong test, hoặc dùng default production.

---

## 4. UseCase — khi nào cần?

```dart
class LoginUseCase {
  LoginUseCase(this._repository);
  final AuthRepository _repository;

  Future<Either<Failure, AuthSession>> call({...}) async {
    try {
      return Right(await _repository.login(...));
    } catch (e) {
      return Left(Failure(message: e.toString()));
    }
  }
}
```

| Dùng UseCase | Gọi Repository trực tiếp từ Bloc |
|--------------|----------------------------------|
| Cần `Either` / chuẩn hóa lỗi | Flow đơn giản try/catch + emit Failure |
| Logic nghiệp vụ tái sử dụng nhiều Bloc | Một Bloc một gọi API |
| `AuthBloc` + `LoginUseCase` | `LoginBloc` gọi `_authRepository.login` |

Cả hai pattern **cùng tồn tại** trong project — không bắt buộc mọi thứ qua UseCase.

---

## 5. DI bằng Provider (wiring ở `app.dart`)

```dart
@override
void initState() {
  super.initState();
  _authRepository = AuthRepositoryImpl();
  _demoRepository = DemoRepositoryImpl();
}

@override
Widget build(BuildContext context) {
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<AuthRepository>.value(value: _authRepository),
      RepositoryProvider<DemoRepository>.value(value: _demoRepository),
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => AuthBloc(authRepository: _authRepository),
        ),
      ],
      child: MaterialApp.router(...),
    ),
  );
}
```

### Vì sao `.value`?

Instance tạo trong `State.initState` → sống cả app, không tạo lại mỗi rebuild.

### Lấy ra ở tầng dưới

```dart
// Trong GoRoute builder / widget
context.read<AuthRepository>()

// Khi tạo LoginBloc
LoginBloc(authRepository: context.read<AuthRepository>())
```

`read` lấy dependency đã đăng ký theo **kiểu generic** `AuthRepository` — nhận interface, runtime là `AuthRepositoryImpl`.

---

## 6. Ai được inject cái gì?

```
BaseApp
  tạo AuthRepositoryImpl
  │
  ├─ RepositoryProvider<AuthRepository>  ← mọi context.read
  │
  └─ AuthBloc(authRepository)
       │
       └─ (route) LoginBloc(authRepository: context.read())
```

| Thành phần | Nhận |
|------------|------|
| `AuthBloc` | `AuthRepository` (+ optional `LoginUseCase`) |
| `LoginBloc` / `RegisterBloc` / `OtpBloc` | `AuthRepository` từ `context.read` |
| Pages | Bloc qua `context.read` / `BlocConsumer` — **không** cần biết Impl |

---

## 7. Lợi ích khi test

```dart
class MockAuthRepository extends Mock implements AuthRepository {}

// test
when(() => authRepository.selectTenant(any())).thenAnswer((_) async {});
AuthBloc(authRepository: authRepository, checkOnCreate: false);
```

Không cần HTTP thật — chỉ mock interface. Xem [Testing & blocTest](./flutter-bloc-testing.md).

---

## 8. So với get_it / Riverpod

| Cách project | get_it | Riverpod |
|--------------|--------|----------|
| `RepositoryProvider` trên cây widget | Service locator global | `Provider` / `Notifier` |
| `context.read<T>()` | `getIt<T>()` | `ref.read(provider)` |
| Scope theo widget tree | Thường singleton | Family / autoDispose |
| Không thêm package DI | Cần get_it | Cần flutter_riverpod |

Project chọn **Provider có sẵn từ flutter_bloc** → đủ cho quy mô hiện tại, dễ thấy dependency trên cây.

---

## 9. Checklist thêm repository mới

1. Tạo `abstract class XxxRepository` trong `domain/repositories/`.
2. Tạo `XxxRepositoryImpl` trong `data/repositories/`.
3. Trong `BaseApp`: tạo instance + `RepositoryProvider<XxxRepository>.value`.
4. Bloc nhận `XxxRepository` qua constructor.
5. Test: `MockXxxRepository extends Mock implements XxxRepository`.

**Không** gọi `AuthApiService` từ Page/Bloc — đi qua repository.

---

## Tài liệu liên quan

- [Bloc Patterns](./flutter-bloc-patterns.md)
- [Testing & blocTest](./flutter-bloc-testing.md)
- [Cheat Sheet](./flutter-cheat-sheet.md)
