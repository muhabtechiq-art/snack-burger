# CHATGPT PROJECT AUDIT HANDOFF — Snack Burger (`snack_burger`)

**Document Purpose:** Single self-contained handoff for ChatGPT (no repository access assumed).  
**Project:** Snack Burger / Al Mahab Menu — Flutter POS + Customer Ordering  
**Version:** `1.0.0+1` (`pubspec.yaml`)  
**Report Date:** 2026-06-22  
**Repository Root:** `snack_burger/`  
**Primary Reference Audit:** `PROJECT_MASTER_AUDIT.md` (2026-06-03), updated with work through 2026-06-22  

---

## 1. Executive Summary

Snack Burger is a **Flutter + Supabase** restaurant operations application targeting **Windows POS** (primary), with Android, iOS, and Web support. It serves two audiences:

1. **Customers** — digital menu per restaurant slug (`/:slug`), cart, delivery location, order submission via RPC, order tracking, optional daily sound, maintenance gate.
2. **Admin / Staff** — email/password login, realtime order dashboards, accept/reject, business day open/close, end-of-day reports, product CRUD (variants + addons), banner management (CRUD + drag-and-drop sort), printer settings, thermal receipt printing (Arabic CP864 raster), maintenance and daily-sound settings.

**Architecture style:** Layered UI + static `Supabase*Service` classes — **not** Clean Architecture. Tenant routing is **slug-first** (`/:slug`, `/:slug/admin/*`). Security is intended as **Flutter client filters + PostgreSQL RLS**, but RLS strict enforcement depends on **manual SQL execution** in Supabase Dashboard.

**Project size:** 187 Dart files in `lib/`, 32 test files, 32 SQL files in `supabase/`, 138 passing tests, `flutter analyze` clean.

**Completion estimates:**

| Dimension | % |
|-----------|---|
| Single restaurant (Snack Burger) production | **~88%** |
| Multi-tenant SaaS (10+ restaurants) | **~25%** |
| Security hardening (RLS + Storage) prepared vs enforced | **~45% prepared / ~15% likely enforced in prod** |
| Enterprise / 1000+ restaurants | **~8%** |
| **Overall weighted score** | **~42 / 100** |

**Technology stack:** Flutter 3.12+ · `provider` · `go_router` · Supabase (Postgres, Auth, Realtime, Storage, RPC) · `image_picker` · `flutter_image_compress` · `esc_pos_utils_plus` · `windows_printer` · `flutter_dotenv` (`.env` in assets).

**Critical context for ChatGPT:** Migration SQL files `c01_orders_rls_migration.sql`, `c02_catalog_rls_migration.sql`, and `c03_storage_rls_hardening.sql` exist in the repo with **`v_enable_strict_mode := false`** / **`v_enable_rls := false`** by default. Production DB state is **unknown** — legacy permissive policies may still be active until an operator runs Strict Mode manually in Supabase SQL Editor.

---

## 2. Final Scores Table

Scores from `PROJECT_MASTER_AUDIT.md` (2026-06-03) with **adjustments through 2026-06-22**.

| Category | Jun 3 | **Jun 22** | Notes |
|----------|-------|------------|-------|
| Architecture | 52 | **54** | Server-side `restaurant_id` filters on catalog; `ProductImageUploadService` |
| Database | 38 | **42** | C-01/C-02/C-03 SQL authored; not auto-applied |
| Security | 22 | **30** | RLS designed; Flutter scope improved; prod likely still permissive |
| Performance | 41 | **44** | Catalog server filters; image compression off UI thread |
| Scalability | 25 | **27** | Full-table order streams remain |
| Maintainability | 50 | **52** | Banner module, more tests |
| Readability | 62 | **62** | Arabic comments, consistent naming |
| Error Handling | 55 | **58** | Product upload try/catch, 30s timeout, SnackBars |
| Testing | 28 | **42** | 48 → **138** unit tests; no integration/E2E |
| Realtime | 35 | **35** | Order streams largely unfiltered server-side |
| Printing | 55 | **55** | Hardcoded Snack Burger branding on receipts |
| Offline | 18 | **18** | Online-first only |
| Monitoring | 12 | **12** | `AppTelemetry` → `debugPrint` only |
| SaaS | 15 | **18** | Migration scaffolding only |
| **Overall** | **38** | **42** | MVP single-tenant improved; not SaaS-ready |

### Multi-Tenant Readiness Percentages

| Scale | Jun 3 | **Jun 22** |
|-------|-------|------------|
| 1 restaurant | 85% | **88%** |
| 10 restaurants | 32% | **35%** |
| 30 restaurants | 32% | **35%** |
| 100 restaurants | 18% | **20%** |
| 1000 restaurants | 8% | **8%** |
| 10000 restaurants | <5% | **<5%** |

### Audit Document Status (`PROJECT_MASTER_AUDIT.md`)

| Field | Value |
|-------|-------|
| Status | 🔴 Not Production-Ready for Multi-Tenant SaaS |
| Current Mode | Single-Tenant (Snack Burger) with Multi-Tenant Scaffolding |
| Target | Global SaaS — thousands of restaurants |

---

## 3. What Was Inspected

| Area | Method |
|------|--------|
| Full project audit document | `PROJECT_MASTER_AUDIT.md` (991 lines) |
| All SQL in `supabase/` | 32 files — schemas, RPCs, RLS migrations C-01/C-02/C-03 |
| Flutter `lib/` structure | 187 Dart files — admin, customer, services, state, core |
| Product edit / image upload path | `product_form_controller.dart`, `product_form_page.dart`, `image_pick_upload_service.dart`, `product_image_upload_service.dart` |
| Banner admin path | `banners_admin_screen.dart`, `banner_form_dialog.dart`, `banner_image_upload_service.dart` |
| Catalog tenant isolation (Phase 2.4) | `supabase_product_service.dart`, `supabase_banner_service.dart`, `product_repository.dart` |
| C-02 catalog RLS migration | `c02_catalog_rls_migration.sql` — Steps 1–4 review (pre-strict) |
| C-03 storage RLS migration | `c03_storage_rls_hardening.sql` |
| Storage policies | `storage_product_images_policies.sql`, `daily_sounds_storage_policies.sql` |
| RLS policy inventory | Cross-reference all `CREATE POLICY` in `supabase/` |
| Legacy policy redundancy analysis | Post C-02/C-03 design vs `*_public_read`, `*_anon_*` |
| Auth / admin boundary | `auth_notifier.dart`, `auth_middleware.dart`, `admin_repositories.dart` |
| Routing | `app_router.dart` |
| Bootstrap | `main.dart` |
| Test suite | 32 test files; `flutter test` run 2026-06-22 |
| Static analysis | `flutter analyze` run 2026-06-22 |
| Strict Mode execution attempt | Blocked — no `psql`/Supabase CLI/`DATABASE_URL` in environment |

