# MobileTinaVPN for Windows

نسخهٔ مستقل و پرتابل ویندوز MobileTinaVPN با رابط فارسی Flutter و هستهٔ Xray.

این پروژه تلاش نمی‌کند کد Android را مستقیماً به Windows تبدیل کند. هویت بصری و تجربهٔ کاربری MobileTinaVPN Android بازسازی شده و کنترلر شبکه برای Windows به‌صورت مستقل نوشته شده است.

## امکانات نسخهٔ 0.5

- رابط فارسی، راست‌به‌چپ و واکنش‌گرا با حالت روشن و تیره
- حالت خودکار (Smart Connect) و انتخاب دستی سرور
- پنجرهٔ پیش‌فرض عمودی با ابعاد نزدیک به رابط موبایل
- منوی مدیریت کانفیگ برای ورود از کلیپ‌بورد، تست، بروزرسانی و پاک‌سازی
- دریافت و بروزرسانی Subscription از HTTPS/HTTP
- افزودن مستقیم لینک اشتراک یا کانفیگ سرور از Clipboard
- اشتراک‌گذاری جداگانهٔ هر سرور با QR یا کپی کانفیگ
- پشتیبانی از VMess، VLESS، Trojan، Shadowsocks و SOCKS
- پشتیبانی از TLS، REALITY، TCP، WebSocket، gRPC، HTTPUpgrade، XHTTP و KCP
- تشخیص انقضای Subscription، حذف پینگ قبلی و جلوگیری از اتصال به سرور منقضی
- تست هم‌زمان واقعی از داخل Xray و انتخاب کمترین تأخیر قابل‌استفاده
- اجرای Xray به‌عنوان Process مستقل و بررسی Config پیش از اتصال
- Local SOCKS و HTTP proxy با پورت‌های قابل‌تنظیم
- تنظیم Windows System Proxy بدون نیاز به Administrator
- ذخیره و بازیابی تنظیمات Proxy قبلی کاربر
- بازیابی امن پس از Crash یا خاموشی ناگهانی
- اجرای اختیاری همراه Windows
- System Tray؛ بستن پنجره برنامه را در Tray نگه می‌دارد
- ذخیرهٔ همهٔ اطلاعات در پوشهٔ `portable-data` کنار برنامه
- CI برای Analyze، Test، Build و تولید ZIP پرتابل Windows x64
- فونت فارسی آزاد Vazirmatn UI و چیدمان نزدیک به رابط Android MobileTina
- صفحهٔ معرفی MobileTina با شبکه‌های اجتماعی و آدرس فروشگاه‌ها
- مبهم‌سازی AOT نام‌ها و سمبل‌های Dart در Build رسمی Release
- بسته‌بندی محافظت‌شدهٔ تصاویر و فونت‌ها؛ فایل خام WebP/TTF در ZIP قرار نمی‌گیرد
- رمزگذاری احرازشدهٔ لینک اشتراک، کانفیگ‌ها و تنظیمات در `portable-data/state.dat`
- مهاجرت خودکار و یک‌بارهٔ `state.json` نسخه‌های قبلی به ذخیره‌سازی محافظت‌شده
- حذف کانفیگ موقت Xray از دیسک بلافاصله پس از بارگذاری توسط Core

> حالت TUN در نسخهٔ 0.5 فعال نیست. System Proxy فقط ترافیک برنامه‌هایی را پوشش می‌دهد که تنظیم Proxy ویندوز را رعایت می‌کنند. TUN/Wintun پس از تثبیت این پایه اضافه می‌شود.

## دریافت نسخهٔ پرتابل

1. وارد بخش **Actions** ریپو شوید.
2. آخرین اجرای موفق workflow با نام **Build portable Windows client** را باز کنید.
3. Artifact با نام `MobileTinaVPN-Windows-x64` را دانلود و Extract کنید.
4. `MobileTinaVPN.exe` را اجرا کنید.

Releaseهای Tagشده نیز فایل `MobileTinaVPN-Windows-x64.zip` را منتشر می‌کنند.

## ساخت محلی

پیش‌نیازها:

- Windows 10/11 x64
- Flutter stable با Windows Desktop فعال
- Visual Studio 2022 و workload مربوط به Desktop development with C++

```powershell
flutter config --enable-windows-desktop
flutter pub get
flutter test
flutter analyze
flutter build windows --release --obfuscate --split-debug-info=build/private-symbols
```

خروجی Flutter برای اتصال واقعی باید پوشهٔ `core` شامل `xray.exe`، `geoip.dat` و `geosite.dat` را کنار EXE داشته باشد. Workflow رسمی نسخهٔ Xray را با SHA-256 ثابت دانلود و اضافه می‌کند.

payloadهای آمادهٔ `assets/protected` همراه سورس هستند. برای جایگزینی مجاز
دارایی‌ها، یک پوشهٔ منبع با ساختار `branding`، `connection` و `fonts` بسازید و
فرمان زیر را اجرا کنید؛ فایل‌های خام نباید به فهرست `flutter.assets` برگردند:

```powershell
dart run tool/protect_assets.dart C:\path\to\source-assets assets\protected
```

## ساختار پرتابل

```text
MobileTinaVPN/
├── MobileTinaVPN.exe
├── flutter_windows.dll
├── data/                    # Flutter runtime
├── core/
│   ├── xray.exe
│   ├── geoip.dat
│   └── geosite.dat
└── portable-data/           # subscriptions, settings, logs, runtime state
```

## امنیت و حریم خصوصی

- لینک و رمز Subscription در Log برنامه ثبت نمی‌شوند.
- اعتبار گواهی HTTPS نادیده گرفته نمی‌شود.
- Config پیش از اجرای Core با خود Xray بررسی می‌شود.
- فایل Xray در CI با SHA-256 ثابت اعتبارسنجی می‌شود.
- Proxy قبلی Windows پیش از اتصال ذخیره و پس از قطع یا بازیابی Crash بازگردانده می‌شود.
- برای دریافت Build رسمی، فقط Artifact یا Release همین ریپو را استفاده کنید.
- فایل‌های تصویری و فونت در خروجی رسمی به‌شکل payload رمزگذاری‌شده بسته‌بندی می‌شوند و فقط در حافظه باز می‌شوند.
- مبهم‌سازی و کلید داخلی برنامه مانع استخراج قطعی توسط مهندسی معکوس حرفه‌ای نیست؛ هدف آن حذف دسترسی ساده به دارایی‌ها و داده‌های ذخیره‌شده است.
- سمبل‌های جداشدهٔ Build داخل ZIP عمومی قرار نمی‌گیرند.

## توسعه

شرح معماری در [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) و محدودهٔ نسخهٔ اول در [docs/V1_SCOPE.md](docs/V1_SCOPE.md) ثبت شده است.

## مجوز

این پروژه تحت GPL-3.0 منتشر می‌شود. مجوز اجزای ثالث در [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) آمده است.
