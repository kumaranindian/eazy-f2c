# Delivery Date & Product Display Name — Investigation Report

Status: **Investigation only — no application code, schema, data or tests changed. Awaiting approval.**
Date: 2026-10-09 · Base commit: `b2ea1e5`

Note on location: the repo has no `docs/` folder; project notes live as Markdown at the repository root, so this report is placed there.

---

## 1. Executive summary

**Issue 1 — Delivery date in the Farmer Package List export.**
The export takes the date straight from `order.deliveryDate`, so it can only show the order's created date in two ways:

1. The stored `deliveryDate` **itself equals the order day**. This comes from how the customer cart calculates the delivery date (`schedule_cart_provider.dart`). That calculation starts searching from *today*. The schedule wizard requires weekly delivery days to be a subset of the ordering days. So an order placed on a delivery day gets `deliveryDate = today` = the day it was created. Confirmed from the code; whether it is a bug depends on a business rule (see §6, Q1).
2. A **daily delivery slot** has no branch in that calculation. It falls back to the schedule's fixed `scheduledDate` (its start date). Every order on that schedule therefore gets the same, increasingly old date. Confirmed from the code.

There is also a **confirmed grouping bug** in the export and the on-screen list. Orders are grouped by `scheduleId` only, and the delivery date shown is taken from the *first* order in the group. A recurring schedule with confirmed orders for two different delivery dates gets merged into one row block carrying one (wrong) date.

Separately, seven read sites use `order.deliveryDate ?? order.createdAt`, and the packing step **writes** `DateTime.now()` into `deliveryDate` when it is missing. Every order created by the current checkout has a `deliveryDate`, so these only affect legacy orders (created by the old, now-unused `checkout_page.dart`, which never set it). I could not verify from code alone whether such orders still exist in Firestore.

**Issue 2 — Product name when an admin adds a product to an existing order.**
Confirmed. `EditOrderDialog` builds the new order item with `productName: product.name`. In this codebase `name` is the **"Product Name (Farmer)"** field. The customer-facing **"Display Name (Customer)"** is `product.displayName`, which the customer cart uses. **No order path reads `product.description`.** The text that looks like a description is the farmer-facing name. Same dialog, confirmed: adding a product already in the order creates a **duplicate line**, not a merged quantity.

---

## 2. Issue 1 — Delivery date

### 2.1 Authoritative field (verified)

| Layer | Field | Evidence |
|---|---|---|
| Order (Firestore `orders`) | `deliveryDate` (Timestamp, nullable) | `order_model.dart:203`, written by `checkout_page_new.dart:1330` as `cart.deliveryDate` |
| Order | `createdAt` = when the order was placed | `checkout_page_new.dart:1349` (`now`) |
| Order | `scheduledDate` — also set to `cart.deliveryDate` | `checkout_page_new.dart:1350` |
| Schedule (`operational_schedules`) | `deliverySlotType`, `deliveryDate` (one-time only), `deliveryDaysOfWeek` (1=Mon..7=Sun), `scheduledDate` (= wizard "Start Date") | `operational_schedule_model.dart:78-82`, wizard `:3066-3093` |
| Bill | `deliveryDate` (non-nullable), copied from order | `bill_service.dart:61` |

Conclusion: **`OrderModel.deliveryDate` is the correct field.** It is only as correct as the cart calculation that produces it.

### 2.2 Farmer Package List export — traced data flow

`farmer_packaging_list_page.dart` (admin → Packaging → Farmer Packaging List; CSV button at `:496`):

1. `_exportToCSV()` `:157` queries `orders` where `isDeleted == false && status == 'confirmed'` (`:166-170`), mapped with `OrderModel.fromFirestore`.
2. Date-range filter on `order.deliveryDate ?? order.createdAt` (`:177`).
3. Groups items by farmer → `scheduleKey`. The key is `order.scheduleId` (`:213-214`); the `scheduleName_date` key is used only when `scheduleId` is null.
4. Per group, the date printed is `firstOrder.deliveryDate ?? firstOrder.createdAt` (`:253`) → `"Delivery Date"` column of `packaging_schedule_details_*.csv`.
5. The second file (`packaging_delivery_summary_*.csv`) uses the same first-order date (`:349`).
6. The on-screen list repeats steps 2–4 at `:613`, `:636`, `:698-701`.

There is no repository, service or provider layer here: the page reads Firestore directly.