---

## 4. Security & RLS Findings

### 4.1 RLS Summary by Table (from audit + migration design)

| Table | RLS in Repo | Tenant-Scoped? | Risk |
|-------|-------------|----------------|------|
| `orders` | C-01 prepared; base schema not in repo | ❌ until C-01 applied | **CRITICAL** |
| `products` | ✅ legacy `USING (true)` | ❌ until C-02 strict | **CRITICAL** |
| `product_addons` | ✅ legacy `USING (true)` | ❌ until C-02 strict | **CRITICAL** |
| `product_variants` | ✅ legacy `USING (true)` | ❌ until C-02 strict | **CRITICAL** |
| `banners` | ✅ legacy `USING (true)` | ❌ until C-02 strict | **CRITICAL** |
| `business_days` | ✅ | ❌ auth read all (`business_days_schema.sql`) | **HIGH** |
| `app_settings` | ✅ | ❌ global row, any auth update | **CRITICAL** |
| `restaurants` | ✅ | Public read active only | **LOW** |
| `profiles` | ✅ (`profiles_rls.sql`) | Own row only; not tenant-scoped | **MEDIUM** |
| `storage.objects` (product-images) | ✅ legacy bucket-only | ❌ until C-03 strict | **HIGH** |
| `storage.objects` (daily-sounds) | ✅ legacy bucket-only | ❌ until C-03 strict | **HIGH** |

### 4.2 C-02 Catalog RLS (`supabase/c02_catalog_rls_migration.sql`)

**Helper functions (require C-02 §6 before C-03):**
- `catalog_matches_admin_profile(p_restaurant_id text)` — joins `profiles` ↔ `restaurants.id` or `slug` via `auth.uid()`
- `catalog_product_id_matches_admin_profile(p_product_id bigint)` — addons/variants via parent `products.restaurant_id`

**20 policies `catalog_c02_*` (5 per table):**
- `catalog_c02_select_anon_interim` — anon SELECT `USING (true)` (interim for customer menu)
- `catalog_c02_select/insert/update/delete_authenticated_tenant` — authenticated + tenant match

**Strict Mode §9 (`v_enable_strict_mode := false` default):** drops 17 legacy policies:
- Per table `products`, `product_addons`, `product_variants`, `banners`: `{table}_public_read`, `{table}_anon_insert`, `{table}_anon_update`, `{table}_anon_delete` (16 total)
- Plus `banners_authenticated_update` on `banners`

**Conflict:** While legacy + C-02 coexist (strict=false), PostgreSQL permissive OR logic means **legacy `USING (true)` nullifies C-02 restrictions**.

### 4.3 C-01 Orders RLS (`supabase/c01_orders_rls_migration.sql`)

**Helper:** `orders_matches_admin_profile(p_order_restaurant_id, p_order_slug)`

**3 policies `orders_c01_*`:**
- `orders_c01_select_anon_interim` — anon SELECT all (interim)
- `orders_c01_select_authenticated_tenant` — admin SELECT tenant-scoped
- `orders_c01_update_authenticated_admin` — admin UPDATE tenant-scoped
- **No INSERT policy** — orders created via `submit_customer_order` RPC (SECURITY DEFINER)

**Default:** `v_enable_rls := false` — does not auto-enable RLS on `orders`.

### 4.4 RPC Security

| RPC | File | SECURITY | Auth Grant | Tenant Check |
|-----|------|----------|------------|--------------|
| `submit_customer_order` | `submit_customer_order_rpc.sql` | DEFINER | anon+auth | slug → restaurant; open day lock |
| `open_business_day` | `business_days_schema.sql` | DEFINER | auth | ❌ no profile check |
| `close_business_day` | `business_days_schema.sql` | DEFINER | auth | ❌ no profile check |
| `save_product_with_addons` | `rpc_save_product_with_addons.sql` | **INVOKER** | anon+auth | RLS-dependent |
| `purge_old_rejected_orders` | `purge_old_rejected_orders.sql` | DEFINER | anon+auth | ❌ global delete |
| `get_customer_delivery_by_phone` | `customer_location_full_setup.sql` | DEFINER | anon+auth | phone only |
| `update_customer_location` | `customer_location_full_setup.sql` | DEFINER | anon+auth | phone only |

### 4.5 Authentication & Authorization

- Admin: Supabase email/password → `profiles.restaurant_id` + `role` → `AdminProfileSession` (`lib/core/auth/admin_profile_session.dart`)
- Customer: **anonymous** — embedded anon key
- `profiles.role` stored but **never enforced** in `auth_middleware.dart` or UI gates
- `AdminOrderRepository.resolveRestaurantId` (`lib/admin_features/data/admin_repositories.dart`) **overrides URL slug** with `AdminProfileSession.restaurantId`
- No validation that URL `/:slug/admin` matches `profiles.restaurant_id`

### 4.6 Cross-Tenant Access Vectors (documented)

| Vector | File | Mechanism |
|--------|------|-----------|
| Full-table order stream | `lib/services/supabase_order_service.dart` | `.stream(primaryKey: ['id'])` + client filter |
| `_orderMatchesSlug` empty match | `lib/services/supabase_order_service.dart` ~847 | Returns true if slug AND restaurant_id empty |
| Fallback to snack_burger | `lib/models/delivery_order_model.dart` ~155 | Silent tenant assignment |
| Global maintenance | `lib/services/supabase_app_settings_service.dart` | Blocks all tenants |
| Phone-global profile | `supabase/customer_location_full_setup.sql` | Same phone = shared address across tenants |
| Order UPDATE by id only | `lib/services/supabase_order_service.dart` | No tenant WHERE |
| Unfiltered notification listener | `lib/services/order_realtime_notification_service.dart` | All INSERT events |

