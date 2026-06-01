# اختصار: بناء الويب + push إلى GitHub
param(
  [string]$Message = "chore: web build and publish",
  [string]$Branch = "main"
)

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
& (Join-Path $Root "scripts\publish_to_github.ps1") -Message $Message -Branch $Branch
