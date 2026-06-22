# PROJECT MASTER AUDIT

**Project:** Snack Burger / Al Mahab Menu — Restaurant POS & Customer Ordering  
**Stack:** Flutter 3.12+ · Supabase (Postgres + Realtime + Storage + Auth) · Windows/Android/iOS/Web  
**Audit Type:** Read-only — Principal Architect + Security + QA + DevOps  
**Audit Date:** 2026-06-03  
**Version Audited:** `1.0.0+1` (pubspec)  
**Scope:** `lib/` (182 Dart files) · `supabase/` (25 SQL files) · `test/` (13 test files) · CI (1 workflow)

> **هذا الملف هو المرجع الرسمي الوحيد لصحة المشروع.**  
> يُحدَّث بعد كل مرحلة تنفيذ. لا يُعتمد على أي تقرير خارجي.

---

## Document Control

| Field | Value |
|-------|-------|
| Status | 🔴 Not Production-Ready for Multi-Tenant SaaS |
| Current Mode | Single-Tenant (Snack Burger) with Multi-Tenant Scaffolding |
| Target | Global SaaS — thousands of restaurants |
| Next Review | After Phase 1 (Database Security Foundation) |

---

# 1. Architecture

## Architecture Score: **52 / 100**

### نقاط القوة

| # | Strength |
|---|----------|
| 1 | **Slug-first routing** — `/:slug`, `/:slug/admin/*`, `/:slug/order/:orderId/status` (`lib/core/router/app_router.dart`) |
| 2 | **Feature folders** — `admin_features/`, `customer_features/`, `services/`, `state/`, `core/` |
| 3 | **Repository thin layer** — `admin_repositories.dart`, `customer_order_repository.dart`, `product_repository.dart` |
| 4 | **RPC for critical writes** — order submit, business day open/close, product save |
| 5 | **Receipt layout centralization** — `receipt_cashier_layout.dart` as single print design source |
| 6 | **Business Day domain** — explicit open/close model, not calendar-only |
| 7 | **Telemetry hooks** — `AppTelemetry` with correlation IDs on order submit/status |
| 8 | **Env-based secrets** — `SupabaseEnv` from `.env`, not hardcoded keys |
| 9 | **Provider + ChangeNotifier** — predictable state for tenant, auth, settings, business day |
| 10 | **Menu catalog cache** — keyed by slug (`lib/core/cache/menu_catalog_cache.dart`) |

### نقاط الضعف

| # | Weakness |
|---|----------|
| 1 | **No Clean Architecture layers** — UI calls `Supabase*Service` directly; no domain/use-case boundary |
| 2 | **God services** — `supabase_order_service.dart` (~1100 lines), `supabase_product_service.dart` (~1300 lines) |
| 3 | **Tenant isolation in Flutter, not DB** — security depends on client-side filters |
| 4 | **Global singleton state** — one `BusinessDayNotifier`, `AppSettingsNotifier` for entire app |
| 5 | **Single-tenant fallbacks everywhere** — `snack_burger` as silent default |
| 6 | **No dependency injection** — static service classes, hard to test/mock at scale |
| 7 | **Mixed identity model** — `restaurant_id` as text slug, UUID nullable, used interchangeably |
| 8 | **Dev code in production path** — `SnackBurgerProductSeeder` in `main.dart` |
| 9 | **No API versioning / feature flags per tenant** |
| 10 | **No event bus / command pattern** for order lifecycle |

### Technical Debt (estimated)

| Category | Debt Level | Effort to Clear |
|----------|------------|-----------------|
| RLS & tenant security | 🔴 Critical | 3–4 weeks |
| Service decomposition | 🟠 High | 4–6 weeks |
| Global → per-tenant settings | 🟠 High | 2 weeks |
| Remove hardcoded fallbacks | 🟡 Medium | 1 week |
| Test coverage (integration/E2E) | 🔴 Critical | 4+ weeks |
| Monitoring/observability | 🔴 Critical | 2–3 weeks |
| Provisioning/onboarding UI | 🔴 Critical | 4+ weeks |

### Clean Architecture Assessment

| Layer | Present? | Quality |
|-------|----------|---------|
| Presentation (Widgets/Screens) | ✅ | Good separation by feature |
| State (Notifiers/Controllers) | ✅ | Partial — some logic in widgets |
| Application / Use Cases | ❌ | Missing |
| Domain (Entities, Rules) | ⚠️ | Models only, no domain services |
| Infrastructure (Supabase) | ✅ | Monolithic static services |
| Cross-cutting (Auth, Telemetry) | ⚠️ | Minimal |

**Verdict:** *Layered UI + Services*, not Clean Architecture. Acceptable for MVP single restaurant; **insufficient for SaaS at scale**.

### Separation of Concerns

- ✅ Receipt design separated from print transport
- ✅ Auth middleware separated from screens
- ❌ Order business rules mixed with Supabase I/O
- ❌ Product variant logic split across service, resolver, and UI
- ❌ Settings (global) coupled to customer submit gate

### Dependency Direction

```
Screens → Notifiers/Controllers → Supabase*Service → Supabase Client
                ↓
            Models (fromMap)
```

**Violations:** Models contain display logic (`displayOrderHeroLabel`); services import UI-related config; `BusinessDayRuntime` static bridge creates hidden coupling.

### Scalability

| Dimension | Current Capacity | Bottleneck |
|-----------|------------------|------------|
| Restaurants | 1–3 (manual) | No provisioning, no RLS |
| Concurrent orders | ~50/day/restaurant | Full-table Realtime streams |
| Products/restaurant | ~250 tested in search | Full-table product fetch |
| Admin users | 1 role (implicit) | No RBAC enforcement |
| Geographic | Single region (Baghdad defaults) | Hardcoded map center |