### 4.7 Secrets

- `SUPABASE_URL`, `SUPABASE_ANON_KEY` in `.env` — listed as **asset** in `pubspec.yaml` (ships in binary)
- No service role key in app ✅
- `.env.example` at repo root documents expected vars

---

## 5. Flutter Architecture Findings

### 5.1 Structure

```
lib/
├── main.dart, app.dart
├── admin_features/     # Back-office (orders, products, banners, settings, reports, auth)
├── customer_features/  # Menu, cart, delivery, order status
├── core/               # auth, router, config, utils, cache, observability
├── dev/                # SnackBurgerProductSeeder (invoked from main.dart)
├── models/             # 15 data classes
├── services/           # ~40 files — Supabase, printing, image upload
└── state/              # ChangeNotifiers (tenant, cart, business day, settings)
```

### 5.2 Dependency Flow

```
Screens → Controllers/Notifiers → Repositories (thin) → Supabase*Service → Supabase Client
```

**Violations:** God services (`supabase_order_service.dart` ~1100+ lines, `supabase_product_service.dart` ~1500+ lines); no use-case layer; many screens call services directly.

### 5.3 Controllers

| Controller | File |
|------------|------|
| `ProductFormController` | `lib/admin_features/products/product_form_controller.dart` |
| `ProductsAdminController` | `lib/admin_features/products/products_admin_controller.dart` |
| `CustomerMenuController` | `lib/customer_features/menu/customer_menu_controller.dart` |
| `CustomerMenuBannersController` | `lib/customer_features/menu/customer_menu_banners_controller.dart` |
| `AdminOrderNotificationController` | `lib/admin_features/orders/admin_order_notification_controller.dart` |

### 5.4 Repositories

| Repository | File | Note |
|------------|------|------|
| `ProductRepository` | `lib/services/product_repository.dart` | `resolveRestaurantDocId` centralizes tenant doc id |
| `BannerRepository` | `lib/services/banner_repository.dart` | |
| `AdminOrderRepository` | `lib/admin_features/data/admin_repositories.dart` | Session overrides slug |
| `AdminProductRepository` | `lib/admin_features/data/admin_repositories.dart` | |
| `CustomerOrderRepository` | `lib/customer_features/data/customer_order_repository.dart` | |

### 5.5 State Management

- **Provider + ChangeNotifier** — `ActiveRestaurantNotifier`, `AuthNotifier`, `AppSettingsNotifier`, `BusinessDayNotifier`, `CartNotifier`, `DeliveryLocationNotifier`
- Registered in `lib/main.dart` via `MultiProvider`
- Global singletons — risk of tenant state bleed on navigation (`business_day_notifier.dart`, `app_settings_notifier.dart`)

### 5.6 Navigation (`lib/core/router/app_router.dart`)

- `go_router` with `AuthMiddleware.redirectAsync`
- Root `/` → hardcoded redirect `/snack_burger` (single-tenant UX)
- Admin routes under `/:slug/admin/*` wrapped in `AdminWrapper`

### 5.7 Phase 2.4 — Catalog Flutter Tenant Filters (DONE in code)

| Service | Change |
|---------|--------|
| `lib/services/supabase_product_service.dart` | `.eq('restaurant_id', normalized)` on fetch, watch, `fetchProductById`; `saveProduct` with `tenantRestaurantId` |
| `lib/services/supabase_banner_service.dart` | `.eq('restaurant_id', normalized)` on fetch and streams |
| `lib/services/product_repository.dart` | `resolveRestaurantDocId` / `resolveRestaurantDocIdWithSource` |

### 5.8 Product Image Upload Fix (2026-06-22)

| File | Change |
|------|--------|
| `lib/services/product_image_upload_service.dart` | **NEW** — `compute()` isolate compression, `[ProductImageUpload]` logs, 30s upload timeout |
| `lib/services/image_pick_upload_service.dart` | 30s timeout on `uploadBinary`; failure message constant |
| `lib/services/image_upload_exception.dart` | `productImageUploadFailureMessage` constant |
| `lib/admin_features/products/product_form_controller.dart` | Uses `ProductImageUploadService`; `_uploadBytes` separate from preview; comprehensive try/catch |
| `lib/admin_features/products/product_form_page.dart` | Loading overlay "جاري معالجة الصورة..."; save button disabled when `isBusy` |

### 5.9 Banner Admin (implemented)

| File | Feature |
|------|---------|
| `lib/admin_features/banners/banners_admin_screen.dart` | CRUD, toggle active, `ReorderableListView` sort |
| `lib/admin_features/banners/banner_form_dialog.dart` | Image pick with loading; preview compression |
| `lib/admin_features/banners/banner_sort_order.dart` | Sort order logic |
| `lib/services/banner_image_upload_service.dart` | Upload to `product-images` bucket at `{tenant}/banners/{id}.jpg` |
| `lib/services/banner_image_diag_log.dart` | Diagnostic logs (not removed) |

---

## 6. Supabase / Database Findings

### 6.1 Tables

| Table | PK | Tenant Columns | In Repo Schema? |
|-------|-----|----------------|-----------------|
| `restaurants` | `id` text | `slug` unique | ✅ `restaurants_table_schema.sql` |
| `business_days` | uuid | `restaurant_id`, `slug` | ✅ `business_days_schema.sql` |
| `orders` | bigint | `restaurant_id` uuid, `slug`, `business_day_id` | ⚠️ partial migrations only |
| `products` | bigint | `restaurant_id` text | ✅ `products_table_schema.sql` |
| `product_addons` | bigint | via `product_id` | ✅ `product_addons_table_schema.sql` |
| `product_variants` | bigint | via `product_id` | ✅ `product_variants_table_schema.sql` |
| `banners` | uuid | `restaurant_id` | ✅ `banners_table_schema.sql` |
| `app_settings` | `id='global'` | **none** | ✅ `app_settings_schema.sql` |
| `profiles` | uuid | `restaurant_id`, `role` | ⚠️ `profiles_rls.sql` only |

### 6.2 Relationships

```
restaurants
  ├── business_days → orders (business_day_id)
  ├── products → product_addons, product_variants
  ├── banners
  └── profiles (admin staff)
orders.restaurant_id → restaurants.restaurant_uuid (uuid)
orders.slug → restaurants.slug
```

