# Form & Validator trong Flutter

Hướng dẫn dùng `Form`, `GlobalKey<FormState>`, `TextFormField` / `AuthTextField`, và validator — bám theo màn `LoginPage`.

Liên quan code:

- `lib/features/auth/pages/login_page.dart`
- `lib/features/auth/widgets/auth_text_field.dart`

---

## 1. Các phần tử chính

```
Form(key: _formKey)
  └── AuthTextField(..., validator: ...)
  └── AuthTextField(..., validator: ...)
  └── AuthPrimaryButton(onPressed: _submit)

_submit() {
  if (!_formKey.currentState!.validate()) return;
  // gửi Bloc...
}
```

| Thành phần | Vai trò |
|------------|---------|
| `Form` | Nhóm các field có `FormField` / `TextFormField` |
| `GlobalKey<FormState>` | Gọi `validate()`, `save()`, `reset()` từ ngoài |
| `validator` | Hàm `(String?) → String?` — null = OK, string = lỗi |
| `TextEditingController` | Giữ text; đọc `.text` khi submit |

---

## 2. Khai báo key & controller (trong `State`)

```dart
class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _credentialsController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _credentialsController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
```

- Key tạo **một lần** trên State (không tạo trong `build` — sẽ mất state Form).
- Controller thuộc State → `dispose` bắt buộc.

---

## 3. Gắn Form + field

```dart
Form(
  key: _formKey,
  child: Column(
    children: [
      AuthTextField(
        controller: _credentialsController,
        label: 'Email / SĐT',
        enabled: !isLoading,
        validator: (value) =>
            value == null || value.trim().isEmpty
                ? 'Vui lòng nhập email hoặc SĐT'
                : null,
      ),
      AuthTextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        onFieldSubmitted: (_) => _submit(), // Enter trên bàn phím
        validator: (value) =>
            value == null || value.isEmpty
                ? 'Vui lòng nhập mật khẩu'
                : null,
      ),
    ],
  ),
);
```

`AuthTextField` là `StatelessWidget` bọc `TextFormField` — truyền `validator` xuống như props.

---

## 4. Kiểu `validator` chi tiết

```dart
String? Function(String?)? validator;
```

```dart
validator: (value) {
  if (value == null || value.trim().isEmpty) {
    return 'Không được để trống'; // hiện dưới field
  }
  if (!value.contains('@')) {
    return 'Email không hợp lệ';
  }
  return null; // hợp lệ
},
```

### Quy ước

| Trả về | Ý nghĩa |
|--------|---------|
| `null` | Hợp lệ |
| `String` không rỗng | Message lỗi (Flutter tự hiện) |

Có thể tách hàm để tái sử dụng:

```dart
String? requiredEmail(String? value) {
  if (value == null || value.trim().isEmpty) return 'Bắt buộc';
  // ...
  return null;
}

// dùng: validator: requiredEmail
```

---

## 5. `validate()` khi submit

```dart
void _submit() {
  if (!_formKey.currentState!.validate()) return;

  context.read<LoginBloc>().add(
    LoginSubmitted(
      credentials: _credentialsController.text.trim(),
      password: _passwordController.text,
    ),
  );
}
```

`validate()`:

1. Gọi lần lượt `validator` của mọi `FormField` con.
2. Trả `true` nếu **tất cả** OK; `false` nếu có lỗi.
3. Field lỗi tự hiện `errorText` (decoration).

`!` sau `currentState`: assert key đã gắn vào `Form` trong cây (sau `build`).

---

## 6. `TextField` vs `TextFormField`

| | `TextField` | `TextFormField` |
|-|-------------|-----------------|
| Nằm trong `Form.validate()` | Không | Có |
| Có `validator` | Không | Có |
| Dùng khi | Ô search đơn lẻ | Form đăng nhập / đăng ký |

Project dùng `TextFormField` bên trong `AuthTextField`.

---

## 7. Controlled text bằng `TextEditingController`

Flutter không bắt buộc `value` + `onChanged` như React controlled input.

```dart
// Đọc
final email = _credentialsController.text.trim();

// Ghi (hiếm trên login)
_credentialsController.text = 'admin@vimes.vn';

// Lắng nghe từng lần gõ (nếu cần)
_credentialsController.addListener(() { ... }); // nhớ remove / dispose
```

Parent giữ controller → con chỉ nhận props → dễ test và dispose tập trung.

---

## 8. UX khi đang loading

```dart
enabled: !isLoading,
```

```dart
AuthPrimaryButton(
  isLoading: isLoading,
  onPressed: _submit, // button tự null khi isLoading
);
```

- Disable field + nút → tránh double submit.
- `onFieldSubmitted: (_) => _submit()` vẫn nên no-op khi loading (Bloc/guard xử lý thêm càng tốt).

---

## 9. Autovalidate — validate khi đang gõ

Mặc định Form chỉ validate khi gọi `validate()` (submit).

Muốn validate sớm hơn:

```dart
Form(
  key: _formKey,
  autovalidateMode: AutovalidateMode.onUserInteraction,
  child: ...,
);
```

| Mode | Hành vi |
|------|---------|
| `disabled` (mặc định) | Chỉ khi `validate()` |
| `onUserInteraction` | Sau lần tương tác đầu, validate tiếp |
| `always` | Luôn validate (có thể ồn lúc mới mở) |

---

## 10. `save()` và `onSaved` (tuỳ chọn)

Pattern cổ điển Form Flutter:

```dart
TextFormField(
  onSaved: (v) => _email = v,
  validator: ...,
);

_formKey.currentState!.validate();
_formKey.currentState!.save(); // gọi mọi onSaved
```

Project login **không** dùng `onSaved` — đọc thẳng từ controller sau `validate()`. Cả hai đều đúng; controller rõ ràng hơn khi cần `.trim()` / logic trước khi gửi Bloc.

---

## 11. So với React

| Flutter | React |
|---------|-------|
| `Form` + `GlobalKey` | `<form onSubmit>` |
| `validator` trên field | schema (Zod/Yup) hoặc lỗi per-field state |
| `validate()` | `handleSubmit` + schema.parse |
| `TextEditingController` | `useState` / `react-hook-form` register |
| `errorText` tự hiện | tự render `{errors.email.message}` |

---

## 12. Checklist Form mới

- [ ] `GlobalKey<FormState>` trên State, không trong `build`
- [ ] Mọi ô cần validate dùng `TextFormField` (hoặc wrapper có validator)
- [ ] Submit: `validate()` trước khi `bloc.add`
- [ ] `dispose` mọi controller
- [ ] Disable khi loading
- [ ] Message lỗi tiếng Việt rõ, ngắn

---

## Tài liệu liên quan

- [Widget Lifecycle](./flutter-widget-lifecycle.md)
- [Bloc patterns](./flutter-bloc-patterns.md)
- [Cheat sheet](./flutter-cheat-sheet.md)