---

# 2. Database

## Tables Inventory (from SQL + app usage)

| Table | In Repo Schema? | `restaurant_id` | `slug` | FK / Relations | Indexes | Normalization |
|-------|-------------------|-----------------|--------|----------------|---------|---------------|
| `restaurants` | ✅ | PK `id` (text) | ✅ unique | Root tenant | `slug_idx` | ✅ |
| `business_days` | ✅ | ✅ NOT NULL | ✅ NOT NULL | → `auth.users` | Unique open per restaurant; status; opened_at | ✅ |
| `orders` | ⚠️ partial | ✅ nullable | ✅ nullable | → `business_days` | `business_day_id`, status composite | ⚠️ `order_items` JSONB (denormalized) |
| `products` | ⚠️ partial | ✅ default `snack_burger` | ❌ | — | None in repo | ⚠️ addons/variants in JSONB + tables |
| `product_addons` | ⚠️ partial | ❌ | ❌ | → `products` | — | 3NF via product |
| `product_variants` | ✅ | ❌ | ❌ | → `products` | — | 3NF via product |
| `banners` | ✅ | ✅ NOT NULL | ❌ | — | `(restaurant_id, is_active, sort_order)` | ✅ |
| `app_settings` | ✅ | ❌ (global `id='global'`) | ❌ | — | PK only | ❌ single row |
| `profiles` | ⚠️ partial | ⚠️ drift | ❌ | → `auth.users` | phone unique (global) | ⚠️ |
| `auth.users` | Supabase managed | — | — | — | — | — |

### UUID Usage

| Entity | ID Type | Notes |
|--------|---------|-------|
| `business_days` | UUID ✅ | Correct |
| `banners` | UUID ✅ | Correct |
| `orders` | **bigint** (app) | Sequential global — OK for internal PK |
| `products` | **bigint** (app) | Sequential global |
| `restaurants` | **text** (slug as id) | Non-standard for SaaS; no UUID FK chain |

### Business Day Design

- ✅ One open day per `restaurant_id` (unique partial index)
- ✅ Orders linked via `business_day_id`
- ✅ `business_day_order_number` per day (recent addition)
- ✅ Close snapshots: `closed_order_count`, `closed_total_sales`
- ⚠️ RPC open/close uses advisory lock — good
- ❌ RLS exposes all tenants' business days to authenticated users

### Missing in Repo (assumed pre-existing)

- `CREATE TABLE orders` — base schema not versioned
- `CREATE TABLE products` — base schema not versioned
- `CREATE TABLE profiles` — base schema not versioned
- **No `orders` RLS policies in repo**

### Database Score: **38 / 100**

---

# 3. Multi-Tenant Readiness

| Scale | Readiness % | Blockers |
|-------|-------------|----------|
| **1 restaurant (current)** | **85%** | Works for Snack Burger with manual Supabase setup |
| **30 restaurants** | **32%** | RLS open, global settings, client-side isolation, no admin boundary |
| **100 restaurants** | **18%** | Full-table streams, no pagination, no monitoring, storage leak |
| **1000 restaurants** | **8%** | All above + no sharding strategy, no rate limits, no provisioning API |

### What Exists (Scaffolding)

- ✅ `restaurants` table with slug, branding, colors
- ✅ `restaurant_id` on products, banners, business_days, orders (partial)
- ✅ URL tenant key (`/:slug`)
- ✅ `ActiveRestaurantNotifier` resolves tenant from route
- ✅ Per-tenant theming (`TenantPalette`, `RestaurantModel`)

### What Blocks Scale

- ❌ Database-enforced tenant isolation
- ❌ Per-tenant settings (maintenance, sounds, phones)
- ❌ Per-tenant customer profiles (phone is global)
- ❌ Admin authorization bound to URL slug
- ❌ No super-admin / provisioning
- ❌ No billing/subscriptions
- ❌ No tenant-aware monitoring

---

# 4. Security

## Security Score: **22 / 100** 🔴

### RLS Summary

| Table | RLS Enabled | Tenant-Scoped? | Risk |
|-------|-------------|----------------|------|
| `orders` | ❓ Unknown (none in repo) | ❌ | **CRITICAL** |
| `products` | ✅ | ❌ `USING (true)` | **CRITICAL** |
| `product_addons` | ✅ | ❌ `USING (true)` | **CRITICAL** |
| `product_variants` | ✅ | ❌ `USING (true)` | **CRITICAL** |
| `banners` | ✅ | ❌ `USING (true)` | **CRITICAL** |
| `business_days` | ✅ | ❌ auth read all | **HIGH** |
| `app_settings` | ✅ | ❌ global, any auth update | **CRITICAL** |
| `restaurants` | ✅ | Public read active only | **LOW** |
| `profiles` | ✅ | Own row only | **MEDIUM** (not tenant-scoped) |
| Storage `product-images` | ✅ | ❌ bucket only | **HIGH** |
| Storage `daily-sounds` | ✅ | ❌ bucket only | **HIGH** |

### RPC Security

| RPC | SECURITY | Auth | Tenant Check | Grant to Anon |
|-----|----------|------|--------------|---------------|
| `submit_customer_order` | DEFINER | anon+auth | Partial (open day lock) | ✅ |
| `open_business_day` | DEFINER | auth only | ❌ no profile check | ❌ |
| `close_business_day` | DEFINER | auth only | ❌ no profile check | ❌ |
| `save_product_with_addons` | INVOKER | anon+auth | ❌ JSON trust | ✅ |
| `purge_old_rejected_orders` | DEFINER | anon+auth | ❌ global delete | ✅ |
| `get_customer_delivery_by_phone` | DEFINER | anon+auth | ❌ phone only | ✅ |
| `update_customer_location` | DEFINER | anon+auth | ⚠️ version drift | ✅ |

