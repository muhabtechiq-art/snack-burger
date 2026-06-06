# بناء Flutter Web محلياً → build/web (جاهز لـ Netlify)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

Write-Host "==> flutter pub get" -ForegroundColor Cyan
flutter pub get

Write-Host "==> flutter build web --release --base-href /snack-burger/" -ForegroundColor Cyan
flutter build web --release --base-href /snack-burger/ --no-wasm-dry-run --pwa-strategy=none

& (Join-Path $Root "scripts\post_build_gh_pages.ps1")

$redirectsSrc = Join-Path $Root "web\_redirects"
$redirectsDst = Join-Path $Root "build\web\_redirects"
if (Test-Path $redirectsSrc) {
  Copy-Item -Force $redirectsSrc $redirectsDst
  Write-Host "==> Copied _redirects to build/web" -ForegroundColor Green
}

$swDst = Join-Path $Root "build\web\flutter_service_worker.js"
if (Test-Path $swDst) {
  Remove-Item -Force $swDst
  Write-Host "==> Removed flutter_service_worker.js (SW disabled)" -ForegroundColor Green
}
$out = Join-Path $Root "build\web"
Write-Host ""
Write-Host "Build OK: $out" -ForegroundColor Green
Write-Host "Netlify publish directory: build/web" -ForegroundColor Yellow