### 2.3 Confirmed bugs

| # | Location | Feature | Current | Expected | Root cause / impact |
|---|---|---|---|---|---|
| C1 | `lib/features/customer/providers/schedule_cart_provider.dart:95-101` | Delivery date stamped on every new order (feeds export, bill/PDF, order history, delivery page, profit report, order merging) | First day in `deliveryDaysOfWeek` searching from **today (i = 0)** | Next delivery day **according to the business rule** (see Q1) | Wizard enforces delivery days ⊂ ordering days (`create_operational_schedule_wizard.dart:2226-2240`). Ordering on a delivery day therefore yields `deliveryDate == createdAt` date. Matches the reported symptom. *Confirmed as behaviour; "bug" status depends on Q1.* |
| C2 | `schedule_cart_provider.dart:81-105` | Same | `deliverySlotType == daily` has no branch → returns `schedule.deliveryDate ?? schedule.scheduledDate` (schedule start date; `deliveryDate` is null for daily slots) | A date derived from today / the cutoff for daily delivery (see Q2) | All daily-slot orders get a fixed, past date. Wrong in every downstream screen. |
| C3 | `farmer_packaging_list_page.dart:213-214, 253, 349` (export) and `:636, 698-701` (screen) | Farmer Package List export + screen | Group key `scheduleId`; date = first order's date | Group key `scheduleId + deliveryDate (day)`; date = that group's date | Recurring schedules: confirmed orders for different delivery dates are merged, and the quantities of both dates are shown under one date. |

### 2.4 Suspected bugs (need data or a business decision)

| # | Location | Feature | Current | Proposed | Notes |
|---|---|---|---|---|---|
| S1 | `farmer_packaging_list_page.dart:177, 253, 349, 613, 698` | Export / screen | `deliveryDate ?? createdAt` | Use `deliveryDate`; show/flag "No delivery date" rows instead of substituting | Only triggers for legacy orders with no `deliveryDate` |
| S2 | `admin/presentation/pages/orders/admin_orders_page.dart:827` | Admin Orders date filter | `deliveryDate ?? createdAt` | Filter on `deliveryDate`; decide how undated orders are shown (Q3) | Filter, not display |
| S3 | `admin/presentation/pages/delivery/admin_delivery_page.dart:873` | Delivery page date filter | same | same | |
| S4 | `admin/presentation/pages/packaging/admin_packaging_page.dart:901` | Packaging page date filter | same | same | |
| S5 | `admin/presentation/pages/profit_report_page.dart:79` | Profit report grouping | same | Use `deliveryDate` | The query already requires `deliveryDate` in range (`:67-68`), so the fallback is unreachable. Cleanup only. |
| S6 | `admin/services/whatsapp_notification_service.dart:85` | "Order packed" WhatsApp message | same | Use `deliveryDate`; omit the line if null | Customer-facing text |
| S7 | `customer/services/bill_service.dart:61` | Bill / PDF "Delivery Date" (`bill_view_dialog.dart:219`, `pdf_service.dart:316`) | same | Needs `BillModel.deliveryDate` nullable or an explicit placeholder | Model change (non-nullable today). Ask first (Q3). |
| S8 | `admin/presentation/pages/packaging/admin_packaging_page.dart:1811-1814` | Mark as packed | **Writes** `deliveryDate = now()` to Firestore if missing | Do not invent a date; leave null or block with a message (Q3) | Persists a fabricated date. Comment says it exists for the Delivery page query (`orderBy('deliveryDate')`, `admin_delivery_page.dart:34`). Removing it would hide undated orders there. |

### 2.5 Legitimate uses of `createdAt` (no change)

- `admin_packaging_page.dart:1131` — labelled "Order Date".
- `order_history_page_new.dart:248, 491` — labelled order time / "Placed On".
- All `json['createdAt'] = …` serializers in admin models.
- `customer_dashboard_page.dart:54, 123, 183` — schedule `deliveryDate ?? scheduledDate` for displaying the schedule (not an order). The one-time fallback is reasonable.

### 2.6 Why the export shows the created date — conclusion

For orders created by the live checkout, the export prints the stored `deliveryDate` (the `createdAt` fallback is not reached). The created date appears because **C1/C2 store a delivery date equal to (or older than) the order date**. C3 then spreads one order's date across a whole recurring schedule. The `createdAt` fallback (S1) is a secondary path for legacy undated orders. **I could not confirm which of C1, C2 or S1 produced your specific report without looking at the actual order/schedule documents** (see Q4).

