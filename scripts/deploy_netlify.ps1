# بناء محلي ثم رفع مجلد build/web مباشرة إلى Netlify (بدون انتظار build على السحابة)
param(
  [switch]$SkipBuild,
  [switch]$Draft
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

if (-not $SkipBuild) {
  & (Join-Path $Root "scripts\build_web.ps1")
}

$publishDir = Join-Path $Root "build\web"
if (-not (Test-Path (Join-Path $publishDir "index.html"))) {
  throw "Missing build/web/index.html — run build_web.ps1 first"
}

$netlify = Get-Command netlify -ErrorAction SilentlyContinue
if (-not $netlify) {
  Write-Host "Netlify CLI not found. Install:" -ForegroundColor Yellow
  Write-Host "  npm install -g netlify-cli" -ForegroundColor White
  Write-Host "  netlify login" -ForegroundColor White
  Write-Host ""
  Write-Host "Or in Netlify UI: Deploys -> Deploy manually -> drag folder:" -ForegroundColor Yellow
  Write-Host "  $publishDir" -ForegroundColor White
  exit 1
}

$args = @("deploy", "--dir=$publishDir")
if ($Draft) {
  $args += "--draft"
}
else {
  $args += "--prod"
}

Write-Host "==> netlify $($args -join ' ')" -ForegroundColor Cyan
& netlify @args

Write-Host ""
Write-Host "Published from: $publishDir" -ForegroundColor Green
