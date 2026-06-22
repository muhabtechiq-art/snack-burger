# C-04 RPC Migration Report — Customer Menu Catalog Reads

**التاريخ:** 2026-06-03  
**النطاق:** Flutter فقط — منيو الزبون (Customer Menu)  
**المرجع SQL:** `supabase/c04_public_catalog_rpc_hardening.sql` (مُنفَّذ في Supabase)

---

## 1. ملخص التنفيذ

تم إكمال الانتقال الكامل لقراءة كتالوج منيو الزبون من **SELECT مباشر** على جداول `products` / `product_addons` / `product_variants` / `banners` إلى **RPC فقط** عبر `PublicCatalogService`.

| الجدول | RPC المستخدم | معامل الاستدعاء |
|--------|--------------|-----------------|
| `products` | `get_public_products` | `p_restaurant_slug` |
| `product_addons` | `get_public_product_addons` | `p_restaurant_slug` |
| `product_variants` | `get_public_product_variants` | `p_restaurant_slug` |
| `banners` | `get_public_banners` | `p_restaurant_slug` |

**مسار البيانات (منتجات):**

```
CustomerMenuController
  → ProductRepository.fetchProductsForCustomerMenu / watchProductsForCustomerMenu
  → PublicCatalogService.fetchMenuProducts / watchMenuProducts
  → rpc(get_public_products | get_public_product_addons | get_public_product_variants)
  → SupabaseProductService.assemblePublicMenuProducts (دمج + parsing)
```

**مسار البيانات (بانرات):**

```
CustomerMenuBannersController
  → BannerRepository.fetchActiveBannersForCustomerMenu / watchActiveBannersForCustomerMenu
  → PublicCatalogService.fetchActiveBanners / watchActiveBanners
  → rpc(get_public_banners)
  → PromoBannerModel.fromSupabase
```

**ما لم يُمس (حسب المطلوب):** لوحة الإدارة، الكاشير، نظام الطلبات، Business Day، ملفات SQL، RLS.

**التحديث الحي:** استبدال Realtime بـ **polling كل 20 ثانية** (`PublicCatalogService.menuPollInterval`) — مناسب لمرحلة strict mode.

---

## 2. الملفات التي تم تعديلها

| الملف | نوع التعديل |
|-------|-------------|
| `lib/services/public_catalog_service.dart` | **جديد** — طبقة RPC لمنيو الزبون |
| `lib/services/product_repository.dart` | إضافة `fetchProductsForCustomerMenu` / `watchProductsForCustomerMenu` |
| `lib/services/banner_repository.dart` | إضافة `fetchActiveBannersForCustomerMenu` / `watchActiveBannersForCustomerMenu` |
| `lib/services/supabase_product_service.dart` | إضافة `assemblePublicMenuProducts` لدمج صفوف RPC |
| `lib/customer_features/menu/customer_menu_controller.dart` | استخدام مسار RPC للمنتجات |
| `lib/customer_features/menu/customer_menu_banners_controller.dart` | استخدام مسار RPC للبانرات |
| `test/services/public_catalog_service_test.dart` | **جديد** — اختبارات RPC parsing ودمج الصفوف |

---

## 3. الملفات التي تم فحصها (بدون تعديل ضمن نطاق C-04)

### منيو الزبون (`lib/customer_features/`)

- `menu/customer_menu_controller.dart` ✓ يستخدم RPC
- `menu/customer_menu_banners_controller.dart` ✓ يستخدم RPC
- `menu/customer_menu_screen.dart`
- `menu/customer_menu_drawer.dart`
- `menu/menu_mock_products.dart` (بيانات وهمية محلية — لا Supabase)
- `menu/utils/product_grouping.dart`
- `widgets/*` (بطاقات، تفاصيل منتج، بانر، سلة، إلخ)
- `data/customer_order_repository.dart` (طلبات — خارج نطاق الكتالوج)
- `services/customer_order_session.dart`
- `services/customer_last_order_notifier.dart`
- `my_orders/my_orders_screen.dart`
- `order_status/order_status_screen.dart`
- `delivery/*`
- `maintenance/maintenance_screen.dart`
- `theme/customer_menu_theme.dart`

### خدمات ومستودعات

- `lib/services/supabase_product_service.dart` (مسارات admin/cashier تبقى SELECT مباشر)
- `lib/services/supabase_banner_service.dart` (admin فقط)
- `lib/services/supabase_order_service.dart`
- `lib/services/supabase_business_day_service.dart`
- `lib/services/supabase_restaurant_service.dart`
- `lib/services/supabase_app_settings_service.dart`
- `lib/services/supabase_customer_location_service.dart`
- `lib/core/cache/menu_catalog_cache.dart` (كاش محلي فقط — لا SELECT على الجداول)

### إدارة / كاشير / أدوات

- `lib/admin_features/**` (قراءة مباشرة للجداول — مقصود)
- `lib/dev/snack_burger_product_seeder.dart` (seeder — ليس منيو زبون)
- `lib/cashier_features/**` (إن وُجد)

### اختبارات

- `test/services/public_catalog_service_test.dart`
- `test/**` (باقي المشروع — 142 اختبار)

### توثيق (مرجع فقط)

- `docs/phase_c04_public_catalog_rpc_hardening_report.md`
- `supabase/c04_public_catalog_rpc_hardening.sql`

---

## 4. ما الذي تم استبداله

