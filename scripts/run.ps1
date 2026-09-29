<#
Date : 29/09/2026
Auteurs : Elpidio Alexis AMOUSSOU
          Eli Yannick HOVI
Emails : amoussouelpidioalexis@gmail.com
         yannickeli2007@gmail.com
But : Script PowerShell d'exécution de l'application Flutter en chargeant dynamiquement les variables du fichier .env via --dart-define.
#>

# Lance l'app avec les variables de .env (fichier non commité).
# Usage:
#   .\scripts\run.ps1                    # chrome
#   .\scripts\run.ps1 -device android    # émulateur / appareil Android

param(
  [string]$device = "chrome"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

$envFile = Join-Path $root ".env"
if (-not (Test-Path $envFile)) {
  Write-Error "Fichier .env manquant. Copiez .env.example vers .env."
}

$defines = @()
Get-Content $envFile | ForEach-Object {
  $line = $_.Trim()
  if ($line -eq "" -or $line.StartsWith("#")) { return }
  $parts = $line.Split("=", 2)
  if ($parts.Length -eq 2) {
    $key = $parts[0].Trim()
    $val = $parts[1].Trim()
    # Map NEXT_PUBLIC_* → noms Flutter
    if ($key -eq "NEXT_PUBLIC_SUPABASE_URL") { $key = "SUPABASE_URL" }
    if ($key -eq "NEXT_PUBLIC_SUPABASE_ANON_KEY") { $key = "SUPABASE_ANON_KEY" }
    $defines += "--dart-define=$key=$val"
  }
}

$env:Path = "$env:USERPROFILE\flutter\bin;$env:Path"
$extra = @()
if ($device -in @("chrome", "web-server", "edge")) {
  # Port fixe : à ajouter dans Supabase → Redirect URLs
  $extra += "--web-port=5555"
  if ($device -eq "chrome") {
    $extra += '--web-browser-flag=--disable-web-security'
  }
}
Write-Host "flutter run -d $device $($defines -join ' ') $($extra -join ' ')" -ForegroundColor Cyan
flutter run -d $device @defines @extra
