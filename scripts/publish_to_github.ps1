# بناء الويب ثم رفع التغييرات إلى GitHub (الكود المصدري — ليس مجلد build)
param(
  [string]$Message = "chore: update app for web deploy",
  [string]$Branch = "main",
  [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

if (-not $SkipBuild) {
  & (Join-Path $Root "scripts\build_web.ps1")
}

if (-not (git rev-parse --is-inside-work-tree 2>$null)) {
  throw "Not a git repository. Run: git init"
}

$remote = git remote get-url origin 2>$null
if (-not $remote) {
  throw "No git remote 'origin'. Add: git remote add origin https://github.com/USER/REPO.git"
}

Write-Host "==> git status" -ForegroundColor Cyan
git status --short

$changes = git status --porcelain
if (-not $changes) {
  Write-Host "No source changes to commit. Pushing branch $Branch anyway..." -ForegroundColor Yellow
}
else {
  git add -A
  git commit -m $Message
}

Write-Host "==> git push origin $Branch" -ForegroundColor Cyan
git push origin $Branch

Write-Host ""
Write-Host "Pushed to GitHub: $remote ($Branch)" -ForegroundColor Green
Write-Host "If Netlify is linked to this repo, a deploy will start automatically." -ForegroundColor Yellow
Write-Host "Or deploy build/web directly: .\scripts\deploy_netlify.ps1" -ForegroundColor Yellow