---

## 3. Issue 2 — Product name when admin adds to an existing order

### 3.1 Product fields (verified)

| Field | Form label (`add_product_dialog.dart`) | Meaning |
|---|---|---|
| `name` | "Product Name (Farmer) *" (`:385`) | Farmer/internal name |
| `displayName` | "Display Name (Customer) *" (`:423`) | **Authoritative customer-facing name** |
| `description` | "Description *" (`:447`) | Free text; only rendered on the customer product card (`customer_dashboard_page.dart:482`) |

No SKU field exists on `ProductModel`.

### 3.2 Flow comparison

| Step | Customer flow (correct) | Admin "Edit Order → Add Product" (wrong) |
|---|---|---|
| Entry | Dashboard → cart | `admin_orders_page.dart:683-691` (orders with status pending **or confirmed**) → `EditOrderDialog` |
| Selection source | `ProductModel` + schedule product | `productsStreamProvider` (`edit_order_dialog.dart:46`) → `_AddProductDialog`; list title, search and selected header use `product.name` (`edit_order_dialog.dart:615, 714, 740`) |
| Item mapping | `productName: product.displayName` (`customer_dashboard_page.dart:1676`) → `OrderItem` (`checkout_page_new.dart:1290-1300, 1335-1345`) | **`productName: product.name`** (`edit_order_dialog.dart:486`) |
| Persist | Transaction in checkout | `orderRef.update(updatedOrder.toFirestore())` (`edit_order_dialog.dart:557`) + `regenerateBillFromOrder` |
| Downstream display | Order history, bill/PDF, WhatsApp, packaging, export "Product Display Name" column — all read `OrderItem.productName` | Same readers, so the farmer name now appears everywhere, including the customer's bill |

### 3.3 Root cause (confirmed)

Of the candidate causes listed in the request, it is **"reading the wrong field from the product selection result"**: `edit_order_dialog.dart:486` maps `product.name` instead of `product.displayName`.

The other candidates were ruled out:

- **Serialization:** `OrderItem` serializes `productName` as-is.
- **Stale cart state:** the admin flow does not use the cart.
- **Overwriting existing names:** existing items are only updated through `copyWith` and keep their names.

`description` is not involved. If what you saw looks like a description, the farmer-name field likely holds descriptive text for those products.

### 3.4 Related findings in the same dialog

| # | Location | Finding | Status |
|---|---|---|---|
| P2 | `edit_order_dialog.dart:484` | `_items.add(...)` always appends, so adding a product already in the order creates a **duplicate line** | Confirmed; your spec asks to prevent duplicates |
| P3 | `edit_order_dialog.dart:488` | Price = `product.price` (catalogue), whereas the customer flow uses the schedule's price (`scheduleProduct.price`) | Observation only. Pricing is out of scope; **will not change** unless you ask |
| P4 | `edit_order_dialog.dart:492` | Farmer = `product.farmerId`; the customer flow uses `scheduleProduct.farmerId` | Observation only; no change proposed |
| — | `create_operational_schedule_wizard.dart:1542, 1734`, `update_operational_schedule_dialog.dart:598` | `ScheduleProductItem.productName = product.name` | Admin/farmer-side schedule data, not order items. **Not considered a bug.** |

### 3.4a Farmer Package List export — how the two columns are built (verified, explains the screenshot)

`farmer_packaging_list_page.dart`, both CSV files (schedule details `:234-309`, delivery summary `:332-453`):

| Column | Source | Lines |
|---|---|---|
| **Product Display Name** | the order item's stored snapshot, `OrderItem.productName` | `:281, :296, :407, :440` |
| **Product Name** | live lookup `products/{item.productId}.name`; falls back to the snapshot only if the product doc is missing | lookup built at `:197-203`, used at `:297, :441` |

So the columns differ exactly when the item snapshot is the customer display name (customer checkout: `product.displayName`, `customer_dashboard_page.dart:1676`). They are identical when the snapshot is the farmer name. That happens for items added through Edit Order (`edit_order_dialog.dart:486`). This matches your screenshot: `MANATHAKKALI LEAVES (Bunch)` is a customer-ordered line, and the record with identical values is an admin-added line. **The export itself is correct** and reads the intended fields. It only exposes the bad snapshot.