**Identity complexity:** `restaurant_id` is **text** on products/restaurants.id but **uuid** on orders.restaurant_id. Flutter resolves via slug or text id through `catalog_matches_admin_profile` and `ProductRepository.resolveRestaurantDocId`.

### 6.3 Indexes (in repo)

| Table | Index |
|-------|-------|
| `restaurants` | `restaurants_slug_idx` |
| `business_days` | unique partial open day per restaurant; status; opened_at |
| `orders` | `business_day_id`; composite with status; unique day order number |
| `banners` | `(restaurant_id, is_active, sort_order)` |

**Missing (recommended):** `orders(slug, status, created_at)`, `products(restaurant_id, is_available, category)`.

### 6.4 Functions & RPCs

See Section 4.4. No triggers or views in repository.

### 6.5 Backup Tables (from migrations)

| Table | Source |
|-------|--------|
| `orders_rls_policies_c01_backup` | `c01_orders_rls_migration.sql` |
| `catalog_rls_policies_c02_backup` | `c02_catalog_rls_migration.sql` |
| `storage_rls_policies_c03_backup` | `c03_storage_rls_hardening.sql` |

### 6.6 Migration Execution Model

- **All SQL is manual** — Supabase Dashboard → SQL Editor
- **No** Supabase CLI migration history in repo
- **No** automated migration runner
- Strict mode requires operator to set `v_enable_strict_mode := true` in §9 DO block and re-run **only that section**

---

## 7. Storage Findings

### 7.1 Buckets

| Bucket | Public | Path Convention | Flutter Constant |
|--------|--------|-----------------|------------------|
| `product-images` | yes | `{tenant}/{productId}/{file}`; `{tenant}/banners/{bannerId}.jpg` | `ImagePickUploadService.bucketName` |
| `daily-sounds` | yes | `{slug}/{timestamp}_{file}` | `DailySoundUploadService.bucketName` |

**No separate banner bucket** — banners use `product-images` (`supabase/banners_table_schema.sql` comment references `storage_product_images_policies.sql`).

### 7.2 Legacy Storage Policies

**`supabase/storage_product_images_policies.sql`:**

| Policy | Op | Roles | Rule |
|--------|-----|-------|------|
| `product_images_public_read` | SELECT | public | `bucket_id = 'product-images'` |
| `product_images_anon_insert` | INSERT | anon, authenticated | bucket only |
| `product_images_anon_update` | UPDATE | anon, authenticated | bucket only |
| *(no DELETE policy)* | | | |

**`supabase/daily_sounds_storage_policies.sql`:**

| Policy | Op | Roles |
|--------|-----|-------|
| `daily_sounds_public_read` | SELECT | public |
| `daily_sounds_anon_insert` | INSERT | anon, authenticated |
| `daily_sounds_anon_update` | UPDATE | anon, authenticated |
| `daily_sounds_anon_delete` | DELETE | anon, authenticated |

**Risk:** Any anon client can write/delete any path in bucket — **cross-tenant** if path is guessed. Flutter uses tenant-prefixed paths but RLS does not enforce until C-03 strict.

### 7.3 C-03 Prepared Policies (`supabase/c03_storage_rls_hardening.sql`)

**8 policies `storage_c03_*`:**

| Bucket | Policies |
|--------|----------|
| `product-images` | select_public, insert/update/delete authenticated + `catalog_matches_admin_profile(storage_object_tenant_folder(name))` |
| `daily-sounds` | same pattern |

**Helper:** `storage_object_tenant_folder(p_name text)` — first path segment = tenant key.

**Strict §7 drops 7 legacy policies** when `v_enable_strict_mode := true`. SELECT remains via `storage_c03_*_select_public` — `getPublicUrl` unaffected.

### 7.4 Storage Classification (from security review)

| Policy | Classification |
|--------|----------------|
| `*_public_read` | Permissive but acceptable for public menu images (interim) |
| `*_anon_insert/update/delete` | **Must delete/replace** — cross-tenant write |
| `storage_c03_*` authenticated tenant | Target state |

---

## 8. Multi-Tenant SaaS Readiness

| Scale | Readiness | Key Limiters |
|-------|-----------|--------------|
| **10 restaurants** | **~35%** | RLS not enforced; no per-tenant settings; no provisioning; admin slug guard missing |
| **100 restaurants** | **~20%** | + no pagination; full-table streams; global phone profiles; no observability |
| **1000 restaurants** | **~8%** | + no billing; no audit log; single Supabase project bottleneck |
| **10000 restaurants** | **<5%** | Requires sharding/multi-project, CDN, platform layer |

### SaaS Capability Matrix

| Capability | Status |
|------------|--------|
| DB-enforced tenant isolation | 🟡 prepared, not proven |
| Per-tenant settings | ❌ global `app_settings` |
| Staff RBAC | ❌ role stored, not enforced |
| Provisioning UI/API | ❌ manual SQL |
| Billing/subscriptions | ❌ |
| Monitoring/APM | ❌ debugPrint only |
| Audit log | ❌ |
| Rate limiting | ❌ |
| Custom domains | ❌ |
| CI quality gate | ❌ deploy-only workflow |

---

## 9. Production Readiness

### Can It Launch?

**Yes — conditional** for **single restaurant (Snack Burger)** on Windows POS + customer web, with manual Supabase setup and accepted security debt.

### Launch Blockers

| Blocker | Severity | Single Tenant? |
|---------|----------|----------------|
| C-02/C-01/C-03 strict not executed in Supabase | High security | Short-term acceptable in trusted env |
| Storage anon write | High | Obscurity-based risk |
| Windows UI freeze (images) | Medium | Mitigated 2026-06-22; verify manually |
| No Sentry/Crashlytics | Medium | Operational |
| No CI test gate | Medium | `.github/workflows/deploy-github-pages.yml` deploy only |
| `SnackBurgerProductSeeder` in `main.dart` | Medium | Accidental seed risk |
| Global `app_settings` maintenance | Low for 1 tenant | OK |

### Verdict by Scenario

| Scenario | Verdict |
|----------|---------|
| Snack Burger only, controlled Windows POS | **Conditional GO** after C-01/C-02/C-03 strict in Supabase |
| Public multi-tenant SaaS | **NO-GO** |
| Enterprise customers | **NO-GO** |

