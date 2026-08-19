# Organization Overview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace mock Tổng quan with real `GET /api/v1/reports/organization-overview` in a dedicated `overview` feature module.

**Architecture:** OverviewPage → OverviewBloc → OverviewRepository → OverviewApiService → Dio. Home shell only wires the bloc and refreshes on tenant switch. Last 30 days; layout follows `visibilityScope`.

**Tech Stack:** Flutter, flutter_bloc, mocktail, bloc_test, Dio, intl

**Spec:** `docs/superpowers/specs/2026-08-17-organization-overview-design.md`

---

## File map

| File | Responsibility |
|------|----------------|
| `lib/data/models/overview/organization_overview.dart` | Parse API payload |
| `lib/features/overview/overview_formatters.dart` | VND / qty display |
| `lib/data/datasources/api_endpoints.dart` | Endpoint constant |
| `lib/data/datasources/api_services/overview_api_service.dart` | GET + query params |
| `lib/domain/repositories/overview_repository.dart` | Interface |
| `lib/data/repositories/overview_repository_impl.dart` | Impl |
| `lib/features/overview/bloc/overview_bloc.dart` | Load / refresh |
| `lib/features/overview/pages/overview_page.dart` | Dashboard UI |
| `lib/app/app.dart` | RepositoryProvider |
| `lib/features/home/pages/home_page.dart` | Embed page, drop mock |
| `test/data/models/organization_overview_test.dart` | fromJson |
| `test/features/overview/overview_formatters_test.dart` | Formatters |
| `test/features/overview/overview_bloc_test.dart` | Bloc |

Do **not** commit unless the user asks.

---

### Task 1: Parse models (TDD)

**Files:**
- Test: `test/data/models/organization_overview_test.dart`
- Create: `lib/data/models/overview/organization_overview.dart`

- [ ] **Step 1: Write failing fromJson tests** for organization payload and `inventory: null`
- [ ] **Step 2: Run tests — expect FAIL** (library missing)
- [ ] **Step 3: Implement models + fromJson**
- [ ] **Step 4: Run tests — expect PASS**

---

### Task 2: Formatters (TDD)

**Files:**
- Test: `test/features/overview/overview_formatters_test.dart`
- Create: `lib/features/overview/overview_formatters.dart`

- [ ] Format money string `"2450000.00"` → grouped VND
- [ ] Format qty `"10.0000"` → `"10"`, `"10.5000"` → `"10,5"` (vi_VN)

---

### Task 3: API + repository

**Files:**
- Modify: `lib/data/datasources/api_endpoints.dart`
- Create: `lib/data/datasources/api_services/overview_api_service.dart`
- Create: `lib/domain/repositories/overview_repository.dart`
- Create: `lib/data/repositories/overview_repository_impl.dart`

- [ ] Endpoint `'$baseApi/reports/organization-overview'`
- [ ] `getOrganizationOverview({from, to, expiryDays, topLimit, recentLimit})`
- [ ] Mirror WarehouseApiService error handling

---

### Task 4: OverviewBloc (TDD)

**Files:**
- Test: `test/features/overview/overview_bloc_test.dart`
- Create: `lib/features/overview/bloc/overview_bloc.dart`

- [ ] Inject `DateTime Function() clock`
- [ ] Started/Refreshed: emit Loading then Loaded; call repo with from=now−30d, to=now, expiryDays=30, topLimit=5, recentLimit=5
- [ ] Failure: emit OverviewFailure with friendly message

---

### Task 5: OverviewPage UI

**Files:**
- Create: `lib/features/overview/pages/overview_page.dart`

- [ ] BlocBuilder + RefreshIndicator
- [ ] Organization vs own_documents sections per spec
- [ ] Greeting from AuthBloc user name

---

### Task 6: Wire Home + DI

**Files:**
- Modify: `lib/app/app.dart`
- Modify: `lib/features/home/pages/home_page.dart`

- [ ] Provide OverviewRepository
- [ ] Create/dispose OverviewBloc like WarehouseListBloc
- [ ] Tenant listener → OverviewRefreshed
- [ ] Delete mock `_OverviewTab`, `_KpiCard`, `_QuickAction`, `_LowStockRow`

---

### Task 7: Verify

- [ ] `flutter test test/data/models/organization_overview_test.dart test/features/overview/`
- [ ] `dart analyze` on touched lib files
