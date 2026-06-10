# Post-build steps for GitHub Pages (SPA routing + Jekyll bypass + index.html).
# Windows alternative when Node.js is not installed.
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

$outDir = Join-Path $Root "build\web"
$outIndex = Join-Path $outDir "index.html"
$sourceIndex = Join-Path $Root "web\index.html"
$ghBase = if ($env:GITHUB_PAGES_BASE_HREF) { $env:GITHUB_PAGES_BASE_HREF } else { "/snack-burger/" }

function Resolve-CacheTag {
  if ($env:SNACK_BURGER_CACHE_TAG) {
    return $env:SNACK_BURGER_CACHE_TAG.Trim()
  }
  if ($env:GITHUB_SHA) {
    return $env:GITHUB_SHA.Substring(0, [Math]::Min(7, $env:GITHUB_SHA.Length))
  }
  if ($env:GITHUB_RUN_NUMBER) {
    return "build-$($env:GITHUB_RUN_NUMBER)"
  }
  try {
    $hash = git rev-parse --short HEAD 2>$null
    if ($hash) { return $hash.Trim() }
  } catch {}
  return "local-$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
}

$cacheTag = Resolve-CacheTag

if (-not (Test-Path $outIndex)) {
  Write-Error "Missing build/web/index.html — run flutter build web first."
}

if (Test-Path $sourceIndex) {
  $html = Get-Content -Raw -Path $sourceIndex
  $html = $html -replace '\$FLUTTER_BASE_HREF', $ghBase
  $html = $html -replace '__CACHE_TAG__', $cacheTag
  Set-Content -Path $outIndex -Value $html -NoNewline -Encoding utf8
  Write-Host "GitHub Pages post-build: applied web/index.html (cache tag=$cacheTag)" -ForegroundColor Green
} else {
  Write-Warning "GitHub Pages post-build: missing web/index.html — using Flutter output"
}

$versionJsonPath = Join-Path $outDir "version.json"
if (Test-Path $versionJsonPath) {
  try {
    $versionJson = Get-Content -Raw -Path $versionJsonPath | ConvertFrom-Json
    $versionJson | Add-Member -NotePropertyName deploy_tag -NotePropertyValue $cacheTag -Force
    $versionJson | ConvertTo-Json -Depth 5 | Set-Content -Path $versionJsonPath -Encoding utf8
    Write-Host "GitHub Pages post-build: version.json deploy_tag=$cacheTag" -ForegroundColor Green
  } catch {
    Write-Warning "GitHub Pages post-build: could not patch version.json"
  }
}

Copy-Item -Force $outIndex (Join-Path $outDir "404.html")
Set-Content -Path (Join-Path $outDir ".nojekyll") -Value "" -NoNewline

$outSw = Join-Path $outDir "flutter_service_worker.js"
if (Test-Path $outSw) {
  Remove-Item -Force $outSw
  Write-Host "GitHub Pages post-build: removed flutter_service_worker.js" -ForegroundColor Green
}

Write-Host "GitHub Pages post-build: copied 404.html and wrote .nojekyll" -ForegroundColor Green
