# MobileTinaVPN for Windows

نسخهٔ مستقل و پرتابل ویندوز MobileTinaVPN با رابط فارسی Flutter و هستهٔ Xray.

این پروژه تلاش نمی‌کند کد Android را مستقیماً به Windows تبدیل کند. هویت بصری و تجربهٔ کاربری MobileTinaVPN Android بازسازی شده و کنترلر شبکه برای Windows به‌صورت مستقل نوشته شده است.

## امکانات نسخهٔ 0.1

- رابط فارسی، راست‌به‌چپ و واکنش‌گرا با حالت روشن و تیره
- حالت خودکار (Smart Connect) و انتخاب دستی سرور
- دریافت و بروزرسانی Subscription از HTTPS/HTTP
- پشتیبانی از VMess، VLESS، Trojan، Shadowsocks و SOCKS
- پشتیبانی از TLS، REALITY، TCP، WebSocket، gRPC، HTTPUpgrade، XHTTP و KCP
- تست هم‌زمان دسترسی سرورها و انتخاب کمترین تأخیر قابل‌دسترسی
- اجرای Xray به‌عنوان Process مستقل و بررسی Config پیش از اتصال
- Local SOCKS و HTTP proxy با پورت‌های قابل‌تنظیم
- تنظیم Windows System Proxy بدون نیاز به Administrator
- ذخیره و بازیابی تنظیمات Proxy قبلی کاربر
- بازیابی امن پس از Crash یا خاموشی ناگهانی
- اجرای اختیاری همراه Windows
- System Tray؛ بستن پنجره برنامه را در Tray نگه می‌دارد
- ذخیرهٔ همهٔ اطلاعات در پوشهٔ `portable-data` کنار برنامه
- CI برای Analyze، Test، Build و تولید ZIP پرتابل Windows x64

> حالت TUN در نسخهٔ 0.1 فعال نیست. System Proxy فقط ترافیک برنامه‌هایی را پوشش می‌دهد که تنظیم Proxy ویندوز را رعایت می‌کنند. TUN/Wintun پس از تثبیت این پایه اضافه می‌شود.

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
flutter build windows --release
```

خروجی Flutter برای اتصال واقعی باید پوشهٔ `core` شامل `xray.exe`، `geoip.dat` و `geosite.dat` را کنار EXE داشته باشد. Workflow رسمی نسخهٔ Xray را با SHA-256 ثابت دانلود و اضافه می‌کند.

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

## توسعه

شرح معماری در [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) و محدودهٔ نسخهٔ اول در [docs/V1_SCOPE.md](docs/V1_SCOPE.md) ثبت شده است.

## مجوز

این پروژه تحت GPL-3.0 منتشر می‌شود. مجوز اجزای ثالث در [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) آمده است.
