# KODE/API CLI - web installer (Windows)
# Usage:  irm https://cli.kodeapi.com/install.ps1 | iex
#
# Env overrides:
#   $env:KODEAPI_VERSION  - install a specific version (e.g. 1.0.0). Default: latest
#   $env:KODEAPI_INSTALL  - install dir. Default: %LOCALAPPDATA%\Programs\KodeAPI

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Change this if your GitHub repo slug differs.
$Repo       = "kode-api/cli"
$AppName    = "kodeapi"
$InstallDir = if ($env:KODEAPI_INSTALL) { $env:KODEAPI_INSTALL } else { Join-Path $env:LOCALAPPDATA "Programs\KodeAPI" }

function Info($m) { Write-Host "  $m" -ForegroundColor Gray }
function Ok($m)   { Write-Host "  $m" -ForegroundColor Green }
function Die($m)  { Write-Host "  ERROR: $m" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "  KODE/API CLI installer" -ForegroundColor Cyan
Write-Host "  ----------------------" -ForegroundColor DarkGray

# Detect architecture
$arch = switch ($env:PROCESSOR_ARCHITECTURE) {
  "ARM64" { "arm64" }
  default { "x64" }
}

# Detect AVX2 (x64 only) to pick the baseline build when needed
$target = "windows-$arch"
if ($arch -eq "x64") {
  $avx2 = $false
  try {
    $sig = '[DllImport("kernel32.dll")] public static extern bool IsProcessorFeaturePresent(int f);'
    $k = Add-Type -MemberDefinition $sig -Name "K32" -Namespace "W" -PassThru
    $avx2 = $k::IsProcessorFeaturePresent(40)  # PF_AVX2_INSTRUCTIONS_AVAILABLE
  } catch { $avx2 = $false }
  if (-not $avx2) { $target = "windows-x64-baseline" }
}

# Resolve version (latest if not pinned)
$version = $env:KODEAPI_VERSION
if (-not $version) {
  Info "Resolving latest release..."
  try {
    $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers @{ "User-Agent" = "kodeapi-installer" }
    $version = $rel.tag_name
  } catch {
    Die "Could not resolve latest release. Set `$env:KODEAPI_VERSION and retry."
  }
}
$version = $version.TrimStart("v")
Info "Version: $version"
Info "Target:  $target"

$asset = "kodeapi-$target.zip"
$url   = "https://github.com/$Repo/releases/download/v$version/$asset"

# Download
$tmp = Join-Path ([IO.Path]::GetTempPath()) "kodeapi-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$zip = Join-Path $tmp $asset
Info "Downloading $asset ..."
try {
  Invoke-WebRequest -Uri $url -OutFile $zip -Headers @{ "User-Agent" = "kodeapi-installer" }
} catch {
  Die "Download failed: $url"
}

# Stop running instance so files aren't locked
Get-Process -Name $AppName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 300

# Fresh install dir
if (Test-Path -LiteralPath $InstallDir) { Remove-Item -LiteralPath $InstallDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

Info "Extracting to: $InstallDir"
Expand-Archive -LiteralPath $zip -DestinationPath $InstallDir -Force
Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue

# Flatten if archive nested everything under a top folder
if (-not (Test-Path (Join-Path $InstallDir "kodeapi.exe"))) {
  $exe = Get-ChildItem -LiteralPath $InstallDir -Recurse -Filter "kodeapi.exe" | Select-Object -First 1
  if ($exe) {
    Get-ChildItem -LiteralPath (Split-Path -Parent $exe.FullName) -Force | Move-Item -Destination $InstallDir -Force
  } else {
    Die "kodeapi.exe not found in downloaded archive."
  }
}

# Add to USER Path (idempotent)
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (-not $userPath) { $userPath = "" }
$parts = $userPath.Split(";") | Where-Object { $_ -ne "" }
if ($parts -notcontains $InstallDir) {
  [Environment]::SetEnvironmentVariable("Path", ((@($parts) + $InstallDir) -join ";"), "User")
  Info "Added to PATH (user)."
}
if (($env:Path -split ";") -notcontains $InstallDir) { $env:Path = "$env:Path;$InstallDir" }

$installed = & (Join-Path $InstallDir "kodeapi.exe") --version 2>$null
Write-Host ""
Ok "Installed kodeapi $installed"
Write-Host ""
Write-Host "  Open a NEW terminal and run:" -ForegroundColor White
Write-Host "      kodeapi --version" -ForegroundColor Yellow
Write-Host ""
