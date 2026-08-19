# Register terms gate + Splash polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Disable Register “Tiếp tục” until terms checkbox is checked; remove Splash spinner and speed up auth handoff.

**Architecture:** Local UI state on RegisterPage gates `AuthPrimaryButton.onPressed`. SplashPage keeps brand-only UI, short min delay (700ms), waits for AuthBloc without extraWait, and uses a 3s fallback to login.

**Tech Stack:** Flutter, flutter_bloc, go_router

**Spec:** `docs/superpowers/specs/2026-08-17-register-terms-splash-design.md`

---

## File map

| File | Responsibility |
|------|----------------|
| `lib/features/auth/pages/register_page.dart` | Terms-gated Continue button; remove snackbar gate |
| `lib/features/splash/pages/splash_page.dart` | Brand-only splash; timing + navigation |

No new files. No unit tests required for this UI-only polish (manual test plan in spec).

---

### Task 1: Register — disable Continue until terms agreed

**Files:**
- Modify: `lib/features/auth/pages/register_page.dart`

- [x] **Step 1: Remove terms snackbar gate from `_submit`**

Remove:

```dart
if (!_agreeTerms) {
  SimpleSnackbarService.showWarning('Vui lòng đồng ý điều khoản sử dụng');
  return;
}
```

Keep form validate + `RegisterSubmitted` dispatch unchanged.

- [x] **Step 2: Gate button `onPressed`**

Change `AuthPrimaryButton` to:

```dart
AuthPrimaryButton(
  label: 'Tiếp tục',
  isLoading: isLoading,
  onPressed: (!_agreeTerms || isLoading) ? null : _submit,
),
```

- [ ] **Step 3: Manual check**

Open Register: button grey until checkbox ticked; tick enables; untick disables; submit still works when enabled.

---

### Task 2: Splash — brand-only + faster handoff

**Files:**
- Modify: `lib/features/splash/pages/splash_page.dart`

- [x] **Step 1: Replace state fields**

Use:

```dart
StreamSubscription<AuthState>? _authSub;
Timer? _minDelay;
Timer? _fallback;
bool _minDelayDone = false;
bool _navigated = false;
```

Remove `_extraWait`.

- [x] **Step 2: Rewrite init + navigate logic**

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    final authBloc = context.read<AuthBloc>();
    _authSub = authBloc.stream.listen(_tryNavigate);
    _minDelay = Timer(const Duration(milliseconds: 700), () {
      _minDelayDone = true;
      _tryNavigate(authBloc.state);
    });
    _fallback = Timer(const Duration(seconds: 3), () {
      if (!mounted || _navigated) return;
      _go(AppRoutes.login.path);
    });
  });
}

void _tryNavigate(AuthState state) {
  if (!mounted || _navigated || !_minDelayDone) return;

  if (state is AuthLoading || state is AuthInitial) return;

  if (state is AuthAuthenticated) {
    _go(AppRoutes.home.path);
  } else if (state is AuthNeedsTenant) {
    _go(AppRoutes.selectTenant.path);
  } else {
    _go(AppRoutes.login.path);
  }
}
```

Keep existing `_go` / `dispose` (cancel `_authSub`, `_minDelay`, `_fallback`).

- [x] **Step 3: Remove spinner from `build`**

Column children: only logo container (no `SizedBox(height: 40)` + `CircularProgressIndicator`).

- [ ] **Step 4: Manual check**

Cold start: logo only, no spinner, reaches login/home/tenant faster than before; no infinite hang (≤3s fallback).

---

### Task 3: Verify

- [x] **Step 1:** Run analyzer on touched files if Dart MCP / `dart analyze` available
- [ ] **Step 2:** Confirm success criteria from spec checklist