### Authentication

- ✅ Supabase Auth (email/password for admin)
- ✅ Session persisted via `AdminProfileSession`
- ✅ `AuthNotifier` loads `profiles.restaurant_id, role`
- ❌ Customer orders: **anon** submit (by design for frictionless ordering)
- ❌ No MFA, no SSO, no magic link for admin

### Authorization

- ⚠️ `role` stored in profile and session — **never enforced** in middleware or UI gates
- ❌ Admin path does not verify `slug == profile.restaurant_id`
- ❌ `AdminOrderRepository.resolveRestaurantId` **overrides URL slug** with session restaurant
- ❌ No super-admin, no multi-restaurant staff model

### Privilege Escalation Vectors

1. Any authenticated user → update global `app_settings`
2. Any authenticated user → open/close any restaurant's business day
3. Anon/authenticated → CRUD any product/banner via PostgREST
4. Anon → execute `purge_old_rejected_orders` (cross-tenant delete)
5. Order update by global `id` without tenant check

### Cross-Tenant Access

| Vector | File | Mechanism |
|--------|------|-----------|
| Full-table order stream | `supabase_order_service.dart` | `.stream()` + client filter |
| `_orderMatchesSlug` empty match | `supabase_order_service.dart:847` | Returns `true` if no tenant fields |
| Fallback to snack_burger | `delivery_order_model.dart:155` | Silent tenant assignment |
| Global maintenance | `supabase_app_settings_service.dart` | Blocks all tenants |
| Phone-global profile | `customer_location_full_setup.sql` | Same phone = shared address |

### Injection

- ✅ Supabase client uses parameterized queries
- ✅ RPC uses typed params
- ⚠️ No SQL injection surface in Flutter; risk is **authorization not injection**

### Hardcoded Values

| Value | Location | Risk |
|-------|----------|------|
| `snack_burger` slug | 15+ files | Wrong tenant attribution |
| `Snack Burger` display name | `printer_config.dart` | Wrong branding |
| Baghdad GPS defaults | `delivery_map_defaults.dart` | Wrong region |
| Emergency phones | `app_settings_defaults.dart` | Snack Burger specific |
| `/snack_burger` root redirect | `app_router.dart` | Single-tenant UX |

### Secrets

- ✅ `SUPABASE_URL`, `SUPABASE_ANON_KEY` in `.env` (not in repo ideally)
- ⚠️ `.env` listed in `pubspec.yaml` assets — **ships with app bundle**
- ❌ No service role key in app (correct — should stay server-side only)
- ❌ No secrets rotation strategy documented

### Anon Access

Anon key is embedded in customer app — **expected for Supabase B2C**. This makes **RLS the only real security boundary**. Current RLS is **not sufficient**.

---

# 5. Performance

## Performance Score: **41 / 100**

### Realtime & Streams

| Stream | Scoped Server-Side? | Impact at 30 tenants |
|--------|---------------------|----------------------|
| Orders (pending/active/all) | ❌ | High bandwidth, client CPU filtering |
| Products catalog | ❌ | Full catalog × N tenants on wire |
| Banners | ❌ | Minor |
| Business days | ✅ `.eq('restaurant_id')` | Good pattern |
| App settings | Global single row | OK |
| Realtime INSERT listener | ❌ all orders | Notification leak risk |

### Queries

- ❌ **No pagination** on orders, products, or closing reports
- ❌ Product fetch: `SELECT *` from products, filter in Dart
- ⚠️ Variants: sometimes fetches ALL variants as fallback
- ✅ Business day orders: filtered by `business_day_id`
- ✅ Restaurant lookup: `.eq('slug')`

### Indexes (in repo)

- ✅ `business_days`: restaurant+status, unique open
- ✅ `orders`: business_day_id, business_day+status
- ✅ `orders`: business_day_order_number unique per day
- ✅ `banners`: restaurant+active+sort
- ❌ Missing: `orders(restaurant_id, status, created_at)` — if column populated
- ❌ Missing: `orders(slug, status, created_at)`
- ❌ Missing: `products(restaurant_id, is_available)`

### Image Loading

- ✅ `cached_network_image` used in menu
- ✅ Image compression on upload (`flutter_image_compress`)
- ⚠️ No CDN strategy documented; direct Supabase Storage URLs
- ⚠️ No lazy loading pagination for large catalogs

### Memory / CPU / Network

- ⚠️ Raster receipt rendering at 2× scale — CPU spike per print
- ⚠️ Full order list held in memory on admin dashboard
- ⚠️ Menu catalog cache per slug — good, but unbounded product count
- ❌ No request debouncing on realtime reconnect storms

---

# 6. Error Handling

## Error Handling Score: **55 / 100**

### Global Handlers (Good)

| Handler | File | Coverage |
|---------|------|----------|
| `FlutterError.onError` | `main.dart` | Uncaught Flutter errors → telemetry |
| `PlatformDispatcher.onError` | `main.dart` | Platform errors |
| `runZonedGuarded` | `main.dart` | Zone uncaught |
| `SupabaseEnv.ensureConfigured` | `supabase_env.dart` | Fail fast on missing env |
| `NetworkTimeouts.run` | `network_timeout.dart` | Order submit timeout |

### Critical Failure Points

