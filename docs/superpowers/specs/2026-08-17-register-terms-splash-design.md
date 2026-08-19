# Register terms gate + Splash polish — Design Spec

> **Status:** Approved in brainstorm (2026-08-17)  
> **Note:** Workspace hiện chưa có `.git`; spec chưa commit được.  
> **Sources:** Brainstorm session; `lib/features/auth/pages/register_page.dart`; `lib/features/splash/pages/splash_page.dart`; `lib/features/auth/widgets/auth_primary_button.dart`

## Goal

1. Trên màn **Đăng ký**, nút **Tiếp tục** chỉ enable khi user đã tick đồng ý điều khoản (disabled xám khi chưa tick).
2. Cải thiện màn **Splash** lần đầu vào: bỏ spinner bị khựng/chờ, giữ brand ngắn rồi chuyển màn nhanh hơn theo auth state.

## Decisions

| Topic | Choice |
|-------|--------|
| Approach | **Approach 1** — Minimal polish |
| Terms UX | Nút vẫn **hiện**, **disabled** khi chưa tick (không ẩn) |
| Terms snackbar | **Xóa** check + warning snackbar trong `_submit` |
| Splash spinner | **Bỏ** `CircularProgressIndicator` |
| Splash min delay | **~700ms** (thay 1500ms) |
| Splash extraWait | **Bỏ** timer 800ms khi còn `AuthLoading` / `AuthInitial` |
| Splash fallback | Timeout an toàn **3s** → login nếu auth không resolve |
| Splash animation | Không thêm fade/logo animation |
| Scope files | `register_page.dart`, `splash_page.dart` only |

## Out of scope

- Link mở Điều khoản / Chính sách bảo mật
- Đổi copy checkbox hoặc layout form đăng ký
- Refactor `AuthBloc`, `main.dart`, Firebase bootstrap
- Splash logo animation / status text
- Đổi flow login / OTP / select tenant

## Design

### 1. Register — terms-gated Continue

**Current:** Checkbox `_agreeTerms`; nút luôn gọi `_submit`; nếu chưa tick → snackbar warning.

**Target:**
- `AuthPrimaryButton.onPressed`:
  - `null` khi `!_agreeTerms || isLoading` → disabled (dùng `disabledBackgroundColor` sẵn có)
  - `_submit` khi đã đồng ý và không loading
- Trong `_submit`: **bỏ** block `if (!_agreeTerms) { showWarning...; return; }`
- Checkbox `onChanged` giữ `setState` để rebuild enable/disable nút

**Files:** `lib/features/auth/pages/register_page.dart`  
**Reuse:** `AuthPrimaryButton` (đã `onPressed: null` → disabled)

### 2. Splash — brand-only, faster handoff

**Current:** Logo + white spinner; min delay 1500ms; nếu auth còn loading/initial sau min delay → thêm `_extraWait` 800ms rồi mới login. Spinner dễ cảm giác “quay rồi đứng”.

**Target UI:**
- Giữ `Scaffold` + gradient + logo card `VimesLogo`
- Xóa hoàn toàn `CircularProgressIndicator` và khoảng trống spinner

**Target timing / navigation:**
1. `initState` / post-frame: subscribe `AuthBloc.stream`, start min delay **700ms**
2. `_tryNavigate(state)` chỉ chạy khi `mounted && !_navigated && _minDelayDone`
3. Nếu `state` là `AuthLoading` hoặc `AuthInitial`: **return** (chờ stream emit tiếp) — không schedule `_extraWait`
4. Nếu `AuthAuthenticated` → home; `AuthNeedsTenant` → select tenant; còn lại (unauthenticated / error) → login
5. Timer fallback **3s** từ lúc start splash: nếu vẫn chưa navigate → `_go(login)` (tránh kẹt splash)

**Cleanup:** cancel `_authSub`, min delay timer, fallback timer trong `dispose`. Xóa field/logic `_extraWait`.

**Files:** `lib/features/splash/pages/splash_page.dart`

## Success criteria

- [ ] Register: chưa tick → nút Tiếp tục xám, không bấm được
- [ ] Register: tick → nút enable; bỏ tick → disable lại
- [ ] Register: submit không còn snackbar “Vui lòng đồng ý điều khoản…”
- [ ] Splash: không còn spinner
- [ ] Splash: cảm giác chuyển màn nhanh hơn so với 1.5s + 0.8s hiện tại
- [ ] Splash: vẫn route đúng theo auth (home / select tenant / login)
- [ ] Splash: không kẹt vô hạn nếu auth chậm (fallback ≤ 3s → login)

## Manual test plan

1. Cold start app (chưa login) → splash logo ngắn, không spinner → login
2. Cold start khi đã có session → splash → home hoặc select tenant
3. Mở Đăng ký → chưa tick → thử bấm Tiếp tục (không phản hồi / disabled)
4. Tick điều khoản → Tiếp tục enable → đi tiếp OTP flow như cũ
5. Bỏ tick lại → nút disable lại