---

## 10. Critical Issues

| ID | File(s) | Problem | Severity |
|----|---------|---------|------------|
| C-01 | `supabase/c01_orders_rls_migration.sql`, `lib/services/supabase_order_service.dart` | Orders RLS not in repo base; likely not enforced in prod | Cross-tenant order breach |
| C-02 | `supabase/products_table_schema.sql`, `banners_table_schema.sql`, `product_addons_table_schema.sql`, `product_variants_table_schema.sql` | Legacy `USING (true)` catalog policies | Any client CRUD any tenant catalog |
| C-02-S | `supabase/c02_catalog_rls_migration.sql` | Legacy + C-02 OR'd while strict=false | C-02 policies ineffective |
| C-03 | `supabase/storage_product_images_policies.sql`, `daily_sounds_storage_policies.sql` | Storage anon write/delete bucket-wide | Cross-tenant file overwrite |
| C-04 | `lib/services/supabase_order_service.dart` | `.stream(primaryKey: ['id'])` on orders without server filter | All tenants' order metadata on wire |
| C-05 | `lib/services/supabase_order_service.dart` | `updateOrderStatus` / `updateRejectionReason` by id only | Cross-tenant order manipulation |
| C-06 | `supabase/purge_old_rejected_orders.sql` | Global DELETE; granted to anon | Cross-tenant data destruction |
| C-07 | `lib/core/auth/auth_middleware.dart`, `lib/admin_features/data/admin_repositories.dart` | No slug ↔ profile validation; session overrides slug | Admin cross-tenant access |
| C-08 | `supabase/app_settings_schema.sql`, `lib/services/supabase_app_settings_service.dart` | Single global settings row | One tenant maintenance stops all |
| C-09 | `supabase/submit_customer_order_rpc.sql` | Historical: orders.restaurant_id linkage (Phase 1 migration addresses) | RLS complexity |

---

## 11. High Issues

| ID | File(s) | Problem |
|----|---------|---------|
| H-01 | `lib/services/supabase_product_service.dart` | Was full fetch/stream — **partially fixed** Phase 2.4 with server filter |
| H-02 | `lib/services/supabase_product_service.dart`, `product_repository.dart` | `fetchProductById` / `deleteProduct` by id only — RLS must cover |
| H-03 | `supabase/business_days_schema.sql` | `business_days_authenticated_read` USING (true) |
| H-04 | `supabase/business_days_schema.sql` | `open_business_day` / `close_business_day` no profile check |
| H-05 | `supabase/customer_location_full_setup.sql` | Phone-global customer profile |
| H-06 | `supabase/storage_product_images_policies.sql` | No path tenant isolation (C-03 addresses) |
| H-07 | `lib/main.dart`, `lib/state/business_day_notifier.dart` | Global singleton state bleed |
| H-08 | `lib/core/config/printer_config.dart`, receipt files | Hardcoded "Snack Burger" branding |
| H-09 | `supabase/patch_rpc_param_names.sql` vs `customer_location_full_setup.sql` | profiles.restaurant_id drift |
| H-10 | `supabase/rpc_save_product_with_addons.sql` | SECURITY INVOKER + anon grant |
| H-11 | `lib/services/order_realtime_notification_service.dart` | Unfiltered INSERT listener |
| H-12 | `pubspec.yaml` | `.env` bundled in assets |
| H-13 | `lib/admin_features/banners/`, Windows | Intermittent UI freeze on banner image pick (partially mitigated) |

---

## 12. Medium Issues

| ID | File(s) | Problem |
|----|---------|---------|
| M-01 | `lib/services/supabase_banner_service.dart` | Banner stream — **server filter added** Phase 2.4; verify |
| M-02 | Banner/product mutations by id without tenant in WHERE | RLS-dependent |
| M-03 | `product_addons`/`product_variants` no `restaurant_id` column | C-02 uses parent join |
| M-04 | `lib/services/supabase_business_day_service.dart` | fetchById ID-only |
| M-05 | `lib/core/router/app_router.dart`, landing | Hardcoded `/snack_burger` redirect |
| M-06 | `lib/state/active_restaurant_notifier.dart` | Synthetic tenant for unknown slug |
| M-07 | Order/product lists | No pagination |
| M-08 | `lib/core/auth/auth_notifier.dart` | Role never enforced |
| M-09 | `lib/models/end_of_day_report_model.dart` | No restaurantId on model |
| M-10 | Missing indexes | `orders(slug, status)`, `products(restaurant_id)` |
| M-11 | `lib/main.dart` | `SnackBurgerProductSeeder` in prod path |
| M-12 | `.github/workflows/deploy-github-pages.yml` | No analyze/test in CI |

---

## 13. Low Issues

| ID | File(s) | Problem |
|----|---------|---------|
| L-01 | `lib/services/order_realtime_notification_service.dart` | Channel id `snack_burger_new_orders` |
| L-02 | `supabase/business_day_closing_time_migration.sql` | Unused global column |
| L-03 | `lib/dev/snack_burger_product_seeder.dart` | Dev-only single tenant |
| L-04 | `lib/models/order_model.dart` | Legacy unused model |
| L-05 | `lib/services/printer_preferences.dart` | Global printer key |
| L-06 | CI workflow | Deploy only, no test gate |
| L-07 | GitHub Pages | `/snack-burger/` base href hardcoded |
| L-08 | `lib/services/banner_image_diag_log.dart` | Verbose diag logs in production code |
| L-09 | `lib/admin_features/banners/banner_form_dialog.dart` | `parseBannerSortOrder()` may be unused |

---

## 14. Positive Findings

