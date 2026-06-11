Snack Burger — Windows Release v1.0.0
=====================================

Run: snack_burger.exe (keep all files in this folder together)

Requirements:
- Windows 10/11 x64
- Visual C++ Redistributable 2015-2022 (usually preinstalled)
- Network access to Supabase
- Thermal printer configured as "Generic / Text Only" (see Admin → Printer Settings)

Package contents:
- snack_burger.exe          Application
- flutter_windows.dll       Flutter engine
- *_plugin.dll              Platform plugins (printer, audio, notifications, etc.)
- pdfium.dll                PDF/printing support
- data\                     Assets, fonts, sounds, app.so

Do not delete or move individual DLLs — the app will not start without them.

Built: flutter build windows --release