| # | Location | Finding | Status |
|---|---|---|---|
| E1 | `farmer_packaging_list_page.dart:277, 387, 719` (and `:1008, :1163` on screen) | Aggregation key is `'${item.productName}_${unit}_${category}'`, not `productId`. After the bug above, the same product ordered by the customer (display name) and added by admin (farmer name) lands in **two rows** with the same Product Name and different Product Display Name. Quantities are split instead of summed. | **Confirmed** by code; secondary effect of the root cause |
| E2 | `:297, :441` | `rawProductNameById[...] ?? productDisplayName` falls back to the snapshot when the product doc is gone, so the two columns can silently match. | Suspected, low impact; acceptable fallback, no change proposed |

### 3.4b Other paths checked for wrong mappings

- **Customer add and checkout merge** (`checkout_page_new.dart:1290-1300, 1335-1345`): copies `cartItem.productName` (already `displayName`). Existing items are only touched through `copyWith(quantity:)`. **No defect.**
- **Qty +/- in Edit Order** (`edit_order_dialog.dart:~430-447`): `copyWith(quantity:)` only. **No defect.**
- **Save/reload**: `orderRef.update(updatedOrder.toFirestore())` and `OrderItem.fromJson/toJson` (Freezed, generated) serialize `productName` as-is. **No defect.**
- **Bill** (`bill_service.dart:27`), **packaging** (`admin_packaging_page.dart:1720, 1852`), **admin orders** (`admin_orders_page.dart:1059`): copy `orderItem.productName`. **No defect**, but they show the wrong name for admin-added lines.
- **`description` / `displayName = product.name` mappings**: no code maps `description` into an order item. `OrderItem` has **no separate display-name field**. `productName` *is* the display-name snapshot, and the raw name is never stored on the item.
- **Snapshot vs dynamic**: order items store a snapshot (`productName`, `price`, `unit`, `category`). Only the export's Product Name column is resolved live from the catalogue.
- **Dead code** (not live, not analysed): `checkout_page.dart`, `customer_dashboard_page_old.dart`, backup page.
- **Not verified**: actual Firestore data. I can't query it from here.

### 3.5 Already-saved items

The wrong name **is persisted** in `orders.items[].productName`, not just displayed. It is also copied into bills at generation (`bill_service.dart:27`, regenerated on every Edit Order save). The fix only affects new additions.

- **How many:** unknown without a data query. Affected = confirmed or pending orders edited via Edit Order with a product added. For each, `items[i].productName == products/{productId}.name` and `!= products/{productId}.displayName`. Items where `name == displayName` are unaffected and indistinguishable.
- **Reliable recovery:** `products/{productId}.displayName`, via `productId` (preserved on every item). Caveat: this is the *current* display name; if an admin renamed a product after the order, the old snapshot can't be recovered. Customer-created lines must not be rewritten, since they hold the display name at order time.
- **Historical snapshots:** the repair should touch only items matching the signature above. Delivered orders and finalized bills should be left alone unless you decide otherwise.
- **Safe approach:** (1) read-only dry-run script on dev, then prod, listing order id, item and old/new name; (2) review the list; (3) write only after your approval, with a backup export and an audit field. **Nothing will be run or written without your approval** (Q6).

---

## 4. Proposed fixes (pending approval)

**Issue 1**

1. **C1/C2:** in `_calculateDeliveryDate`, apply the rule you confirm in Q1/Q2 (e.g. "first delivery day on/after the ordering cutoff date"; daily slot → per Q2). One-time slots are unchanged.
2. **C3:** group the export and the screen by `scheduleId + yyyy-MM-dd(deliveryDate)`, and take the date from the group key, not the first order.
3. **S1–S7:** stop substituting `createdAt`. Undated orders show "Not set" in the export, WhatsApp and bill, and are handled in filters per Q3.
4. **S8:** per Q3.
5. No migration and no changes to existing records.

**Issue 2**

1. `edit_order_dialog.dart:486` → `productName: product.displayName`. Use `displayName` for the list title, search (also match `name`, so admins can still find products by farmer name) and selected header.
2. Adding a product already present increases that line's quantity instead of appending a duplicate (match on `productId`).
2a. **Export (E1):** key the aggregation on `productId + unit + category` instead of the display-name text, in the schedule-details export, the delivery-summary export and the on-screen list. The columns keep their current sources. This also stops old bad rows from splitting quantities. Needs confirmation (Q7).
3. No changes to price, farmer, totals or bill logic.