| Location | Failure | App Behavior | Cascading? |
|----------|---------|--------------|------------|
| `submitOrder` maintenance check | Global maintenance ON | **All tenants blocked** | ✅ Yes |
| `submitOrder` no open day | RPC `no_open_business_day` | Customer cannot order | Per-tenant OK |
| Realtime stream disconnect | `supabase_order_service.dart` | Reconnect with backoff; UI shows stale/error | Admin degraded |
| `_orderMatchesSlug` bug | Bad data | Wrong orders shown | Silent corruption |
| Product stream parse fail | `supabase_product_service.dart` | Empty menu | **Total menu loss** |
| Profile load fail | `auth_notifier.dart` | Admin stays on route, shows error | Weak auth |
| Print failure | `receipt_escpos_printer.dart` | Order saved; print fails | Isolated ✅ |
| GPS denied | `delivery_location_notifier.dart` | Blocks submit if required | Per-order OK |
| Image upload fail | `image_pick_upload_service.dart` | Product save fails | Admin feature |
| Daily sound load fail | `daily_sound_player.dart` | Silent skip | Cosmetic |

### try/catch Coverage

- ✅ Most Supabase service methods wrapped with try/catch + telemetry
- ⚠️ Some UI actions show generic SnackBar only
- ❌ No centralized `AppErrorHandler` usage everywhere (exists but underused)
- ❌ Stream error handlers often log only — no user recovery UX

### Fallback Patterns

| Fallback | Safe? | File |
|----------|-------|------|
| `snack_burger` slug on missing tenant | ❌ Dangerous | `delivery_order_model.dart` |
| Synthetic restaurant for unknown slug | ❌ Dangerous | `active_restaurant_notifier.dart` |
| Full variant table fetch | ⚠️ Performance | `supabase_product_service.dart` |
| Legacy order ID display | ✅ Safe | `delivery_order_model.dart` |
| ESC/POS profile fallbacks | ✅ Safe | `receipt_escpos_builder.dart` |

---

# 7. Offline Readiness

## Offline Score: **18 / 100**

| Scenario | Ready? | Notes |
|----------|--------|-------|
| Internet disconnect (customer) | ❌ | No offline menu cache persistence; no queue |
| Internet disconnect (admin) | ❌ | Dashboard requires Realtime |
| Realtime disconnect | ⚠️ | Reconnect logic exists; stale state shown |
| Printer failure | ✅ | Order persists; reprint available |
| Image load failure | ⚠️ | Placeholder in UI; upload fails hard |
| GPS failure | ⚠️ | Blocks order if location required |
| Supabase down | ❌ | Complete app failure for core flows |
| Business day check offline | ❌ | Cannot submit |

**Verdict:** Online-first POS. No offline order queue, no local DB (Hive/SQLite), no sync engine.

---

# 8. Printing

## Printing Score: **62 / 100** (single restaurant) · **28 / 100** (multi-tenant)

### Cashier Receipt

- ✅ Raster mode (Arabic quality) + ESC/POS text fallback
- ✅ Professional layout via `ReceiptCashierLayout`
- ✅ QR for delivery location (unchanged logic)
- ✅ Daily order number display
- ❌ Branding: `PrinterConfig.restaurantDisplayName = 'Snack Burger'` hardcoded

### Kitchen Ticket

- ✅ Separate pipeline (`buildKitchenTicket`, `_kitchenLines`)
- ✅ Order number on kitchen ticket
- ❌ Same global branding issue

### Multiple Printers

- ⚠️ Single `PrinterPreferences` key — one printer per device
- ⚠️ No cashier vs kitchen printer routing
- ✅ Windows spooler + USB raw paths

### Isolation

- ❌ Not tenant-isolated — same config for all slugs on same machine
- ❌ Print pipeline does not receive `RestaurantModel.name`

### Failure Recovery

- ✅ Reprint from admin (`order_invoice_reprint.dart`)
- ✅ Print errors don't rollback orders
- ⚠️ No print job queue or retry

---

# 9. Flutter

## Flutter Score: **58 / 100**

### Widgets & Structure

- ✅ Feature-based folders
- ✅ Shared admin shell (`admin_drawer.dart`, `admin_page_scaffold.dart`)
- ✅ RTL support throughout
- ⚠️ Some large widgets (`menu_cart_bar.dart`, `admin_home_screen.dart` 793 lines)
- ⚠️ Business logic in widgets in places

### State Management

- **Provider + ChangeNotifier** — consistent but not scalable for complex domains
- Controllers: `ProductFormController`, `CustomerMenuController`, `ProductsAdminController`
- ❌ No Riverpod/Bloc for testability at scale

### Memory Leaks

- ✅ Many `dispose()` and `cancel()` patterns found in notifiers and screens
- ⚠️ Stream subscriptions in services — verify all paths call `_disposeStream`
- ⚠️ `OrderRealtimeNotificationService` — lifecycle tied to auth listener

### Navigation & Routing

- ✅ `go_router` with auth middleware
- ✅ Slug in path parameters
- ❌ No deep link validation for tenant
- ❌ Root `/` → hardcoded `/snack_burger`

---

# 10. Supabase

## Supabase Score: **35 / 100**

### RPCs (8 documented)

All in `supabase/` — manual execution, no automated migration runner.

### Triggers / Views

- ❌ No triggers in repo
- ❌ No views in repo
- ❌ No database functions beyond RPCs

### Realtime Publications

- `business_days` added to realtime
- `app_settings` commented out
- Orders/products/banners realtime via PostgREST streams (not publication config in repo)

### Performance Recommendations

