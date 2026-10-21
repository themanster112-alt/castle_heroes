# فتح المشروع على جهاز ثاني

ثبّت Git وFlutter بإصدار يدعم Dart 3.13.4 أو أحدث، ثم نفّذ:

```sh
git clone https://github.com/themanster112-alt/castle_heroes.git
cd castle_heroes
flutter pub get
flutter run -d chrome
```

إذا كانت عندك نسخة مرتبطة بالمستودع مسبقًا، احفظ تعديلاتك المحلية ثم نفّذ `git pull --ff-only` و`flutter pub get` للحصول على آخر نسخة.

للعب مباشرة: https://castle-heroes-online-20261021.web.app

اللعب الأونلاين متصل بمشروع Firebase `castle-heroes-online-20261021`، وبنك الأسئلة بمشروع `castle-heroes-20261014`. إعدادات التطبيق موجودة في المصدر؛ لا تحتاج إنشاء مشروع جديد أو تسجيل دخول إداري لتشغيل اللعبة. توجد نسخة محلية من الأسئلة داخل `data`.

لتشغيل Android، جهّز Android SDK وفعّل USB debugging ثم نفّذ `flutter devices` و`flutter run`.

تفاصيل الغرف والقواعد والنشر والاختبارات موجودة في [docs/ONLINE.md](docs/ONLINE.md). أدوات الإدارة داخل `tools` تحتاج Firebase CLI وحسابًا مخوّلًا عند نشر القواعد أو تحديث البيانات، ولا تحتاجها لتشغيل التطبيق.
