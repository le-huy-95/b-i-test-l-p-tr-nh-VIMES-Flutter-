# Select Tenant Refresh + Logo Upload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** On `SelectTenantPage`, refresh tenants via `GET /auth/me`, show `logoUrl` on tenant cards, and let users create a new tenant with an optional logo (defaulting to `lib/assets/image/app_icon_foreground.png`) and upload it to `POST /tenants/current/logo`.

**Architecture:** Extend the existing `TenantSelectBloc` to support a refresh action and to create tenants via `AuthRepository`. Add a multipart upload capability in the API layer for uploading the tenant logo; ensure the upload uses `X-Tenant-Id` by selecting the newly created tenant before uploading.

**Tech Stack:** Flutter, `flutter_bloc`, `dio`, `image_picker`, `path_provider`, `rootBundle`, `bloc_test`, `mocktail`.

---

## Task 1: Update tenant model to carry `logoUrl`

**Files:**
- Modify: `lib/data/models/tenant/tenant_membership.dart`
- Test: `test/data/models/tenant_membership_test.dart`

- [ ] **Step 1: Create/Update unit test for `TenantMembership.fromJson` (logoUrl)**

Add `test/data/models/tenant_membership_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:test_y_app/data/models/tenant/tenant_membership.dart';

void main() {
  test('TenantMembership.fromJson parses logoUrl', () {
    final m = {
      'id': 't1',
      'code': 'ACME',
      'name': 'Acme Corp',
      'role': 'admin',
      'logoUrl': 'http://example.com/logo.png',
      'status': 'active',
    };
    final tenant = TenantMembership.fromJson(m);
    expect(tenant.id, 't1');
    expect(tenant.code, 'ACME');
    expect(tenant.name, 'Acme Corp');
    expect(tenant.role, 'admin');
    expect(tenant.logoUrl, 'http://example.com/logo.png');
    expect(tenant.status, 'active');
  });

  test('TenantMembership.fromJson handles null logoUrl', () {
    final m = {
      'id': 't1',
      'code': 'ACME',
      'name': 'Acme Corp',
      'role': 'admin',
      'logoUrl': null,
    };
    final tenant = TenantMembership.fromJson(m);
    expect(tenant.logoUrl, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails (expected: compile error until model changes)**

Run:
`flutter test test/data/models/tenant_membership_test.dart -v`

Expected: FAIL due to missing `logoUrl` in model.

- [ ] **Step 3: Modify model to add `logoUrl`**

Update `lib/data/models/tenant/tenant_membership.dart`:
- Add `final String? logoUrl;`
- Include it in constructor
- Parse from JSON key `logoUrl`
- Include in `toJson` only when not null

Concrete change sketch:
```dart
class TenantMembership {
  const TenantMembership({
    required this.id,
    required this.code,
    required this.name,
    required this.role,
    this.status,
    this.logoUrl,
  });

  final String? status;
  final String? logoUrl;

