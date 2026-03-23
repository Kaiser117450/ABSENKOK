[CmdletBinding()]
param(
    [switch]$CheckOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$defaultJavaHome = "C:\Program Files\Android\Android Studio\jbr"
$flutterCli = "C:\flutter\bin\flutter.bat"
$resolvedJavaHome = if ([string]::IsNullOrWhiteSpace($env:ABSENKOK_JAVA_HOME)) {
    $defaultJavaHome
} else {
    $env:ABSENKOK_JAVA_HOME.Trim()
}

if (-not (Test-Path -LiteralPath $resolvedJavaHome)) {
    throw "Java runtime not found at '$resolvedJavaHome'. Set ABSENKOK_JAVA_HOME to a Java 21 Android Studio JBR install."
}

$javaExe = Join-Path $resolvedJavaHome "bin\java.exe"
if (-not (Test-Path -LiteralPath $javaExe)) {
    throw "Resolved JAVA_HOME '$resolvedJavaHome' does not contain bin\\java.exe."
}

$javaVersionOutput = (cmd.exe /d /c ('"{0}" -version 2>&1' -f $javaExe) | Out-String).Trim()
if ($javaVersionOutput -notmatch 'version "(?<major>\d+)') {
    throw "Unable to determine Java version from '$javaExe'. Output:`n$javaVersionOutput"
}

$javaMajor = [int]$Matches["major"]
if ($javaMajor -ne 21) {
    throw "Unsupported Java runtime detected at '$resolvedJavaHome'. Expected Java 21 JBR but found:$([Environment]::NewLine)$javaVersionOutput"
}

if (-not (Test-Path -LiteralPath $flutterCli)) {
    throw "Canonical Flutter CLI missing at '$flutterCli'. Install Flutter 3.41.1 to C:\flutter before running release commands."
}

$env:JAVA_HOME = $resolvedJavaHome
$javaBin = Join-Path $resolvedJavaHome "bin"
$pathSegments = @($env:Path -split ";")
if ($pathSegments -notcontains $javaBin) {
    $env:Path = "$javaBin;$env:Path"
}

$contract = [pscustomobject]@{
    JavaHome       = $env:JAVA_HOME
    JavaVersion    = ($javaVersionOutput -split [Environment]::NewLine)[0]
    FlutterCli     = $flutterCli
    FlutterVersion = "3.41.1"
    AgpVersion     = "8.11.1"
    GradleVersion  = "8.14"
    KotlinVersion  = "1.9.25"
    Notes          = "android/local.properties is machine-local evidence; tracked contract lives in docs/android-release-contract.md"
}

if ($CheckOnly) {
    Write-Host "ABSENKOK Android release contract"
    Write-Host "  JAVA_HOME      : $($contract.JavaHome)"
    Write-Host "  Java runtime   : $($contract.JavaVersion)"
    Write-Host "  Flutter CLI    : $($contract.FlutterCli)"
    Write-Host "  Flutter / AGP  : $($contract.FlutterVersion) / $($contract.AgpVersion)"
    Write-Host "  Gradle / Kotlin: $($contract.GradleVersion) / $($contract.KotlinVersion)"
    Write-Host "  Contract doc   : docs/android-release-contract.md"
}

return $contract
