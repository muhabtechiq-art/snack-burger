# Post-build steps for GitHub Pages (SPA routing + Jekyll bypass + index.html).
# Windows alternative when Node.js is not installed.
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

$outDir = Join-Path $Root "build\web"
$outIndex = Join-Path $outDir "index.html"
$sourceIndex = Join-Path $Root "web\index.html"
$ghBase = if ($env:GITHUB_PAGES_BASE_HREF) { $env:GITHUB_PAGES_BASE_HREF } else { "/snack-burger/" }

if (-not (Test-Path $outIndex)) {
  Write-Error "Missing build/web/index.html — run flutter build web first."
}

if (Test-Path $sourceIndex) {
  $html = Get-Content -Raw -Path $sourceIndex
  $html = $html -replace '\$FLUTTER_BASE_HREF', $ghBase
  Set-Content -Path $outIndex -Value $html -NoNewline -Encoding utf8
  Write-Host "GitHub Pages post-build: applied web/index.html" -ForegroundColor Green
} else {
  Write-Warning "GitHub Pages post-build: missing web/index.html — using Flutter output"
}

Copy-Item -Force $outIndex (Join-Path $outDir "404.html")
Set-Content -Path (Join-Path $outDir ".nojekyll") -Value "" -NoNewline

$outSw = Join-Path $outDir "flutter_service_worker.js"
if (Test-Path $outSw) {
  Remove-Item -Force $outSw
  Write-Host "GitHub Pages post-build: removed flutter_service_worker.js" -ForegroundColor Green
}

Write-Host "GitHub Pages post-build: copied 404.html and wrote .nojekyll" -ForegroundColor Green
