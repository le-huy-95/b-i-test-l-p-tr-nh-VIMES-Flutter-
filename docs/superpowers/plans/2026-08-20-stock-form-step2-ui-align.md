# Stock Form Step 2 UI Align — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline) or superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align phiếu nhập/xuất step 2 UI: shared date field for HSD/NSX, remove Batch No, money price field full-width, move "Thêm sản phẩm" next to title.

**Architecture:** Extend `AppDateField` to support `initialValue`/`onChanged` + built-in picker while keeping controller+onTap for step 1. Update both form line builders and headers to match the approved layout.

**Tech Stack:** Flutter, `intl` DateFormat, existing `AppPriceField` / `AppButton` / `AppFormField`.

**Commits:** Skip auto-commits unless the user explicitly asks (repo rule).

---

## File map

| File | Responsibility |
|---|---|
| `lib/shared/widgets/app_date_field.dart` | Shared date input (controller or initialValue mode) |
| `test/shared/widgets/app_date_field_test.dart` | Widget tests for new API |
| `lib/features/document/pages/stock_issue_form_page.dart` | Header + line item (no batch, price full width) |
| `lib/features/document/pages/stock_receipt_form_page.dart` | Same + HSD/NSX full-width date fields |

---

### Task 1: Extend `AppDateField`

**Files:**
- Modify: `lib/shared/widgets/app_date_field.dart`
- Test: `test/shared/widgets/app_date_field_test.dart`

- [x] **Step 1: Write failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_y_app/shared/widgets/app_date_field.dart';

void main() {
  testWidgets('AppDateField shows initialValue and calendar icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppDateField(
            label: 'HSD',
            initialValue: '20/08/2026',
            required: false,
            onChanged: _noop,
          ),
        ),
      ),
    );

    expect(find.text('20/08/2026'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
  });
}

void _noop(String _) {}
```

- [x] **Step 2: Run test — expect FAIL** (API missing)

```bash
flutter test test/shared/widgets/app_date_field_test.dart
```

- [x] **Step 3: Implement `AppDateField`**

Convert to `StatefulWidget`:

- Keep: `label`, `controller`, `hintText`, `enabled`, `onTap`
- Add: `initialValue`, `onChanged`, `required` (default `true`)
- If `controller == null`, own a `TextEditingController` seeded from `initialValue`
- Sync when `initialValue` changes (`didUpdateWidget`)
- If `onTap == null`, built-in `showDatePicker` → format `dd/MM/yyyy` → update text + `onChanged`
- Validator: `required ? requiredValidator : null`
- Still render calendar suffix icon

Existing call sites (`controller` + `onTap`) must compile unchanged.

- [x] **Step 4: Run test — expect PASS**

```bash
flutter test test/shared/widgets/app_date_field_test.dart
```

---

### Task 2: Update phiếu xuất step 2

**Files:**
- Modify: `lib/features/document/pages/stock_issue_form_page.dart`

- [x] **Step 1: Header — title + button**

In `_buildLines`, replace title-only + bottom `AppButton` with:

```dart
Row(
  children: [
    const Expanded(
      child: Text(
        'Hàng hóa',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
    ),
    if (_products.isNotEmpty)
      AppButton(
        label: 'Thêm sản phẩm',
        onPressed: _navigateToCreateProduct,
        variant: AppButtonVariant.outlined,
        height: 40,
        icon: const Icon(Icons.add, color: ColorSkin.primary),
      ),
  ],
),
```

Remove the bottom `if (_products.isNotEmpty) ...[ AppButton Thêm sản phẩm ]` block.

- [x] **Step 2: Line item — remove Batch, price full width**

In `_IssueLineItem`, replace the Row of `AppPriceField` + Batch `AppTextField` with a single full-width:

```dart
AppPriceField(
  label: 'Tiền mặt',
  initialValue: draft.unitPrice,
  hintText: '0',
  onChanged: (value) => draft.unitPrice = value,
),
```

- [x] **Step 3: Drop `batchId` from draft**

- Remove field from `_IssueLineDraft` constructor / members / `toJson`
- Remove `batchId:` when hydrating from existing document
- Remove Batch text from review preview helper that appends `\nBatch: ...`

---

### Task 3: Update phiếu nhập step 2

**Files:**
- Modify: `lib/features/document/pages/stock_receipt_form_page.dart`

- [x] **Step 1: Header** — same `Hàng hóa` + outlined button row as issue; remove bottom duplicate button; change title from `Dòng hàng` → `Hàng hóa`.

- [x] **Step 2: Line item fields**

Replace price+batch Row and HSD/NSX Row with:

```dart
AppPriceField(
  label: 'Tiền mặt',
  initialValue: draft.unitPrice,
  hintText: '0',
  onChanged: (value) => draft.unitPrice = value,
),
const SizedBox(height: 12),
AppDateField(
  label: 'HSD',
  initialValue: draft.expiryDate,
  required: false,
  onChanged: (value) => draft.expiryDate = value,
),
const SizedBox(height: 12),
AppDateField(
  label: 'NSX',
  initialValue: draft.manufactureDate,
  required: false,
  onChanged: (value) => draft.manufactureDate = value,
),
```

Optionally auto-fill `unitPrice` from `product.averageCost` on product select (match issue) — **do this** for UI parity.

- [x] **Step 3: Drop `batchNo` from draft**

- Remove from `_ReceiptLineDraft`, `toJson`, and hydrate mapping

---

### Task 4: Verify

- [x] **Step 1:** `flutter analyze lib/shared/widgets/app_date_field.dart lib/features/document/pages/stock_issue_form_page.dart lib/features/document/pages/stock_receipt_form_page.dart`
- [x] **Step 2:** `flutter test test/shared/widgets/app_date_field_test.dart`
- [x] **Step 3:** Hot-reload / manual check step 2 both forms if `flutter run` is active

---

## Spec coverage

| Spec item | Task |
|---|---|
| Shared date for HSD/NSX | Task 1 + 3 |
| Remove Batch both forms | Task 2 + 3 |
| AppPriceField Tiền mặt full width | Task 2 + 3 |
| Button beside title | Task 2 + 3 |
| Title Hàng hóa | Task 2 + 3 |
| HSD/NSX each full row | Task 3 |
| Step-1 AppDateField unbroken | Task 1 (controller+onTap kept) |
