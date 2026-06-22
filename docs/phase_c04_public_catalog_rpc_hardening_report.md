# Phase C-04 — Public Catalog RPC Hardening Report

**المشروع:** snack_burger (Flutter + Supabase)  
**التاريخ:** 2026-06-22  
**الحالة:** منفّذ في الكود — SQL يُنفَّذ يدوياً في Supabase  

---

## 1) الهدف

نقل **قراءة منيو الزبون** (منتجات، أحجام، إضافات، بانرات) من **SELECT مباشر** على جداول الكتالوج — التي تعتمد حالياً على سياسات `catalog_c02_select_anon_interim USING (true)` — إلى **دوال RPC عامة** (`SECURITY DEFINER`) مفلترة حسب `restaurant_slug` ومطعم **نشط فقط**.

بعد نشر Flutter المحدّث واختبار المنيو، يُفعَّل **strict mode** في migration C-04 لحذف **أربع سياسات anon interim فقط**، دون كسر لوحة الإدارة (authenticated) ودون المساس بـ orders أو storage.

---

## 2) الملفات التي تم تعديلها

### ملفات جديدة

| الملف | الوصف |
|-------|--------|
| `supabase/c04_public_catalog_rpc_hardening.sql` | Migration C-04 — RPCs + strict cleanup |
| `lib/services/public_catalog_service.dart` | خدمة قراءة المنيو العام عبر RPC + polling |
| `test/services/public_catalog_service_test.dart` | اختبارات تجميع RPC وتحليل البانرات |
| `docs/phase_c04_public_catalog_rpc_hardening_report.md` | هذا التقرير |

### ملفات معدّلة

| الملف | الوصف |
|-------|--------|
| `lib/services/supabase_product_service.dart` | إضافة `assemblePublicMenuProducts()` |
| `lib/services/product_repository.dart` | `fetchProductsForCustomerMenu` / `watchProductsForCustomerMenu` |
| `lib/services/banner_repository.dart` | `fetchActiveBannersForCustomerMenu` / `watchActiveBannersForCustomerMenu` |
| `lib/customer_features/menu/customer_menu_controller.dart` | يستخدم مسارات الزبون عبر RPC |
| `lib/customer_features/menu/customer_menu_banners_controller.dart` | يستخدم مسارات الزبون عبر RPC |

### ملفات لم تُمس (تأكيد)

- `supabase/c01_orders_rls_migration.sql` — orders RLS
- `supabase/c03_storage_rls_hardening.sql` — storage RLS
- مسارات الأدمن: `AdminProductRepository` → `fetchProductsForRestaurant` / `watchProductsForRestaurant` (SELECT مباشر + authenticated)

---

## 3) ملف SQL

| البند | القيمة |
|-------|--------|
| **اسم migration** | `supabase/c04_public_catalog_rpc_hardening.sql` |
| **دوال RPC عامة (منيو زبون)** | `get_public_products` · `get_public_product_addons` · `get_public_product_variants` · `get_public_banners` |
| **دوال مساعدة** | `c04_resolve_active_restaurant` · `c04_product_belongs_to_restaurant` |
| **SECURITY DEFINER** | نعم — كل الدوال أعلاه + `SET search_path = public` |
| **تعمل بـ restaurant_slug** | نعم — المعامل `p_restaurant_slug text` في كل RPC عامة |
| **تتحقق من مطعم نشط** | نعم — `c04_resolve_active_restaurant` يشترط `restaurants.is_active = true` ووجود slug |
| **v_enable_strict_mode افتراضياً** | نعم — `v_enable_strict_mode boolean := false` (قسم §9 في الملف) |

### حقول العائد (آمنة للزبون)

- **منتجات:** id, restaurant_id, name, description, price, image_url, category, variants (jsonb), is_available, created_at — **متاحة فقط** (`is_available = true`)
- **إضافات:** product_id, name, price (عبر join منتجات المطعم)
- **أحجام:** id, product_id, name, price, sort_order (عبر join)
- **بانرات:** id, restaurant_id, image_url, title, is_active, sort_order, created_at — **نشطة فقط**

### صلاحيات التنفيذ

`GRANT EXECUTE TO anon, authenticated` على كل RPCs العامة.

---

## 4) سياسات RLS

### عند `strict=false` (الافتراضي — Run 1)

**لا يُحذف شيء.** تبقى كل السياسات الحالية، بما فيها:

| السياسة | الجداول |
|---------|---------|
| `catalog_c02_select_anon_interim` | products, product_addons, product_variants, banners |
| `catalog_c02_select_authenticated_tenant` | نفس الجداول الأربعة |
| `catalog_c02_insert/update/delete_authenticated_tenant` | نفس الجداول |
| سياسات legacy (إن وُجدت ولم يُشغَّل C-02 strict) | مثل `products_public_read`, `banners_public_read`, … |

### عند `strict=true` (Run 2 — قسم §9 فقط)

**يُحذف فقط:**

| Policy | Table |
|--------|-------|
| `catalog_c02_select_anon_interim` | `public.products` |
| `catalog_c02_select_anon_interim` | `public.product_addons` |
| `catalog_c02_select_anon_interim` | `public.product_variants` |
| `catalog_c02_select_anon_interim` | `public.banners` |

**لا يُحذف:** أي policy أخرى (authenticated، legacy، C-02 strict drops، orders، storage).

### تأكيد عدم تعديل orders و storage

- لم يُضف أو يُعدَّل أي SQL في `c01_orders_rls_migration.sql` أو `c03_storage_rls_hardening.sql`
- migration C-04 لا يذكر `orders` أو `storage.objects`

---

## 5) تعديلات Flutter

### أين كانت القراءة سابقاً (واجهة الزبون)

| المورد | المسار القديم |
|--------|----------------|
| منتجات + embed addons/variants | `CustomerMenuController` → `ProductRepository.fetchProductsForRestaurant` / `watchProductsForRestaurant` → `SupabaseProductService.fetchProducts` / `watchProducts` → `.from('products').select(...)` |
| إضافات/أحجام (عند فشل embed) | `SupabaseProductService._attachAddonsToProducts` / `_fetchVariantRowsForProductIds` → `.from('product_addons')` / `.from('product_variants')` |
| بانرات | `CustomerMenuBannersController` → `BannerRepository.fetchActiveBanners` / `watchActiveBanners` → `SupabaseBannerService` → `.from('banners')` |

### أين أصبحت الآن (RPC)

| المورد | المسار الجديد |
|--------|----------------|
| منتجات | `CustomerMenuController` → `ProductRepository.fetchProductsForCustomerMenu` / `watchProductsForCustomerMenu` |
| تجميع RPC | `PublicCatalogService.fetchMenuProducts` / `watchMenuProducts` |
| RPCs | `get_public_products` + `get_public_product_addons` + `get_public_product_variants` |
| دمج الصفوف | `SupabaseProductService.assemblePublicMenuProducts()` |
| بانرات | `CustomerMenuBannersController` → `BannerRepository.fetchActiveBannersForCustomerMenu` / `watchActiveBannersForCustomerMenu` → `PublicCatalogService` → `get_public_banners` |

### خدمات/دوال جديدة

| الاسم | الملف |
|-------|-------|
| `PublicCatalogService` | `lib/services/public_catalog_service.dart` |
| `fetchMenuProducts` / `watchMenuProducts` | نفس الملف |
| `fetchActiveBanners` / `watchActiveBanners` | نفس الملف (RPC بانرات) |
| `assemblePublicMenuProducts` | `lib/services/supabase_product_service.dart` |
| `fetchProductsForCustomerMenu` / `watchProductsForCustomerMenu` | `lib/services/product_repository.dart` |
| `fetchActiveBannersForCustomerMenu` / `watchActiveBannersForCustomerMenu` | `lib/services/banner_repository.dart` |

### هل بقي direct read في واجهة الزبون؟

| الجدول | direct `.from()` في `lib/customer_features/`؟ |
|--------|-----------------------------------------------|
| `products` | **لا** |
| `product_variants` | **لا** |
| `product_addons` | **لا** |
| `banners` | **لا** |

**ملاحظة:** التحديث اللحظي للزبون أصبح **polling كل 20 ثانية** (`PublicCatalogService.menuPollInterval`) بدلاً من Realtime على الجداول — مطلوب بعد strict لأن anon لن يملك SELECT على الجداول.

**الأدمن** ما زال يستخدم SELECT مباشر عبر `SupabaseProductService` / `SupabaseBannerService` (مصادق).

---

## 6) خطوات التنفيذ اليدوي

### المرحلة الأولى — Run 1 (`strict=false`)

