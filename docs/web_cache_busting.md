# Web cache busting (Snack Burger Flutter)

## فكرتان منفصلتان (الطريقة الاحترافية)

| المفهوم | مثال | من يغيّره؟ | يظهر للزبون؟ |
|---------|------|------------|--------------|
| **رقم الإصدار** (SemVer) | `1.0.0` في `pubspec.yaml` | أنت يدوياً عند إصدار حقيقي | نعم (إن عرضته في التطبيق) |
| **معرّف النشر** (deploy tag) | `a3f9c2b` (أول 7 حروف من commit) | **تلقائياً** عند كل بناء | لا |

لا ترفع `1.0.0` → `1.0.847` في كل تعديل. ارفع `1.0.0` → `1.0.1` فقط عند إصلاح مهم، أو `1.1.0` عند ميزة جديدة.

معرّف النشر يُحقَن في `web/index.html` كـ `__CACHE_TAG__` أثناء `post_build_gh_pages` ويجبر الموبايل على جلب `main.dart.js` الجديد.

## كيف يعمل التحديث

1. **`web/index.html`** (المصدر يحتوي `__CACHE_TAG__`):
   - يُستبدل عند البناء بـ commit hash أو `SNACK_BURGER_CACHE_TAG`.
   - يلغي service workers القديمة.
   - يحمّل `flutter_bootstrap.js?v=<tag>`.

2. **`web/flutter_bootstrap.js`**:
   - لا يسجّل service worker.
   - يجلب `version.json` بدون كاش.
   - يضيف `?v=<tag>` لـ `main.dart.js`.

3. **`post_build`** يحذف `flutter_service_worker.js` من `build/web/`.

## أولوية معرّف النشر

1. `SNACK_BURGER_CACHE_TAG` (إن وُجد)
2. `GITHUB_SHA` (أول 7 أحرف) — في GitHub Actions
3. `git rev-parse --short HEAD` — بناء محلي
4. طابع زمني `local-...`

## متى تغيّر `pubspec.yaml` يدوياً؟

```yaml
version: 1.0.0+1
#        ^^^^^  ^ build number (للمتجر/أندرويد — ارفعه عند نشر APK جديد)
#        SemVer — للزبون
```

- **كل push على main للويب:** لا حاجة لتغيير `pubspec` — معرّف النشر يكفي.
- **إصدار APK جديد:** ارفع `+1` أو `version` حسب نوع التحديث.

## بناء محلي

```powershell
flutter build web --release --base-href /snack-burger/
.\scripts\post_build_gh_pages.ps1
```

أو:

```powershell
.\scripts\github_pages_build.ps1
```

## SemVer سريع

| التغيير | مثال |
|---------|------|
| إصلاح خطأ | `1.0.0` → `1.0.1` |
| ميزة جديدة | `1.0.1` → `1.1.0` |
| تغيير جذري | `1.1.0` → `2.0.0` |