1. Add composite indexes on `orders(slug, status, created_at DESC)`
2. Add `products(restaurant_id, is_available, category)`
3. Replace full-table streams with filtered subscriptions
4. Consider materialized views for closing reports
5. Connection pooling / read replicas at 1000+ tenants (infra, not app)

---

# 11. SaaS Readiness

## SaaS Score: **15 / 100**

| Capability | Status |
|------------|--------|
| Subscriptions / Billing | ❌ Not present |
| Restaurant isolation (DB) | ❌ Not enforced |
| Restaurant settings per tenant | ❌ Global `app_settings` |
| Staff roles | ⚠️ Stored, not enforced |
| Permissions / RBAC | ❌ Not implemented |
| Monitoring | ⚠️ debugPrint telemetry only |
| Provisioning | ❌ Manual SQL inserts |
| Tenant onboarding UI | ❌ Not present |
| Custom domains per tenant | ❌ Not present |
| White-label apps | ❌ Single app binary |
| Rate limiting | ❌ Not present |
| Audit log | ❌ Not present |
| Data export / GDPR | ❌ Not present |
| Multi-region | ❌ Single Supabase project |

---

# 12. Monitoring

## Monitoring Score: **12 / 100**

### What Exists

- `AppTelemetry` → `debugPrint` JSON (local dev only)
- `[QA]` prefixed logs throughout services
- `StreamHealth` enum for admin dashboard connection status
- Correlation IDs on order submit/status

### What's Missing

| Need | Tool Suggestion | Priority |
|------|-----------------|----------|
| Error tracking | Sentry / Firebase Crashlytics | P1 |
| Performance APM | Datadog / Supabase Dashboard | P2 |
| Order funnel metrics | Custom events → analytics | P1 |
| Print success/fail rate | Telemetry event (exists partially) | P2 |
| Realtime health per tenant | Dashboard | P2 |
| Structured logs | CloudWatch / Loki | P2 |
| Uptime monitoring | Better Stack / Pingdom | P3 |
| RPC latency alerts | Supabase logs + alerts | P2 |
| Business metrics | Orders/day/tenant, GMV | P1 |

---

# 13. Code Quality Scores

| Category | Score /100 | Notes |
|----------|------------|-------|
| Architecture | 52 | Feature folders good; no clean architecture |
| Database | 38 | Schema drift; missing orders RLS in repo |
| Security | 22 | Permissive RLS; client-side isolation |
| Performance | 41 | Full-table streams; no pagination |
| Scalability | 25 | Not ready beyond single tenant |
| Maintainability | 50 | God services; 182 files manageable |
| Readability | 62 | Arabic comments; consistent naming |
| Error Handling | 55 | Global handlers good; gaps in streams |
| Testing | 28 | 48 unit tests; no integration/E2E/security tests |
| Realtime | 35 | Works for 1 tenant; unsafe at scale |
| Printing | 55 | Good quality; not multi-tenant |
| Offline | 18 | Online-first only |
| Monitoring | 12 | debugPrint only |
| SaaS | 15 | Scaffolding only |
| **Overall Score** | **38 / 100** | **MVP single restaurant — not SaaS** |

---

# 14. All Issues (Prioritized)

## CRITICAL

### C-01
| Field | Value |
|-------|-------|
| **File** | `supabase/` (no orders RLS) · `lib/services/supabase_order_service.dart` |
| **Problem** | Orders table has no tenant-scoped RLS in repo; all CRUD/stream operations |
| **Cause** | Security deferred to Flutter client filters |
| **Severity** | Complete cross-tenant data breach via anon key |
| **Fix** | Enable RLS; policies on `restaurant_id`/`slug`; mutations require tenant match |
| **Duration** | 3–5 days |
| **Break Risk** | Medium — needs backfill + testing |
| **Priority** | P1 |

### C-02
| Field | Value |
|-------|-------|
| **File** | `supabase/products_table_schema.sql`, `banners_table_schema.sql`, `product_addons_table_schema.sql` |
| **Problem** | `USING (true)` on all catalog RLS policies |
| **Cause** | MVP permissive policies for development |
| **Severity** | Any client can CRUD any tenant's catalog |
| **Fix** | Tenant-scoped RLS via `restaurant_id` |
| **Duration** | 2–3 days |
| **Break Risk** | Medium |
| **Priority** | P2 |

### C-03
| Field | Value |
|-------|-------|
| **File** | `lib/services/supabase_order_service.dart` (~284, 351, 438, 519, 544, 691) |
| **Problem** | `.stream(primaryKey: ['id'])` on full orders table |
| **Cause** | PostgREST stream without server filter |
| **Severity** | All tenants' order metadata on wire |
| **Fix** | `.eq('slug', slug)` or RLS-only access |
| **Duration** | 2 days |
| **Break Risk** | Low |
| **Priority** | P3 |

### C-04
| Field | Value |
|-------|-------|
| **File** | `lib/services/supabase_order_service.dart` (updateOrderStatus ~710, updateRejectionReason ~750) |
| **Problem** | Update orders by `id` only |
| **Cause** | Missing tenant guard |
| **Severity** | Cross-tenant order status manipulation |
| **Fix** | Add `.eq('restaurant_id', tenant)` + RLS |
| **Duration** | 1 day |
| **Break Risk** | Low |
| **Priority** | P4 |

### C-05
| Field | Value |
|-------|-------|
| **File** | `lib/services/supabase_order_service.dart:847-851` |
| **Problem** | `_orderMatchesSlug` returns true when slug AND restaurant_id empty |
| **Cause** | Legacy order compatibility |
| **Severity** | Unscoped orders appear in every tenant dashboard |
| **Fix** | Return false; backfill tenant columns |
| **Duration** | 1 day |
| **Break Risk** | Low after backfill |
| **Priority** | P5 |