| Area | Evidence |
|------|----------|
| Slug-first multi-tenant routing | `lib/core/router/app_router.dart` |
| Feature folder separation | `admin_features/`, `customer_features/` |
| RPC atomic order submit | `supabase/submit_customer_order_rpc.sql` — open business day lock |
| Business day domain model | `supabase/business_days_schema.sql` — one open day per restaurant |
| Receipt pipeline quality | `lib/services/receipt_escpos_builder.dart`, `receipt_cashier_layout.dart` — Arabic CP864 raster |
| Env-based Supabase config | `lib/core/config/supabase_env.dart` |
| Global error handlers | `lib/main.dart` — FlutterError, PlatformDispatcher, runZonedGuarded |
| Telemetry hooks | `lib/core/observability/app_telemetry.dart` — correlation IDs on orders |
| Catalog server-side tenant filters | `lib/services/supabase_product_service.dart`, `supabase_banner_service.dart` |
| C-01/C-02/C-03 migration design | Phased strict mode, backup tables, rollback comments |
| Product image upload hardening | `lib/services/product_image_upload_service.dart` — isolate + timeout |
| Banner admin complete | CRUD, reorder, image upload with cache-bust |
| Test growth | 48 → 138 tests |
| `flutter analyze` clean | 2026-06-22 |
| Menu catalog cache | `lib/core/cache/menu_catalog_cache.dart` |
| Resilient banner/product streams | Reconnect with backoff in services |
| Admin profile session | `lib/core/auth/admin_profile_session.dart` |

---

## 15. Evidence From Repository

### 15.1 Legacy Catalog Policies (permissive)

From `supabase/products_table_schema.sql`:

```sql
CREATE POLICY "products_public_read" ON public.products FOR SELECT TO public USING (true);
CREATE POLICY "products_anon_insert" ON public.products FOR INSERT TO anon, authenticated WITH CHECK (true);
```

Same pattern in `product_addons_table_schema.sql`, `product_variants_table_schema.sql`, `banners_table_schema.sql`, `banners_rls_fix.sql`.

### 15.2 C-02 Strict Drop List

From `supabase/c02_catalog_rls_migration.sql` §9 — drops `{table}_public_read`, `{table}_anon_insert/update/delete` for 4 tables + `banners_authenticated_update`.

### 15.3 C-03 Strict Drop List

From `supabase/c03_storage_rls_hardening.sql` §7 — drops 7 legacy storage policies on `product-images` and `daily-sounds`.

### 15.4 Product Path Convention

From `lib/services/image_pick_upload_service.dart`:

```dart
static const String bucketName = 'product-images';
// Path: {restaurantId}/{productId}/{fileName}
```

From `lib/services/banner_image_upload_service.dart`:

```dart
// Path: {restaurantId}/banners/{bannerId}.jpg
// Uses same bucket: product-images
```

### 15.5 Admin Session Override

From `lib/admin_features/data/admin_repositories.dart` — `resolveRestaurantId` returns `AdminProfileSession.restaurantId` when set, overriding URL slug.

### 15.6 Root Redirect

From `lib/core/router/app_router.dart`:

```dart
redirect: (_, _) => '/snack_burger',
```

### 15.7 Test Count

```
flutter test → 138 passed (2026-06-22)
flutter analyze → No issues found! (2026-06-22)
```

### 15.8 Strict Mode Not Executed From CI/Agent

Environment lacks `psql`, `npx`/Supabase CLI, `DATABASE_URL`. Only `SUPABASE_URL` + `SUPABASE_ANON_KEY` in `.env`. Strict Mode SQL must be run manually in Supabase Dashboard.

---

## 16. Files Reviewed

### SQL (`supabase/` — 32 files)

| File | Purpose |
|------|---------|
| `c01_orders_rls_migration.sql` | Orders RLS C-01 |
| `c02_catalog_rls_migration.sql` | Catalog RLS C-02 (702 lines) |
| `c03_storage_rls_hardening.sql` | Storage RLS C-03 (445 lines) |
| `products_table_schema.sql` | Products schema + legacy RLS |
| `product_addons_table_schema.sql` | Addons schema + legacy RLS |
| `product_variants_table_schema.sql` | Variants schema + legacy RLS |
| `banners_table_schema.sql` | Banners schema + legacy RLS |
| `banners_rls_fix.sql` | Banner UPDATE policy fix |
| `storage_product_images_policies.sql` | Storage legacy product-images |
| `daily_sounds_storage_policies.sql` | Storage legacy daily-sounds |
| `business_days_schema.sql` | Business days table + open/close RPC |
| `submit_customer_order_rpc.sql` | Order submit RPC |
| `rpc_save_product_with_addons.sql` | Product save RPC |
| `purge_old_rejected_orders.sql` | Global purge RPC |
| `app_settings_schema.sql` | Global settings |
| `profiles_rls.sql` | Admin profile RLS |
| `restaurants_table_schema.sql` | Restaurants table |
| `customer_location_full_setup.sql` | Customer profile RPCs |
| `customer_profile_location_rpc.sql` | Location RPCs |
| `profiles_customer_location.sql` | Profile columns |
| `patch_rpc_param_names.sql` | RPC param patches |
| `patch_rename_update_customer_location.sql` | RPC rename |
| `orders_delivery_columns.sql` | Order delivery columns |
| `orders_rejection_reason.sql` | Rejection reason column |
| `phase1_orders_restaurant_id_migration.sql` | Orders restaurant_id backfill |
| `phase1_orders_link_restaurant_uuid_migration.sql` | UUID linkage |
| `phase1_business_days_link_restaurant_uuid_migration.sql` | Business days UUID |
| `business_day_order_number_migration.sql` | Per-day order numbers |
| `business_day_closing_time_migration.sql` | Closing time |
| `daily_sound_migration.sql` | Daily sound columns |
| `restaurants_restaurant_uuid_migration.sql` | restaurant_uuid column |
| `fix_attach_open_business_day_orders.sql` | Data fix script |

### Flutter — Core

| File | Purpose |
|------|---------|
| `lib/main.dart` | Bootstrap |
| `lib/app.dart` | MaterialApp |
| `lib/core/router/app_router.dart` | All routes |
| `lib/core/auth/auth_notifier.dart` | Auth state |
| `lib/core/auth/auth_middleware.dart` | Route guards |
| `lib/core/auth/admin_profile_session.dart` | Admin session persistence |
| `lib/core/config/restaurant_ids.dart` | Tenant ID constants |
| `lib/core/config/supabase_env.dart` | Env loading |
| `lib/core/utils/order_tenant_match.dart` | Client tenant matching |
| `lib/core/utils/image_compressor.dart` | Image compression |
| `lib/core/observability/app_telemetry.dart` | Telemetry |

### Flutter — Services