| قبل (منيو الزبون) | بعد |
|-------------------|-----|
| `ProductRepository.fetchProductsForRestaurant` → `SupabaseProductService.fetchProducts` → `.from('products').select(...)` | `ProductRepository.fetchProductsForCustomerMenu` → `PublicCatalogService` → `get_public_products` |
| `_attachAddonsToProducts` → `.from('product_addons')` | `get_public_product_addons` ضمن `fetchMenuProducts` |
| `_fetchVariantRowsForProductIds` → `.from('product_variants')` | `get_public_product_variants` ضمن `fetchMenuProducts` |
| `BannerRepository.fetchActiveBanners` → `SupabaseBannerService` → `.from('banners')` | `BannerRepository.fetchActiveBannersForCustomerMenu` → `get_public_banners` |
| Realtime streams على الجداول | `watchMenuProducts` / `watchActiveBanners` — polling 20s |

**صيغة الاستدعاء الموحّدة:**

```dart
_client.rpc<dynamic>(
  'get_public_products', // أو addons / variants / banners
  params: {'p_restaurant_slug': restaurantSlug.trim().toLowerCase()},
);
```

**معالجة الأنواع (RPC → Models):**

- `products.id` و `product_addons.product_id` و `product_variants.product_id`: `bigint` من Postgres → `int` في Dart → `_asString()` → `String` في `ProductModel.id`
- `product_variants.id`: `uuid` → `String` عبر `ProductVariant._readOptionalId`
- `banners.id`: `uuid` → `PromoBannerModel.fromSupabase` (`data['id']?.toString()`)

---

## 5. هل بقي أي SELECT مباشر على الجداول الأربعة داخل منيو الزبون؟

**لا.** بعد البحث في `lib/` بالكامل:

- **صفر** استخدام لـ `.from('products')` / `.from('product_addons')` / `.from('product_variants')` / `.from('banners')` داخل `lib/customer_features/`
- **صفر** استدعاء لـ `SupabaseProductService.fetchProducts` / `watchProducts` أو `SupabaseBannerService.fetchActiveBanners` / `watchActiveBanners` من مسار الزبون
- المسارات الوحيدة للكتالوج في الزبون: `fetchProductsForCustomerMenu` / `watchProductsForCustomerMenu` و `fetchActiveBannersForCustomerMenu` / `watchActiveBannersForCustomerMenu`

**ملاحظة:** `MenuCatalogCache` يقرأ/يكتب **SharedPreferences محلياً** فقط — ليس SELECT على Supabase.

**مسارات admin/cashier/seeder** ما زالت تستخدم SELECT مباشر — **مقصود** وخارج نطاق هذه المهمة.

---

## 6. نتيجة `flutter analyze`

```
Analyzing snack_burger...
No issues found! (ran in ~80s)
```

**الحالة:** بدون أخطاء أو تحذيرات مرتبطة بهذا التعديل.

---

## 7. نتيجة الاختبارات

```
flutter test
00:17 +142: All tests passed!
```

يشمل `test/services/public_catalog_service_test.dart` (5 اختبارات):

- تطبيع slug في تسمية RPC
- ترتيب وفلترة البانرات النشطة
- دمج صفوف RPC (منتج + إضافة + حجم) مع `product_id` من نوع `int`
- دمج `variant.id` من نوع UUID (مطابقة production)
- استبعاد منتجات خارج نطاق المطعم

---

## 8. ملاحظات ومخاطر متبقية

| # | الملاحظة | الخطورة |
|---|----------|---------|
| 1 | **Strict mode** في SQL (`v_enable_strict_mode := false` افتراضياً) — يجب تشغيل المرحلة الثانية يدوياً بعد نشر Flutter | تشغيلية |
| 2 | **تأخير التحديث** حتى 20 ثانية بسبب polling بدل Realtime | منخفضة |
| 3 | **كاش محلي** (`MenuCatalogCache`) قد يعرض بيانات قديمة لحظياً قبل أول fetch RPC | منخفضة |
| 4 | **slug فارغ** يرمي `ArgumentError` — يعتمد على تمرير slug صحيح من routing المطعم | منخفضة |
| 5 | سياسات RLS القديمة على الجداول (`*_public_read`) تبقى حتى C-02 strict — RPC يحمي مسار الزبون لكن لا يغلق المسارات القديمة لـ anon | أمنية (SaaS) |
| 6 | لم يُجرَ اختبار تكامل حي ضد Supabase production في هذه الجلسة — يُنصح بفحص يدوي للمنيو بعد النشر | تشغيلية |

---

## 9. تقييم الجاهزية

| المعيار | الوزن | النتيجة |
|---------|-------|---------|
| اكتمال ترحيل Flutter لمسار الزبون | 35% | 35/35 |
| parsing وأنواع RPC (bigint + uuid) | 20% | 20/20 |
| `flutter analyze` نظيف | 15% | 15/15 |
| اختبارات وحدة | 15% | 15/15 |
| عدم المساس بمسارات admin/orders | 10% | 10/10 |
| نشر SQL strict + اختبار حي production | 5% | 2/5 |

### **التقييم الإجمالي: 97 / 100**

**الحكم:** جاهز لنشر Flutter لمنيو الزبون على RPC. الخطوة المتبقية للوصول إلى 100%: اختبار حي على Supabase + تفعيل strict mode (§9 في SQL) بعد التأكد من استقرار المنيو.

---

## 10. مرجع سريع للمراجعة (ChatGPT)

```
CUSTOMER MENU CATALOG — RPC ONLY (C-04 Flutter migration complete)

RPCs: get_public_products, get_public_product_addons,
      get_public_product_variants, get_public_banners
Param: p_restaurant_slug (lowercased)

Entry: PublicCatalogService
Controllers: CustomerMenuController, CustomerMenuBannersController
Assembly: SupabaseProductService.assemblePublicMenuProducts

Direct .from('products'|'product_addons'|'product_variants'|'banners')
in customer menu path: NONE

flutter analyze: No issues found
flutter test: 142 passed

Readiness: 97/100
```

---

*تم إنشاء هذا التقرير آلياً بعد إكمال ترحيل C-04 في Flutter.*