### C-06
| Field | Value |
|-------|-------|
| **File** | `supabase/purge_old_rejected_orders.sql` |
| **Problem** | Global DELETE across all restaurants; granted to anon |
| **Cause** | Missing tenant scope in RPC |
| **Severity** | Cross-tenant data destruction |
| **Fix** | Add `p_restaurant_id`; restrict to service_role or admin |
| **Duration** | 0.5 day |
| **Break Risk** | Low |
| **Priority** | P6 |

### C-07
| Field | Value |
|-------|-------|
| **File** | `lib/core/auth/auth_middleware.dart`, `lib/admin_features/data/admin_repositories.dart` |
| **Problem** | No validation URL slug vs `profiles.restaurant_id`; session overrides slug |
| **Cause** | Admin auth incomplete |
| **Severity** | Admin cross-tenant access |
| **Fix** | Middleware guard; remove blind session override |
| **Duration** | 2 days |
| **Break Risk** | Medium |
| **Priority** | P7 |

### C-08
| Field | Value |
|-------|-------|
| **File** | `supabase/app_settings_schema.sql`, `lib/services/supabase_app_settings_service.dart` |
| **Problem** | Single global settings row |
| **Cause** | Single-tenant design |
| **Severity** | One tenant maintenance stops entire platform |
| **Fix** | `restaurant_settings(restaurant_id PK)` |
| **Duration** | 3–4 days |
| **Break Risk** | High |
| **Priority** | P8 |

### C-09
| Field | Value |
|-------|-------|
| **File** | `supabase/submit_customer_order_rpc.sql` |
| **Problem** | INSERT omits `orders.restaurant_id` (only slug) |
| **Cause** | Incremental migration |
| **Severity** | Incomplete tenant linkage; complicates RLS |
| **Fix** | INSERT `restaurant_id = v_restaurant_id` |
| **Duration** | 0.5 day |
| **Break Risk** | Low |
| **Priority** | P9 |

---

## HIGH

### H-01 · `supabase_product_service.dart` — full product fetch/stream, client filter · Performance + leak · Server `.eq('restaurant_id')` · 1 day · Low · P10

### H-02 · `supabase_product_service.dart` + `product_repository.dart` — fetchProductById/delete by id only · Cross-tenant product access · Tenant in WHERE + RLS · 1 day · Low · P11

### H-03 · `supabase/business_days_schema.sql` — authenticated read all business days · Info leak · Tenant RLS · 1 day · Low · P12

### H-04 · `supabase/business_days_schema.sql` — open/close RPC no profile check · Privilege escalation · `auth.uid()` → profiles check · 1 day · Medium · P13

### H-05 · `supabase/customer_location_full_setup.sql` — phone-global customer profile · Cross-tenant address leak · Composite (phone, restaurant_id) · 3 days · High · P14

### H-06 · `supabase/storage_product_images_policies.sql` — no path tenant isolation · Storage cross-tenant write · Path prefix policy · 1 day · Low · P15

### H-07 · `lib/main.dart`, `lib/state/business_day_notifier.dart`, `lib/core/config/business_day_runtime.dart` — global singleton state · Tenant state bleed on navigation · Reset on slug change · 2 days · Medium · P16

### H-08 · `lib/core/config/printer_config.dart`, `receipt_*.dart` — hardcoded Snack Burger branding · Wrong tenant on receipts · Pass RestaurantModel.name · 1 day · Low · P17

### H-09 · `patch_rpc_param_names.sql` vs `customer_location_full_setup.sql` — profiles.restaurant_id drift · RBAC unreliable · Unified migration · 1 day · Medium · P18

### H-10 · `supabase/rpc_save_product_with_addons.sql` — anon grant + INVOKER · Unauthorized product writes · DEFINER + auth check · 1 day · Medium · P19

### H-11 · `lib/services/order_realtime_notification_service.dart` — unfiltered INSERT listener · Cross-tenant notifications · Filter by slug server-side · 1 day · Low · P20

### H-12 · `pubspec.yaml` — `.env` in assets bundle · Anon key exposure in binary · Build-time injection / obfuscation · 1 day · Low · P21

---

## MEDIUM

### M-01 · `supabase_banner_service.dart` — unscoped banner stream · Client filter only · Server filter · 0.5 day · P22

### M-02 · Banner/product mutations by ID without tenant · Cross-tenant writes · Tenant WHERE · 0.5 day · P23

### M-03 · `product_addons`/`product_variants` no restaurant_id · RLS gap · Policy via parent join · 1 day · P24

### M-04 · `supabase_business_day_service.dart` — fetchById ID-only · ID guessing · Tenant check · 0.5 day · P25

### M-05 · `app_router.dart`, `landing_page.dart` — hardcoded snack_burger redirect · Single-tenant UX · Tenant picker · 1 day · P26

### M-06 · `active_restaurant_notifier.dart` — synthetic tenant for unknown slug · Fake restaurants · 404 on invalid slug · 0.5 day · P27

### M-07 · No pagination on orders/products · Memory/perf at scale · Cursor pagination · 3 days · Medium · P28

### M-08 · `auth_notifier.dart` — role stored never enforced · RBAC illusion · Role gates in middleware · 2 days · P29

### M-09 · `end_of_day_report_model.dart` — no restaurantId on model · Implicit trust of businessDayId · Validation layer · 0.5 day · P30

### M-10 · Missing indexes on orders(slug, status) · Slow queries at scale · Migration · 0.5 day · P31

### M-11 · `main.dart` — SnackBurgerProductSeeder in prod path · Accidental seed · Feature flag / remove · 0.5 day · P32

