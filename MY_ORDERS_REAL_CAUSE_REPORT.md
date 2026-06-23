# MY_ORDERS_REAL_CAUSE_REPORT.md

**التاريخ:** 2026-06-22  
**النطاق:** My Orders / Orders / CustomerOrderRepository / SupabaseOrderService  
**لم يُمس:** C-04، PublicCatalogService، الكتالوج، RLS، SQL

---

## 1. أين كان الخلل

### أ) عدم تطابق مسار القراءة مع مسار الحفظ

| | **الحفظ** (`submitOrder` → `submit_customer_order`) | **القراءة (قبل الإصلاح)** |
|---|-----------------------------------------------------|---------------------------|
| الهاتف | `orders.phone_number` ← `p_phone_number` = **`customerPhone.trim()`** | Realtime بـ **`slug` فقط** — الهاتف يُفلتر **client-side** |
| slug | `orders.slug` ← **`p_slug` = slug.trim().toLowerCase()** | `eq('slug')` على Realtime بدون SELECT أولي |
| restaurant_id | UUID في DB | **`OrderTenantMatch` + restaurantUuid** client-side — قد يستبعد صفاً رغم تطابق slug+phone |
| status | `pending` → `accepted` … | **لا فلتر يخفي `accepted`** (لم يكن هذا السبب) |
| آلية الجلب | INSERT | Realtime **بدون** `SELECT WHERE slug AND phone_number` |

**النتيجة:** عند فتح «طلباتي» لا يُنفَّذ استعلام Supabase يطابق مفاتيح الحفظ → قائمة فارغة.

### ب) ليس السبب

- إخفاء حالة `accepted`
- تحويل رقم الهاتف (المعيار: 11 رقم يبدأ بـ 0 — `trim()` فقط)

---

## 2. الإصلاح

### الحفظ — بدون تغيير المنطق

```dart
p_phone_number: customerPhone.trim()
p_slug: slug.trim().toLowerCase()
```

**Log:** `[MyOrdersSave] phone_number=… slug=…`

### القراءة — محاذاة كاملة

```dart
SELECT * FROM orders
WHERE slug = eq.<slug.trim().toLowerCase()>
  AND phone_number = eq.<phone.trim()>
  AND created_at >= since   // 24h مؤقتًا
```

**Logs:**

- `[MyOrdersRead] fetchOrdersByPhone phone_number=… slug=…`
- `[MyOrdersRead] query=…`
- `[MyOrdersRead] supabaseRowCount=N`
- `[MyOrdersFilter] supabaseRows=N → visible=M`

### ما أُزيل من مسار «طلباتي»

- فلتر **`restaurant_id` / `OrderTenantMatch`** client-side
- إعادة فلترة **`phone`** client-side (Supabase يفلترها)
- الاعتماد على Realtime فقط (يُبقى كمحفّز لإعادة `fetchOrdersByPhone`)

### بعد Supabase

فلتر client-side **وحيد:** نافذة الوقت (24h) + قواعد المرفوض — **بدون** فلتر status لـ `accepted`.

---

## 3. الملفات المعدّلة

| الملف | التعديل |
|-------|---------|
| `lib/services/supabase_order_service.dart` | `fetchOrdersByPhone` server-side؛ logs؛ إزالة tenant filter؛ `filterOrdersByPhoneAndSlug` مبسّط |
| `lib/customer_features/data/customer_order_repository.dart` | إزالة `restaurantUuid` من مسار My Orders |
| `lib/customer_features/my_orders/my_orders_screen.dart` | لا يمرّر `restaurantUuid` |
| `lib/core/config/customer_my_orders_config.dart` | نافذة 24h (مؤقت) |
| `test/services/supabase_order_service_my_orders_test.dart` | اختبارات محدّثة |

---

## 4. كيف تختبر أن الطلب يظهر

1. **سجّل خروج الأدmin** أو افتح **نافذة خاصة** (مسار الزبون `/snack_burger` وليس `/admin`).
2. من المنيو أرسل طلباً — راقب في الـ console:
   ```
   [MyOrdersSave] phone_number=07827399119 slug=snack_burger
   ```
3. افتح **طلباتي** — راقب:
   ```
   [MyOrdersRead] fetchOrdersByPhone phone_number=07827399119 slug=snack_burger
   [MyOrdersRead] supabaseRowCount=3
   [MyOrdersFilter] supabaseRows=3 → visible=3
   ```
4. **Hot restart** (`R`) بعد أي تعديل كود.
5. إذا `supabaseRowCount=0`:
   - قارن `[MyOrdersSave]` مع `[MyOrdersRead]` — يجب أن يتطابقا حرفياً
   - راجع `[MyOrdersDiag] last10ForSlug` — يظهر آخر 10 طلبات للمطعم مع `customer_phone`
6. قبول الطلب من الكاشير — يجب أن يبقى ظاهراً (`accepted` لا يُستبعد).

---

## 5. flutter analyze

```
No issues found!
```

---

## 6. الحكم

**السبب الحقيقي:** القراءة لم تستخدم نفس مفاتيح الحفظ (`slug` + `phone_number`) على Supabase، واعتمدت على Realtime + فلترة client-side (بما فيها `restaurant_id`). **ليس** إخفاء `accepted`.