  factory TenantMembership.fromJson(Map<String, dynamic> json) {
    return TenantMembership(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      status: json['status']?.toString(),
      logoUrl: json['logoUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'role': role,
    if (status != null) 'status': status,
    if (logoUrl != null) 'logoUrl': logoUrl,
  };
}
```

- [ ] **Step 4: Run the unit tests again**

Run:
`flutter test test/data/models/tenant_membership_test.dart -v`

Expected: PASS.

---

## Task 2: Implement multipart tenant logo upload in the API layer

**Files:**
- Modify: `lib/data/datasources/api_endpoints.dart`
- Modify: `lib/data/datasources/api_services/auth_api_service.dart`
- Modify (if needed): `lib/data/datasources/api_services/base_api_service.dart`
- Test: `test/data/datasources/auth_api_service_logo_upload_test.dart` (optional; see Step 4)

- [ ] **Step 1: Add endpoint constant**

Update `lib/data/datasources/api_endpoints.dart`:
- Add:
`static const String tenantsCurrentLogo = '$baseApi/tenants/current/logo';`

- [ ] **Step 2: Add upload method to `AuthApiService`**

In `lib/data/datasources/api_services/auth_api_service.dart`, add:

```dart
Future<TenantMembership> uploadTenantLogo({
  required String filePath,
}) async {
  final fileName = filePath.split('/').last;
  final formData = FormData.fromMap({
    'logo': await MultipartFile.fromFile(filePath, filename: fileName),
  });

  final response = await dio.post<dynamic>(
    ApiEndpoints.tenantsCurrentLogo,
    data: formData,
  );

  // Decode like other methods in this file.
  // The backend returns a Tenant object; reuse TenantMembership.fromJson.
}
```

Implementation details:
- Ensure content type is multipart (Dio with `FormData` sets it).
- Decode response via existing `ApiResponse` utilities if you have a wrapper pattern; otherwise follow file’s existing style.

- [ ] **Step 3: Ensure `X-Tenant-Id` header exists during upload**

No code change needed if your auth interceptor already reads tenantId from storage (it does in `lib/core/network/auth_interceptor.dart`).

But you must guarantee that right before calling upload, `AuthRepository.selectTenant(created.id)` has been invoked.

- [ ] **Step 4: (Optional) Add unit test with Dio mocking**

If you have an existing pattern for mocking Dio in this codebase, create a test that verifies:
- correct endpoint used
- multipart field name is `logo`

If no mocking infrastructure exists, skip tests and rely on integration run for this endpoint.

---

## Task 3: Extend `AuthRepository` to refresh tenants and create tenant with logo

**Files:**
- Modify: `lib/domain/repositories/auth_repository.dart`
- Modify: `lib/data/repositories/auth_repository_impl.dart`
- Modify: `lib/data/datasources/api_services/auth_api_service.dart` (if new method needed)

- [ ] **Step 1: Add new repository methods**

Update `lib/domain/repositories/auth_repository.dart`:
- Add:
```dart
Future<List<TenantMembership>> fetchMyTenants();

Future<TenantMembership> createTenantWithLogo({
  required String code,
  required String name,
  String? logoFilePath, // null -> use default asset logo
});
```

- [ ] **Step 2: Implement `fetchMyTenants()`**

In `lib/data/repositories/auth_repository_impl.dart`, implement:
- call `getMe()`
- return `me?.tenants ?? []`

- [ ] **Step 3: Implement `createTenantWithLogo()`**

Implementation steps:
1. Call existing `createTenant(code: code, name: name)` (backend: `POST /auth/tenants`)
2. Call `selectTenant(created.id)` to persist tenant id for auth interceptor
3. Resolve logo file path:
   - if `logoFilePath != null` use it
   - else copy default asset `lib/assets/image/app_icon_foreground.png` into a temp file and use that path
4. Call `uploadTenantLogo(filePath: resolvedPath)` (backend: `POST /tenants/current/logo`)
5. Return the tenant membership parsed from upload response

Default asset temp-file implementation sketch:
```dart
final bytes = await rootBundle.load('lib/assets/image/app_icon_foreground.png');
final tempDir = await getTemporaryDirectory();
final tempPath = '${tempDir.path}/default_tenant_logo.png';
final file = File(tempPath);
await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
return file.path;
```

You need:
- `import 'dart:io';`
- `import 'package:flutter/services.dart';` (rootBundle)
- `import 'package:path_provider/path_provider.dart';`

- [ ] **Step 4: Handle upload failures gracefully**

If upload fails:
- still return the `created` tenant (logoUrl may be null)
- rethrow? no: this task requires “upload fail => tenant still created”.

Preferred:
```dart
try { ...upload... } catch (e) { return created; }
```

The UI layer will show a snackbar; therefore the repository should either:
- return created + log, OR
- throw a typed exception and let bloc show message.

Pick one consistent approach (recommended: repository throws a custom exception with created tenant).

Concrete option to implement in this task:
- Add a repository method that throws `TenantLogoUploadFailed(created: ..., message: ...)`
- Bloc catches and emits Created + snackbar.

---

## Task 4: Add refresh + logo path through TenantSelectBloc

**Files:**
- Modify: `lib/features/auth/bloc/tenant_select_event.dart`
- Modify: `lib/features/auth/bloc/tenant_select_state.dart`
- Modify: `lib/features/auth/bloc/tenant_select_bloc.dart`
- Modify (optional): `lib/features/auth/pages/select_tenant_page.dart`

- [ ] **Step 1: Add event `TenantSelectRefreshRequested`**

In `tenant_select_event.dart`:
```dart
class TenantSelectRefreshRequested extends TenantSelectEvent {
  const TenantSelectRefreshRequested();
}
```

- [ ] **Step 2: Extend create event to include `logoFilePath`**

Update `TenantSelectCreateRequested` to add:
```dart
final String? logoFilePath;
const TenantSelectCreateRequested({
  required this.code,
  required this.name,
  this.logoFilePath,
});
```

- [ ] **Step 3: Add refreshing state**

In `tenant_select_state.dart`, add a state:
`TenantSelectRefreshing(tenants: [...])`

Ensure props include `tenants` as others do.

- [ ] **Step 4: Update bloc handlers**

In `tenant_select_bloc.dart`:
- Register handler for `TenantSelectRefreshRequested`:
  - emit refreshing state (keep current tenants in state)
  - call `authRepository.fetchMyTenants()`
  - on success emit initial state with fresh tenants
  - on failure emit failure state while keeping current tenants
- Update create handler to call `createTenantWithLogo(...)` using event.logoFilePath

If upload fails but tenant created:
- emit `TenantSelectCreated` with created tenant (logo may be null)
- also emit failure snackbar message via a field OR by throwing an exception caught in bloc and producing `TenantSelectFailure` after created.

Pick a clean implementation:
- Add `TenantSelectCreated` field: `String? warningMessage`
- Page listens and shows snackbar.

---

## Task 5: Update `SelectTenantPage` UI (refresh on mount + logo picker + preview)

**Files:**
- Modify: `lib/features/auth/pages/select_tenant_page.dart`

- [ ] **Step 1: Refresh tenants when page opens**

Update `BlocProvider` creation:
```dart
create: (context) => TenantSelectBloc(... )..add(const TenantSelectRefreshRequested()),
```

If rebuild risk exists, convert `SelectTenantPage` into a `StatefulWidget` and dispatch in `initState`.

- [ ] **Step 2: Update tenant card to display logo**

In `_TenantCard`, replace the current icon with:
- if `tenant.logoUrl != null && tenant.logoUrl!.isNotEmpty`:
  - `Image.network(tenant.logoUrl!, ...)`
- else:
  - `Image.asset('lib/assets/image/app_icon_foreground.png', ...)`

Ensure:
- clip to rounded rectangle (12px)
- set fixed size 48×48
- add `errorBuilder` for network image fallback.

- [ ] **Step 3: Add logo picker to create tenant sheet**

Inside `_CreateTenantFormFields`:
1. Add `XFile? _pickedLogo;`
2. Add UI:
   - preview circle/square 72×72
   - button/row “Chọn logo (tùy chọn)”
3. Use `ImagePicker().pickImage(source: ImageSource.gallery, maxHeight: ...?)` (optional)
4. Validate that picked file size <= 2MB (client-side best-effort):
   - if size > 2MB => show inline error by using form validator or local state.

Return from bottom sheet pop:
`({ code: fields.code, name: fields.name, logoFilePath: _pickedLogo?.path })`

- [ ] **Step 4: Pass `logoFilePath` into bloc event**

Update `_showCreateSheet` caller:
`TenantSelectCreateRequested(code: ..., name: ..., logoFilePath: result.logoFilePath)`

---

## Task 6: Add bloc tests for refresh + create flow (mock repository)

**Files:**
- Create: `test/features/auth/tenant_select_bloc_test.dart`

- [ ] **Step 1: Write tests**

Add:
`test/features/auth/tenant_select_bloc_test.dart` with bloc_test + mocktail.

Test cases:
1. Refresh success:
   - seed bloc with initial tenants
   - mock `fetchMyTenants()` returns new list
   - expect sequence: refreshing -> initial with fresh list
2. Refresh failure:
   - mock `fetchMyTenants()` throws
   - expect: refreshing -> failure (keep old tenants)
3. Create with logo:
   - mock `createTenantWithLogo(...)` returns created tenant
   - expect: loading -> created state with new tenant in list

- [ ] **Step 2: Run tests**

Run:
`flutter test test/features/auth/tenant_select_bloc_test.dart -v`

Expected: PASS.

---

## Task 7: Verification run (manual + lint)

**Files:** (no changes)

- [ ] **Step 1: Run analyzer**

Run:
`dart analyze`

- [ ] **Step 2: Run targeted Flutter tests**

Run:
`flutter test`

- [ ] **Step 3: Manual smoke test**

Checklist:
1. Open select tenant page:
   - see loader
   - list renders with logo thumbnails
2. Create new tenant without selecting logo:
   - upload default asset path
   - navigate to home without crash
3. Create new tenant with selected logo:
   - upload multipart with selected image
4. Ensure no controller dispose crash returns.

---

## Self-review (must pass)

- [ ] Every requirement in the spec has a matching task.
- [ ] No “TBD/TODO” placeholders exist in code blocks.
- [ ] Test plan is consistent with repo patterns (`bloc_test`, `mocktail`).

---

## Execution choice

Plan complete and saved to `docs/superpowers/plans/2026-08-17-select-tenant-refresh-logo-implementation-plan.md`. Two execution options:

1. Subagent-Driven (recommended)
2. Inline Execution

Which approach?