| File | Purpose |
|------|---------|
| `lib/services/supabase_order_service.dart` | Orders (~1100+ lines) |
| `lib/services/supabase_product_service.dart` | Products (~1500+ lines) |
| `lib/services/supabase_banner_service.dart` | Banners |
| `lib/services/supabase_business_day_service.dart` | Business days |
| `lib/services/supabase_app_settings_service.dart` | Global settings |
| `lib/services/supabase_restaurant_service.dart` | Restaurant fetch |
| `lib/services/supabase_customer_location_service.dart` | Customer location RPCs |
| `lib/services/product_repository.dart` | Product repository |
| `lib/services/banner_repository.dart` | Banner repository |
| `lib/services/image_pick_upload_service.dart` | Storage upload |
| `lib/services/product_image_upload_service.dart` | Isolate upload pipeline |
| `lib/services/banner_image_upload_service.dart` | Banner images |
| `lib/services/daily_sound_upload_service.dart` | Daily sounds |
| `lib/services/order_realtime_notification_service.dart` | Desktop notifications |
| `lib/services/receipt_escpos_builder.dart` | Receipt generation |
| `lib/services/receipt_escpos_printer.dart` | Print transport |

### Flutter — Admin Features

| File | Purpose |
|------|---------|
| `lib/admin_features/products/product_form_controller.dart` | Product form logic |
| `lib/admin_features/products/product_form_page.dart` | Product form UI |
| `lib/admin_features/products/products_admin_screen.dart` | Product list |
| `lib/admin_features/products/widgets/product_image_picker_field.dart` | Image picker UI |
| `lib/admin_features/banners/banners_admin_screen.dart` | Banner admin |
| `lib/admin_features/banners/banner_form_dialog.dart` | Banner form |
| `lib/admin_features/banners/banner_sort_order.dart` | Sort logic |
| `lib/admin_features/data/admin_repositories.dart` | Admin repositories |
| `lib/admin_features/dashboard/orders_dashboard_screen.dart` | Orders UI |
| `lib/admin_features/settings/*.dart` | Settings screens |

### Flutter — Customer Features

| File | Purpose |
|------|---------|
| `lib/customer_features/menu/customer_menu_screen.dart` | Menu UI |
| `lib/customer_features/menu/customer_menu_controller.dart` | Menu logic |
| `lib/customer_features/menu/customer_menu_banners_controller.dart` | Banners on menu |

### Tests (32 files, 138 tests)

| File | Coverage Area |
|------|---------------|
| `test/features/tenant/product_form_controller_test.dart` | Product form + pick |
| `test/services/supabase_product_service_products_filter_test.dart` | Server filter |
| `test/services/supabase_product_service_fetch_by_id_test.dart` | fetchById |
| `test/services/supabase_product_service_save_product_test.dart` | saveProduct |
| `test/services/supabase_banner_service_banners_filter_test.dart` | Banner filter |
| `test/services/banner_image_upload_service_test.dart` | Banner upload |
| `test/admin_features/banner_form_dialog_test.dart` | Banner form |
| `test/admin_features/banner_sort_order_test.dart` | Sort order |
| `test/core/utils/order_tenant_match_test.dart` | Tenant match |
| `test/services/supabase_order_service_*_stream_test.dart` | Order streams (5 files) |
| `test/services/receipt_escpos_builder_test.dart` | Receipts |
| + 20 more test files | Utils, models, widgets |

### Documentation

| File | Purpose |
|------|---------|
| `PROJECT_MASTER_AUDIT.md` | Official master audit (Jun 3, 2026) |
| `pubspec.yaml` | Dependencies, version, assets |
| `.env.example` | Env template |

---

## 17. Test Results

**Date:** 2026-06-22

```
flutter analyze
→ No issues found! (ran in 32.9s)

flutter test
→ 138 tests passed
```

**Prior audit (Jun 3):** 48 tests documented in `PROJECT_MASTER_AUDIT.md`.

**Gaps:** No integration tests against live Supabase; no E2E; no two-tenant security isolation tests; no widget tests for full product form page on Windows.

---

## 18. Final Verdict

### Invest?

| Lens | Verdict |
|------|---------|
| **SaaS platform** | **No** — scaffolding only; security not DB-proven |
| **Single-restaurant POS product** | **Conditional Yes** — working flows, real domain depth |

### Production Deploy?

| Scenario | Verdict |
|----------|---------|
| Snack Burger Windows POS + web menu | **Conditional GO** — execute C-01/C-02/C-03 strict in Supabase first; verify image upload on Windows |
| Multi-tenant public launch | **NO-GO** |
| Enterprise | **NO-GO** |

### Conditions for Single-Tenant GO

1. Run `c02_catalog_rls_migration.sql` → test app → enable §9 strict (`v_enable_strict_mode := true`)
2. Run `c01_orders_rls_migration.sql` → enable RLS (`v_enable_rls := true`) after data readiness
3. Run `c03_storage_rls_hardening.sql` → enable §7 strict
4. Manual regression: customer menu, admin CRUD, orders, product/banner images, daily sound
5. Gate or remove `SnackBurgerProductSeeder` from `lib/main.dart` production builds
6. Add Sentry before scaling operations

---

## 19. Roadmap Before Launch

### P0 — Immediate (Before Any Multi-Tenant)

| Step | Action | File |
|------|--------|------|
| 1 | Verify `catalog_matches_admin_profile` exists | `c02_catalog_rls_migration.sql` §6 |
| 2 | Run C-02 full migration (strict=false first) | `c02_catalog_rls_migration.sql` |
| 3 | Test admin + customer catalog flows | App manual |
| 4 | Run C-02 §9 with `v_enable_strict_mode := true` | Same file |
| 5 | Run C-01 migration + enable RLS | `c01_orders_rls_migration.sql` |
| 6 | Run C-03 migration + strict | `c03_storage_rls_hardening.sql` |
| 7 | Verify no legacy policies remain | SQL: `SELECT * FROM pg_policies WHERE ...` |

### P1 — Security Foundation (Weeks 1–3)

- Backfill `orders.restaurant_id` — `phase1_orders_restaurant_id_migration.sql`
- Fix `_orderMatchesSlug` fail-closed — `lib/core/utils/order_tenant_match.dart`
- Scope `purge_old_rejected_orders` — `purge_old_rejected_orders.sql`
- Two-tenant penetration test

