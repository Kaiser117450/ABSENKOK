<#
.SYNOPSIS
  Builds the ABSENKOK "beta" APK with all beta features enabled.

.DESCRIPTION
  The Phase-74 beta features (read-only QC role, admin password reset) plus the
  attendance-photo grooming flow all ship behind the SINGLE build-time flag
  `ATTENDANCE_PHOTO_BETA`. This script sets up the environment and runs the
  Flutter build with that flag so the beta features are active in the APK.

  Environment notes (this machine):
    - The Flutter SDK lives under a path WITH SPACES, which breaks the
      objective_c native-assets build hook. `C:\fl` is a directory junction to
      the SDK (space-free), so we invoke `C:\fl\bin\flutter.bat`.
    - JAVA_HOME must point at the Java 21 Android Studio JBR.
    - TEMP/TMP are redirected to C:\tmp (avoids spaced-temp issues).

.PARAMETER Debug
  Build a debug APK instead of a signed release APK (faster, no signing key).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tool\build_beta.ps1
  powershell -ExecutionPolicy Bypass -File tool\build_beta.ps1 -Debug
#>
[CmdletBinding()]
param(
    [switch]$Debug
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

# --- Resolve a SPACE-FREE Flutter CLI -------------------------------------
$flutterCli = $null
foreach ($candidate in @("C:\fl\bin\flutter.bat", "C:\flutter\bin\flutter.bat")) {
    if (Test-Path -LiteralPath $candidate) { $flutterCli = $candidate; break }
}
if (-not $flutterCli) {
    $onPath = Get-Command flutter -ErrorAction SilentlyContinue
    if ($onPath) { $flutterCli = $onPath.Source }
}
if (-not $flutterCli) {
    throw "Flutter CLI not found. Expected C:\fl\bin\flutter.bat (junction to the SDK) or flutter on PATH."
}
if ($flutterCli -match '\s') {
    Write-Warning "Flutter CLI path contains spaces ('$flutterCli'). The native-assets hook may fail. Create a junction: cmd /c mklink /J C:\fl `"<flutter sdk dir>`""
}

# --- JAVA_HOME (Java 21 JBR) ----------------------------------------------
$javaHome = if ([string]::IsNullOrWhiteSpace($env:ABSENKOK_JAVA_HOME)) {
    "C:\Program Files\Android\Android Studio\jbr"
} else {
    $env:ABSENKOK_JAVA_HOME.Trim()
}
if (-not (Test-Path -LiteralPath (Join-Path $javaHome "bin\java.exe"))) {
    throw "Java not found at '$javaHome'. Set ABSENKOK_JAVA_HOME to a Java 21 Android Studio JBR."
}
$env:JAVA_HOME = $javaHome

# --- Spaces-safe temp ------------------------------------------------------
if (-not (Test-Path -LiteralPath "C:\tmp")) {
    New-Item -ItemType Directory -Path "C:\tmp" -Force | Out-Null
}
$env:TEMP = "C:\tmp"
$env:TMP = "C:\tmp"

# --- Build -----------------------------------------------------------------
$mode = if ($Debug) { "--debug" } else { "--release" }
$args = @("build", "apk", $mode, "--dart-define=ATTENDANCE_PHOTO_BETA=true")
if (-not $Debug) {
    # Match the production release contract: obfuscate + retain symbols.
    $args += @("--obfuscate", "--split-debug-info=build\debug-info")
}

Write-Host "ABSENKOK beta build"
Write-Host "  Flutter CLI : $flutterCli"
Write-Host "  JAVA_HOME   : $env:JAVA_HOME"
Write-Host "  Mode        : $mode"
Write-Host "  Beta flag   : ATTENDANCE_PHOTO_BETA=true"
Write-Host "  Command     : $flutterCli $($args -join ' ')"
Write-Host ""

Push-Location $repoRoot
try {
    & $flutterCli @args
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        throw "Flutter build failed with exit code $code."
    }
    Write-Host ""
    Write-Host "Beta APK built. Look under build\app\outputs\flutter-apk\ (ABSENKOK-v<version>.apk)."
}
finally {
    Pop-Location
}