---

## 5. Regression risks & test plan

**Risks**

- Changing C1 shifts which date new orders get. Checkout merges into an existing order only when `deliveryDate` matches (`checkout_page_new.dart` merge filter). Orders placed before and after the change on the same schedule may therefore not merge. Existing orders are unaffected.
- The cutoff logic (`_calculateCutoffDateTime`) and the delivery date must stay consistent.
- Removing S8 may hide undated orders from the Delivery page, which uses `orderBy('deliveryDate')`.
- S7 needs a `BillModel` change, which affects the bill dialog, PDF and WhatsApp.

**Tests (to add after approval)**

- Unit tests for `_calculateDeliveryDate` (extracted to a pure, testable function): weekly ordered on a delivery day, before it and after it; daily slot; one-time slot; Sunday = 7; week wrap-around.
- Unit tests for the export grouping (extracted pure function): two delivery dates on one recurring schedule produce two groups with correct dates; an order with `createdAt ≠ deliveryDate` is labelled with `deliveryDate`; a null `deliveryDate` is not labelled with `createdAt`.
- Admin add product: the stored `productName` equals `displayName`, not `name`/`description`; it survives a Firestore round-trip (fake_cloud_firestore), quantity changes and reopening; re-adding an existing product merges the quantity; the bill shows the display name.
- `flutter analyze`, `flutter test`, `flutter build web -t lib/main_dev.dart`, and a review of the final diff.

---

## 6. Questions to answer before implementation

1. **Weekly delivery rule (C1):** for a customer ordering *on* a delivery day, is delivery the same day, or the next occurrence? Or should the delivery date be "the first delivery day on/after the ordering cutoff"? Example: ordering Mon–Sat, delivery Sat, cutoff Sat 10:00; a Monday order delivers this Saturday under every option. The options differ when a schedule has several delivery days per week.
2. **Daily delivery slot (C2):** same day as the order, or the next day? Before or after the daily ordering end time?
3. **Orders with no `deliveryDate`:** in date filters, should they be excluded, or shown under a "No delivery date" bucket? On bills/WhatsApp, show "Not set"? At packing (S8), keep auto-filling `now()`, leave null, or block packing?
4. **Data check:** may I run a **read-only** script against dev (and, if you allow, prod) to count orders with `deliveryDate == null`, and orders whose `deliveryDate` day equals the `createdAt` day? This would confirm which cause produced the reported export.
5. **Scope:** the price/farmer differences P3/P4 — leave as-is? (Recommended: yes.)
6. **Backfill:** fix the names on order items already saved with the farmer name, or leave them? (Recommended: leave them, unless they appear on unfinalized bills.)

---

7. **Export grouping (E1):** group by `productId` (recommended), so legacy rows with a wrong snapshot merge with correct ones. Which snapshot name should the merged row show: the catalogue's current `displayName`, or the first item's snapshot?

---

## 7. Implementation results

### Issue 2 (product display name) - implemented

Delivery-date issue (Issue 1) was **not** touched.

| File | Change |
|---|---|
| `lib/features/admin/widgets/edit_order_dialog.dart` | `productName: product.name` -> `product.displayName` (via new helper); list title/selected header show `displayName`; search matches `displayName` and `name`; re-adding a product merges quantity |
| `lib/features/admin/utils/order_item_utils.dart` (new) | `addProductToOrderItems` pure helper |
| `farmer_packaging_list_page.dart` | CSV aggregation key now `productId_unit_category` (was `productName_...`) in the details export, summary export and on-screen list; exports' *Product Display Name* column uses the catalogue `displayName`, falling back to the item snapshot |
| `test/features/admin/order_item_utils_test.dart` (new) | 5 tests |

Before/after: added item `productName` = `product.name` -> `product.displayName`. Export *Product Name* column still = `products/{id}.name`.

Verification actually run: `flutter test` (47 passed), `flutter analyze` on touched files (no errors; only pre-existing infos/warnings), `flutter build web -t lib/main_dev.dart` (succeeded).
Not covered by automated tests: the CSV export itself (it is inline in the page and reads Firestore directly), and the on-screen list still shows the first item's stored name for merged rows. No existing data was changed; no backfill was run.
