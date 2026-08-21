# Design: Align stock issue/receipt step 2 UI

**Date:** 2026-08-20  
**Status:** Approved for planning  
**Scope:** Step 2 (Hàng hóa) on `stock_issue_form_page.dart` and `stock_receipt_form_page.dart`, plus shared `AppDateField` enhancement.

## Goal

Make phiếu nhập step 2 match phiếu xuất layout, remove Batch No on both forms, use money input for unit price, and use a shared date picker field for HSD/NSX (full-width rows).

## Decisions

| Topic | Decision |
|---|---|
| Batch No | Remove from **both** issue and receipt UI + draft payload fields |
| Unit price | `AppPriceField`, label **Tiền mặt**, full width |
| HSD / NSX | Receipt only; each field on its **own full-width row** |
| Date component | Extend existing `AppDateField` (option 1) |
| Add-product CTA | Move next to title `Hàng hóa` (outlined); empty-product state unchanged |
| Title | Both forms use `Hàng hóa` |

## Layout

### Header (both forms)

```
Row: [Text "Hàng hóa"] ........ [AppButton "Thêm sản phẩm" outlined]
```

When `_products.isEmpty`, keep current empty state (primary CTA inside empty block). Header outlined **Thêm sản phẩm** chỉ hiện khi `_products.isNotEmpty`.

### Line item — phiếu xuất

1. Product select (full)
2. Stock hint (if selected)
3. Unit (full)
4. SL dự kiến | SL thực xuất (half / half)
5. Tiền mặt — `AppPriceField` (full)

### Line item — phiếu nhập

Same as xuất, then:

6. HSD — `AppDateField` (full)
7. NSX — `AppDateField` (full)

Qty labels stay domain-specific: `SL thực xuất` vs `SL thực nhập`.

## `AppDateField` API

Keep backward-compatible controller + external `onTap` for step 1 forms.

Add optional mode for line drafts:

- `initialValue` / `onChanged` (string `dd/MM/yyyy`)
- Built-in `showDatePicker` when `onTap` is null
- `required` (default `true` for existing; HSD/NSX should pass `required: false`)

Existing call sites (`controller` + `onTap`) must keep working without changes.

## Data / payload

- Issue draft: remove `batchId` from UI and `toJson` (stop sending `batchId`).
- Receipt draft: remove `batchNo` from UI and `toJson` (stop sending `batchNo`).
- Loading existing documents: ignore `batchId` / `batchNo` if present; do not surface in UI.
- HSD / NSX still map to `expiryDate` / `manufactureDate` as today (ISO via existing helpers).

## Out of scope

- Step 0 / step 1 / review PDF table redesign
- Backend API contract changes beyond omitting batch fields from client payload
- Extracting shared line-item widget across both pages (optional later)

## Acceptance

- [ ] Both step 2 headers show `Hàng hóa` + `Thêm sản phẩm` beside title when products exist
- [ ] No Batch No field on either form
- [ ] Unit price uses `AppPriceField` labeled Tiền mặt, full row
- [ ] Receipt HSD and NSX use date picker via shared `AppDateField`, each full row
- [ ] Existing step-1 `AppDateField` usages still work
- [ ] Analyze/build/tests for touched files pass