### P2 — Admin Authorization (Week 4)

- Slug ↔ profile guard — `lib/core/auth/auth_middleware.dart`
- Remove session override — `lib/admin_features/data/admin_repositories.dart`
- Enforce `role` — middleware + sensitive actions

### P3 — Query & Realtime (Weeks 5–6)

- Server-side order stream filters — `lib/services/supabase_order_service.dart`
- Pagination — admin order/product lists
- Composite indexes — new migration SQL

### P4 — Per-Tenant Settings (Weeks 7–8)

- `restaurant_settings` table replacing `app_settings`
- Per-tenant print branding — `printer_config.dart`, receipt builders

### P5 — Observability (Weeks 11–12)

- Sentry integration
- CI test gate — `.github/workflows/`
- Structured telemetry pipeline

### P6 — SaaS Platform (Weeks 13–20)

- Provisioning UI, tenant picker, billing, audit log

---

## 20. Short Copy-Paste Summary For ChatGPT

```
PROJECT: snack_burger — Flutter 3.12 + Supabase POS & customer ordering app (Snack Burger / multi-tenant scaffold).
VERSION: 1.0.0+1 | DATE: 2026-06-22 | SIZE: 187 lib Dart files, 32 SQL files, 138 tests passing.

OVERALL SCORE: 42/100 (up from 38). Single-restaurant ready ~88%. SaaS ~25%. NOT enterprise-ready.

STACK: Flutter, provider, go_router, supabase_flutter, Windows POS printing (ESC/POS raster Arabic), image_picker, flutter_image_compress.

ARCHITECTURE: Layered UI + static Supabase*Service (NOT Clean Architecture). Slug routes /:slug and /:slug/admin/*. God services: supabase_order_service (~1100 lines), supabase_product_service (~1500 lines).

DATABASE TABLES: restaurants, business_days, orders, products, product_addons, product_variants, banners, app_settings (GLOBAL), profiles. orders.restaurant_id is UUID; products.restaurant_id is text slug. No triggers/views in repo.

RLS STATUS: Migration files EXIST but strict mode DEFAULT FALSE — legacy permissive policies likely ACTIVE in production:
- c02_catalog_rls_migration.sql — 20 catalog_c02_* policies + catalog_matches_admin_profile; strict drops 17 legacy policies
- c01_orders_rls_migration.sql — 3 orders_c01_* policies; v_enable_rls=false default
- c03_storage_rls_hardening.sql — 8 storage_c03_* policies; strict drops 7 legacy storage policies
Legacy catalog: USING(true) on products/banners/addons/variants. Storage: anon can write any path in product-images and daily-sounds buckets.

FLUTTER IMPROVEMENTS DONE: Phase 2.4 server-side restaurant_id filters on products/banners. ProductImageUploadService with compute() isolate + 30s timeout. Banner admin CRUD + drag-drop sort. 138 unit tests.

CRITICAL ISSUES: (1) RLS not enforced until manual SQL strict run (2) full-table order realtime streams (3) order UPDATE by id only (4) purge_old_rejected_orders global+anon (5) admin session overrides URL slug (6) global app_settings (7) storage anon write cross-tenant.

HIGH ISSUES: business_days read all tenants, open/close RPC no profile check, phone-global customer profiles, save_product_with_addons INVOKER+anon grant, .env in app bundle, hardcoded snack_burger redirects and printer branding.

PRODUCTION: Conditional GO for single Snack Burger Windows POS AFTER running C-01/C-02/C-03 strict in Supabase SQL Editor. NO-GO for multi-tenant SaaS or enterprise.

SAAS SCALE: 10 restaurants ~35%, 100 ~20%, 1000 ~8%, 10000 <5%.

KEY FILES: lib/main.dart, lib/core/router/app_router.dart, lib/services/supabase_order_service.dart, lib/services/supabase_product_service.dart, supabase/c02_catalog_rls_migration.sql, supabase/c01_orders_rls_migration.sql, supabase/c03_storage_rls_hardening.sql, PROJECT_MASTER_AUDIT.md.

TESTS: flutter analyze clean, flutter test 138 passed (2026-06-22).

ASK CHATGPT TO: Help plan strict RLS execution order, two-tenant test matrix, admin slug guard design, or per-tenant settings migration — with this context only.
```

---

## ملخص عربي مختصر (20–30 سطر)

**المشروع:** تطبيق Flutter + Supabase لإدارة مطعم (منيو زبون + لوحة إدارة + طباعة حرارية على Windows).

**الحالة العامة:** يعمل بشكل جيد لمطعم واحد (Snack Burger) بنسبة ~88%، لكنه **غير جاهز كمنصة SaaS** متعددة المطاعم (الدرجة الإجمالية 42/100).

**التقنية:** 187 ملف Dart، 32 ملف SQL يدوي، 138 اختبار ناجح، `flutter analyze` نظيف.

**الأمان (الأهم):** ملفات RLS جاهزة (`c01`, `c02`, `c03`) لكن **Strict Mode معطّل افتراضياً** — السياسات القديمة permissive (`USING true`) قد لا تزال فعّالة في Supabase حتى يُنفَّذ SQL يدوياً. التخزين (Storage) يسمح لـ anon بالكتابة على أي مسار في bucket.

**ما تم إنجازه:** فلاتر `restaurant_id` على السيرفر للمنتجات والبانرات في Flutter؛ إدارة بانرات كاملة؛ تحسين رفع صور المنتج (ضغط على isolate + timeout 30 ثانية).

**مشاكل حرجة:** بث الطلبات بدون فلتر سيرفر؛ تحديث الطلبات بـ id فقط؛ إعدادات عامة لكل المطاعم؛ جلسة الأدمن تتجاوز slug الرابط؛ purge عالمي لـ anon.

**الإطلاق:** **موافقة مشروطة** لمطعم واحد على Windows **بعد** تنفيذ Strict Mode لـ C-01/C-02/C-03 في Supabase. **رفض** للإطلاق متعدد المستأجرين أو للعملاء المؤسسيين.

**الخطوة التالية:** تنفيذ migrations يدوياً بالترتيب (C-02 → اختبار → strict → C-01 → C-03 → strict) ثم اختبار يدوي كامل.

---

**END OF HANDOFF DOCUMENT**