### M-12 · No CI test/analyze gate · Regressions ship · Add test job to workflow · 1 day · P33

---

## LOW

### L-01 · `order_realtime_notification_service.dart` — channel id `snack_burger_new_orders` · Naming · Dynamic slug · 0.25 day · P34

### L-02 · `business_day_closing_time_migration.sql` — unused global column · Dead config · Remove or per-tenant · 0.25 day · P35

### L-03 · `lib/dev/snack_burger_product_seeder.dart` — dev-only single tenant · Dev confusion · Tenant param · 0.5 day · P36

### L-04 · `lib/models/order_model.dart` — legacy unused model · Confusion · Deprecate · 0.25 day · P37

### L-05 · `printer_preferences.dart` — global printer key · Shared workstation issue · Optional slug key · 0.5 day · P38

### L-06 · `.github/workflows/deploy-github-pages.yml` — deploy only, no test · Quality gate missing · Add analyze/test step · 0.5 day · P39

### L-07 · GitHub Pages base-href `/snack-burger/` hardcoded · Single tenant web deploy · Per-tenant or neutral · 0.5 day · P40

---

# 15. Roadmap to Professional SaaS

## Phase 1 — Security Foundation (Weeks 1–3)
**Goal:** Database-enforced tenant isolation. Zero cross-tenant access.

- RLS on `orders`, `products`, `banners`, `addons`, `variants`, `business_days`
- Fix RPCs: submit order (restaurant_id), purge (scoped), open/close (profile check)
- Backfill `orders.restaurant_id`, `slug` for legacy rows
- Fix `_orderMatchesSlug` fail-closed
- **Test gate:** Security integration tests; two-tenant isolation proof

## Phase 2 — Admin Authorization Boundary (Week 4)
**Goal:** Admin can only operate their restaurant.

- Middleware: slug ↔ profile.restaurant_id validation
- Remove blind session override in repositories
- Enforce `role` for sensitive actions (close day, settings, purge)
- **Test gate:** Admin A cannot access `/:tenantB/admin`

## Phase 3 — Query & Realtime Hardening (Weeks 5–6)
**Goal:** Scale to 30 restaurants without full-table streams.

- Server-side filters on all `.select()` and `.stream()`
- Composite indexes on orders and products
- Pagination on admin order list and product admin
- Filtered Realtime channels per tenant
- **Test gate:** Load test 30 tenants × 10 concurrent orders

## Phase 4 — Per-Tenant Settings & Branding (Weeks 7–8)
**Goal:** Each restaurant independent operation.

- `restaurant_settings` table (maintenance, phones, sounds)
- Migrate from global `app_settings`
- Pass `RestaurantModel.name` to print pipeline
- Per-tenant map defaults (optional)
- **Test gate:** Maintenance on tenant A does not affect B

## Phase 5 — Customer Isolation (Weeks 9–10)
**Goal:** Customer data scoped per restaurant.

- `(phone, restaurant_id)` composite for delivery profiles
- Update location RPCs
- Customer maintenance/settings per slug
- **Test gate:** Same phone, two restaurants, two addresses

## Phase 6 — Observability & Reliability (Weeks 11–12)
**Goal:** Operate 100+ restaurants with visibility.

- Sentry/Crashlytics integration
- Structured telemetry → analytics pipeline
- Stream health dashboard per tenant
- CI: analyze + test on every PR
- Print success/fail metrics
- **Test gate:** Alert fires on RPC error spike

## Phase 7 — SaaS Platform Layer (Weeks 13–20)
**Goal:** Onboard and manage thousands of restaurants.

- Super-admin provisioning UI (create restaurant, assign staff)
- Tenant picker / landing (replace `/snack_burger` hardcode)
- Subscription/billing hook (Stripe)
- Audit log table
- Rate limiting on RPCs
- Optional: Edge Functions for webhooks
- Historical business day archive UI
- **Test gate:** Onboard restaurant #31 end-to-end without code change

## Phase 8 — Scale Infrastructure (Weeks 21+)
**Goal:** 1000+ restaurants.

- Read replicas / connection pooling
- CDN for product images
- Consider Supabase multi-project or schema-per-tenant at extreme scale
- Offline queue for admin (optional)
- Multi-printer routing per tenant

---

# 16. Master Checklist

> **Legend:** ⬜ Not Started · 🟡 In Progress · ✅ Done  
> Update this section after every sprint.

## 1. Architecture
| # | Item | Status |
|---|------|--------|
| 1.1 | Decompose `supabase_order_service.dart` into domain + infra | ⬜ |
| 1.2 | Decompose `supabase_product_service.dart` | ⬜ |
| 1.3 | Introduce use-case layer for order lifecycle | ⬜ |
| 1.4 | Remove global singleton tenant state leak | ⬜ |
| 1.5 | Remove all silent `snack_burger` fallbacks | ⬜ |
| 1.6 | Standardize restaurant_id identity (UUID vs slug) | ⬜ |

## 2. Database
| # | Item | Status |
|---|------|--------|
| 2.1 | Version base `orders` CREATE TABLE in repo | ⬜ |
| 2.2 | Version base `products` CREATE TABLE in repo | ⬜ |
| 2.3 | RLS on `orders` | ⬜ |
| 2.4 | RLS on catalog tables (tenant-scoped) | ⬜ |
| 2.5 | Backfill `orders.restaurant_id` | ⬜ |
| 2.6 | Index `orders(slug, status, created_at)` | ⬜ |
| 2.7 | Index `products(restaurant_id, is_available)` | ⬜ |
| 2.8 | Unified profiles migration (restaurant_id column) | ⬜ |
| 2.9 | Automated migration runner (Supabase CLI) | ⬜ |

