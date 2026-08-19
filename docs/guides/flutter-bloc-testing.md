# Testing Bloc với blocTest

Hướng dẫn viết unit test cho Bloc theo đúng style trong repo (`auth_bloc_test.dart`): mocktail + bloc_test + matcher.

Liên quan code: `test/features/auth/auth_bloc_test.dart`.

---

## 1. Packages

Trong `pubspec.yaml` (dev):

- `flutter_test` — framework test
- `bloc_test` — `blocTest(...)`
- `mocktail` — mock class không cần codegen (khác Mockito)

---

## 2. Mock repository

```dart
class MockAuthRepository extends Mock implements AuthRepository {}
```

`implements AuthRepository` → compile bắt buộc đúng contract; runtime mọi method cần `when(...)` nếu được gọi.

```dart
setUp(() {
  authRepository = MockAuthRepository();
  when(() => authRepository.selectTenant(any())).thenAnswer((_) async {});
  when(() => authRepository.getSelectedTenantId()).thenAnswer((_) async => null);
});
```

| Cú pháp mocktail | Ý nghĩa |
|------------------|---------|
| `when(() => repo.fn(any()))` | Stub mọi argument |
| `thenAnswer((_) async => value)` | Trả Future |
| `thenReturn(value)` | Trả sync |
| `verify(() => repo.fn('t1')).called(1)` | Assert đã gọi |
| `verifyNever(() => repo.fn(any()))` | Assert không gọi |

---

## 3. Fake data helpers

```dart
TenantMembership fakeTenant(String id) { ... }
const fakeUser = User(...);
AuthSession fakeSession(List<TenantMembership> tenants) { ... }
```

Tách fixture → test đọc dễ, tránh JSON dài trong từng case.

---

## 4. `buildBloc` — tắt side-effect lúc tạo

```dart
AuthBloc buildBloc() => AuthBloc(
      authRepository: authRepository,
      checkOnCreate: false, // không tự AuthCheckRequested
    );
```

Nếu `checkOnCreate: true` (mặc định production), Bloc ngay lập tức gọi API check → test phải stub `isLoggedIn`/`getMe` mọi case, dễ nhiễu.

---

## 5. Cấu trúc `blocTest`

```dart
blocTest<AuthBloc, AuthState>(
  'mô tả hành vi bằng tiếng người',
  build: buildBloc,                    // tạo Bloc mới mỗi test
  seed: () => AuthNeedsTenant(...),    // (optional) state ban đầu
  act: (bloc) => bloc.add(...),        // gửi event
  expect: () => [                      // danh sách state phát ra (theo thứ tự)
    isA<AuthAuthenticated>()
        .having((s) => s.selectedTenantId, 'selectedTenantId', 't2'),
  ],
  verify: (_) {                        // (optional) verify mock
    verify(() => authRepository.selectTenant('t2')).called(1);
  },
);
```

### Ý nghĩa từng field

| Field | Bắt buộc? | Vai trò |
|-------|-----------|---------|
| `build` | Có | Factory Bloc |
| `act` | Thường có | `add` event / gọi method |
| `expect` | Thường có | States **sau** seed mà Bloc `emit` |
| `seed` | Không | State giả lập trước khi `act` |
| `verify` | Không | Tương tác repository |
| `errors` | Không | Khi expect exception |

**Lưu ý:** `expect` không gồm state `seed` — chỉ các emit mới.

---

## 6. Matcher hay dùng

```dart
isA<AuthAuthenticated>()
  .having((s) => s.user.id, 'user.id', 'u1')
  .having((s) => s.tenants.length, 'tenants.length', 1),
```

Hoặc so khớp instance nếu state `Equatable` và bạn tạo đúng object:

```dart
expect: () => [
  AuthAuthenticated(user: fakeUser, tenants: [...], selectedTenantId: 't1'),
],
```

`isA` + `having` linh hoạt hơn khi không muốn so cả object lớn.

---

## 7. Ví dụ theo scenario trong repo

### 1 tenant → auto chọn → Authenticated

```dart
act: (bloc) => bloc.add(AuthSessionEstablished(fakeSession([fakeTenant('t1')]))),
expect: () => [isA<AuthAuthenticated>()...],
verify: (_) {
  verify(() => authRepository.selectTenant('t1')).called(1);
},
```

### 2 tenants, chưa lưu → NeedsTenant

```dart
expect: () => [isA<AuthNeedsTenant>()...],
verify: (_) {
  verifyNever(() => authRepository.selectTenant(any()));
},
```

### Đang NeedsTenant + chọn org

```dart
seed: () => AuthNeedsTenant(user: fakeUser, tenants: [t1, t2]),
act: (bloc) => bloc.add(const AuthTenantSelected('t2')),
expect: () => [isA<AuthAuthenticated>()...],
```

---

## 8. Chạy test

```bash
# tất cả
flutter test

# một file
flutter test test/features/auth/auth_bloc_test.dart

# theo tên test
flutter test --name "1 tenant"
```

---

## 9. Checklist viết test Bloc mới

1. Mock mọi dependency interface (`AuthRepository`, …).
2. `setUp` stub mặc định an toàn (`thenAnswer`, không throw).
3. Tắt auto-event lúc create nếu có (`checkOnCreate: false`).
4. Mỗi `blocTest` = một hành vi rõ ràng.
5. `expect` đúng thứ tự emit (`Loading` rồi `Success` nếu có).
6. `verify` / `verifyNever` cho tương tác quan trọng.
7. Không phụ thuộc timer/navigate thật — navigation trong `AuthBloc` đã `_safeNavigate` bắt lỗi; vẫn có thể stub thêm nếu cần.

---

## 10. Mở rộng: test `LoginBloc`

Ý tưởng:

```dart
blocTest<LoginBloc, LoginState>(
  'login ok → LoginSuccess',
  build: () => LoginBloc(authRepository: authRepository),
  setUp: () {
    when(() => authRepository.login(
      credentials: any(named: 'credentials'),
      password: any(named: 'password'),
    )).thenAnswer((_) async => fakeSession([fakeTenant('t1')]));
  },
  act: (bloc) => bloc.add(const LoginSubmitted(
    credentials: 'a@b.com',
    password: 'secret',
  )),
  expect: () => [
    const LoginLoading(),
    isA<LoginSuccess>(),
  ],
);
```

Named params trong mocktail: `any(named: 'credentials')`.

---

## 11. So với Jest / React Testing Library

| bloc_test | Jest + RTL / Redux |
|-----------|-------------------|
| `blocTest` | `store.dispatch` + assert state |
| `Mock` + `when` | `jest.fn` / `vi.fn` |
| `expect: () => [states]` | `expect(store.getState()).toEqual` |
| `verify` | `expect(mock).toHaveBeenCalledWith` |
| Không render widget | Có thể thêm `flutter_test` + `pumpWidget` cho widget test |

Unit test Bloc = test reducer/thunk **không cần** render UI — nhanh, ổn định.

---

## Tài liệu liên quan

- [Bloc Patterns](./flutter-bloc-patterns.md)
- [Repository & DI](./repository-and-di.md)
- [AuthBloc & Redirect](./auth-bloc-and-router-redirect.md)