1. **Supabase SQL Editor:** نفّذ `supabase/c04_public_catalog_rpc_hardening.sql` **كاملاً** (الافتراضي `v_enable_strict_mode := false`).
2. **تحقق RPC:**
   ```sql
   SELECT count(*) FROM public.get_public_products('snack_burger');
   SELECT count(*) FROM public.get_public_product_addons('snack_burger');
   SELECT count(*) FROM public.get_public_product_variants('snack_burger');
   SELECT count(*) FROM public.get_public_banners('snack_burger');
   ```
3. **انشر/شغّل** Flutter المحدّث (C-04).
4. **اختبار منيو الزبون:** `/#/<slug>` — منتجات، فئات، أحجام، إضافات، بانرات، إرسال طلب.
5. **اختبار لوحة الإدارة:** `/#/<slug>/admin` — قائمة منتجات، تعديل منتج، بانرات CRUD.
6. **اختبار الطلبات:** إرسال طلب زبون، قبول/رفض، متابعة حالة — **لا علاقة لـ C-04 بـ orders** لكن يُفضَّل regression سريع.

### المرحلة الثانية — Run 2 (`strict=true`)

1. بعد نجاح المرحلة الأولى، في **قسم §9** غيّر:
   ```sql
   v_enable_strict_mode boolean := true;
   ```
2. نفّذ **قسم §9 فقط** (`DO $$ ... END $$`).
3. **فحص RLS:**
   ```sql
   SELECT tablename, policyname
   FROM pg_policies
   WHERE policyname = 'catalog_c02_select_anon_interim'
     AND tablename IN ('products','product_addons','product_variants','banners');
   -- المتوقع: 0 صفوف
   ```
4. أعد اختبار منيو الزبون (يجب أن يعمل عبر RPC فقط).
5. أعد اختبار لوحة الإدارة (authenticated).

### Rollback strict (إن لزم)

أعد إنشاء `catalog_c02_select_anon_interim` من `supabase/c02_catalog_rls_migration.sql` §6 للجداول الأربعة.

---

## 7) نتائج الفحص

### flutter analyze

```
Analyzing snack_burger...
No issues found! (ran in 3.6s)
```

### flutter test

```
142 tests passed (شامل 4 اختبارات جديدة في public_catalog_service_test.dart)
```

اختبارات C-04 ذات الصلة:

- `PublicCatalogService.publicCatalogRpcLabel`
- `PublicCatalogService.parsePublicBannerRows`
- `SupabaseProductService.assemblePublicMenuProducts` (دمج + استبعاد tenant آخر)

### grep — عدم direct reads في واجهة الزبون

بحث في `lib/customer_features/`:

```
fetchProductsForCustomerMenu / watchProductsForCustomerMenu
  → customer_menu_controller.dart

fetchActiveBannersForCustomerMenu / watchActiveBannersForCustomerMenu
  → customer_menu_banners_controller.dart
```

**لا توجد** إشارات إلى:

- `fetchProductsForRestaurant` / `watchProductsForRestaurant`
- `SupabaseProductService.fetchProducts` / `watchProducts`
- `SupabaseBannerService.fetchActiveBanners` / `watchActiveBanners`
- `.from('products')` / `.from('banners')` / `.from('product_variants')` / `.from('product_addons')`

داخل `lib/customer_features/`.

---

## 8) قرار الجاهزية

| السؤال | القرار | ملاحظة |
|--------|--------|--------|
| **جاهز للتنفيذ الأول (Run 1, strict=false)** | **نعم** | الكود + الاختبارات جاهزة؛ SQL يُنفَّذ يدوياً في Supabase |
| **جاهز لتفعيل strict=true** | **نعم — بعد Run 1 واختبار يدوي** | لا تفعّل strict قبل نشر Flutter ونجاح منيو الزبون |
| **مخاطر متبقية** | انظر أدناه | |

### مخاطر / ملاحظات متبقية

1. **Legacy catalog policies:** إن لم يُشغَّل C-02 strict، قد تبقى `*_public_read USING (true)` — C-04 strict يحذف **anon interim فقط**، وليس legacy.
2. **Polling بدل Realtime للزبون:** تحديث المنيو قد يتأخر حتى 20 ثانية بعد strict.
3. **مطعم غير نشط:** RPC ترفع `restaurant_not_found_or_inactive` — سلوك مقصود.
4. **SQL لم يُنفَّذ بعد في Supabase من هذا الوكيل** — التقرير يصف الحالة بعد تنفيذ الكود محلياً فقط.

---

**نهاية التقرير**