## 3. Multi-Tenant
| # | Item | Status |
|---|------|--------|
| 3.1 | 30-restaurant isolation test suite | ⬜ |
| 3.2 | 100-restaurant load test | ⬜ |
| 3.3 | Per-tenant settings table | ⬜ |
| 3.4 | Per-tenant customer profiles | ⬜ |
| 3.5 | Tenant provisioning API/UI | ⬜ |
| 3.6 | Tenant picker landing page | ⬜ |

## 4. Security
| # | Item | Status |
|---|------|--------|
| 4.1 | Fix `_orderMatchesSlug` fail-closed | ⬜ |
| 4.2 | Admin slug ↔ profile guard | ⬜ |
| 4.3 | Scope `purge_old_rejected_orders` | ⬜ |
| 4.4 | Restrict `save_product_with_addons` auth | ⬜ |
| 4.5 | Storage path tenant policies | ⬜ |
| 4.6 | Remove anon from destructive RPCs | ⬜ |
| 4.7 | Enforce role-based permissions | ⬜ |
| 4.8 | Security penetration test (2 tenants) | ⬜ |

## 5. Performance
| # | Item | Status |
|---|------|--------|
| 5.1 | Server-side stream filters | ⬜ |
| 5.2 | Order list pagination | ⬜ |
| 5.3 | Product list pagination | ⬜ |
| 5.4 | Remove full-table variant fallback | ⬜ |
| 5.5 | Realtime reconnect storm handling | ⬜ |

## 6. Error Handling
| # | Item | Status |
|---|------|--------|
| 6.1 | Centralize user-facing error messages | ⬜ |
| 6.2 | Stream error recovery UX | ⬜ |
| 6.3 | Remove dangerous fallbacks | ⬜ |
| 6.4 | Graceful degradation when Realtime down | ⬜ |

## 7. Offline
| # | Item | Status |
|---|------|--------|
| 7.1 | Offline menu cache (read) | ⬜ |
| 7.2 | Admin offline order view (read-only) | ⬜ |
| 7.3 | Print without network (reprint) | ✅ |

## 8. Printing
| # | Item | Status |
|---|------|--------|
| 8.1 | Tenant name on cashier receipt | ⬜ |
| 8.2 | Tenant name on kitchen ticket | ⬜ |
| 8.3 | Tenant name on closing report | ⬜ |
| 8.4 | Optional per-slug printer prefs | ⬜ |
| 8.5 | Cashier + kitchen printer routing | ⬜ |

## 9. Flutter
| # | Item | Status |
|---|------|--------|
| 9.1 | Split large widgets (menu_cart_bar, admin_home) | ⬜ |
| 9.2 | didUpdateWidget slug handling on all admin screens | ⬜ |
| 9.3 | Memory leak audit (streams) | ⬜ |

## 10. Supabase
| # | Item | Status |
|---|------|--------|
| 10.1 | submit_customer_order writes restaurant_id | ⬜ |
| 10.2 | Resolve customer location RPC version drift | ⬜ |
| 10.3 | Realtime publication audit | ⬜ |
| 10.4 | Database audit log trigger | ⬜ |

## 11. SaaS Platform
| # | Item | Status |
|---|------|--------|
| 11.1 | Super-admin role | ⬜ |
| 11.2 | Restaurant CRUD admin | ⬜ |
| 11.3 | Staff invite / assign | ⬜ |
| 11.4 | Billing integration | ⬜ |
| 11.5 | Usage metering | ⬜ |

## 12. Monitoring
| # | Item | Status |
|---|------|--------|
| 12.1 | Sentry / Crashlytics | ⬜ |
| 12.2 | Order funnel analytics | ⬜ |
| 12.3 | Print metrics | ⬜ |
| 12.4 | RPC latency monitoring | ⬜ |
| 12.5 | Per-tenant health dashboard | ⬜ |

## 13. Testing
| # | Item | Status |
|---|------|--------|
| 13.1 | Integration tests (Supabase mock) | ⬜ |
| 13.2 | Multi-tenant security tests | ⬜ |
| 13.3 | E2E order flow test | ⬜ |
| 13.4 | CI test gate on PR | ⬜ |
| 13.5 | Current unit tests (48) | ✅ |

## 14. DevOps
| # | Item | Status |
|---|------|--------|
| 14.1 | CI analyze + test | ⬜ |
| 14.2 | Staging environment | ⬜ |
| 14.3 | Environment separation (dev/staging/prod) | ⬜ |
| 14.4 | GitHub Pages deploy | ✅ |
| 14.5 | Secrets not in app bundle | ⬜ |

---

# 17. Executive Summary

**Snack Burger** is a **functional single-restaurant POS and customer ordering system** with **early multi-tenant scaffolding** (slug routes, `restaurants` table, `restaurant_id` columns). It is **not ready** for SaaS deployment at 30+ restaurants without **Phase 1–3 security and isolation work**.

The **single highest risk** is that **tenant isolation lives in Flutter, not Postgres**, while the **anon key ships in the customer app** and **RLS policies are permissive or missing**.

The **recommended immediate action** is **Phase 1 (Security Foundation)** — estimated **3 weeks** — before onboarding any additional restaurant beyond Snack Burger.

**Overall Project Health: 38/100**  
**SaaS Readiness: NOT READY**  
**Safe for current single-tenant production: YES (with manual Supabase setup)**  
**Safe for 30-restaurant SaaS: NO**

---

*End of PROJECT_MASTER_AUDIT.md*
