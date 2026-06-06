# Build Flutter web for GitHub Pages (project site: /snack-burger/)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

$baseHref = if ($env:GITHUB_PAGES_BASE_HREF) { $env:GITHUB_PAGES_BASE_HREF } else { "/snack-burger/" }

Write-Host "==> flutter pub get" -ForegroundColor Cyan
flutter pub get

Write-Host "==> flutter build web --release --base-href $baseHref" -ForegroundColor Cyan
flutter build web --release --base-href $baseHref

& (Join-Path $Root "scripts\post_build_gh_pages.ps1")

Write-Host ""
Write-Host "GitHub Pages build complete (base-href=$baseHref)" -ForegroundColor Green
