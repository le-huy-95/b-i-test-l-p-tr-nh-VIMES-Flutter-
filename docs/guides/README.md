# Guides — Flutter trong project Test Y

Bộ tài liệu học / tra cứu theo đúng code đang dùng trong repo (auth, Bloc, Form, router, DI, test).

## Danh sách

| # | Tài liệu | Nội dung |
|---|----------|----------|
| 1 | [Widget Lifecycle](./flutter-widget-lifecycle.md) | `initState`, `build`, `setState`, `dispose`, `mounted`, map React |
| 2 | [AuthBloc & Router Redirect](./auth-bloc-and-router-redirect.md) | Session toàn app, `setAuthState`, `GoRouter.redirect`, Splash |
| 3 | [Form & Validator](./flutter-form-validation.md) | `Form`, `GlobalKey`, `validator`, controller, submit |
| 4 | [Bloc Patterns](./flutter-bloc-patterns.md) | Event/State/Bloc, Provider scope, `BlocConsumer`, anti-patterns |
| 5 | [GoRouter & Navigation](./go-router-navigation.md) | `AppRoutes`, `go`/`push`, `extra`/query, thêm màn mới |
| 6 | [Repository & DI](./repository-and-di.md) | Domain/data, `RepositoryProvider`, UseCase |
| 7 | [Testing & blocTest](./flutter-bloc-testing.md) | mocktail, `blocTest`, fake data, chạy test |
| 8 | [Cheat Sheet](./flutter-cheat-sheet.md) | Tra cứu 1 trang |

## Thứ tự đọc gợi ý

**Làm quen UI / màn login**

1. Lifecycle → Form → Bloc patterns → Cheat sheet  

**Hiểu auth end-to-end**

2. AuthBloc & Redirect → GoRouter → Repository & DI  

**Viết / bảo trì test**

3. Testing & blocTest (+ đọc lại Repository & DI phần mock)

## Code mẫu chính

- `lib/features/auth/pages/login_page.dart`
- `lib/features/auth/bloc/`
- `lib/app/router/app_router.dart`
- `lib/app/app.dart`
- `lib/domain/repositories/auth_repository.dart`
- `lib/data/repositories/auth_repository_impl.dart`
- `lib/features/splash/pages/splash_page.dart`
- `test/features/auth/auth_bloc_test.dart`
