[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$releaseEnv = Join-Path $PSScriptRoot "release_env.ps1"
$flutterCli = "C:\flutter\bin\flutter.bat"
$gradleWrapper = Join-Path $repoRoot "android\gradlew.bat"
$settingsFile = Join-Path $repoRoot "android\settings.gradle.kts"
$gradleWrapperProperties = Join-Path $repoRoot "android\gradle\wrapper\gradle-wrapper.properties"
$contractDoc = Join-Path $repoRoot "docs\android-release-contract.md"

$expectedFlutterVersion = "3.41.1"
$expectedAgpVersion = "8.11.1"
$expectedGradleVersion = "8.14"
$expectedKotlinVersion = "1.9.25"
$expectedJavaLine = "Java 21 JBR"

if (-not (Test-Path -LiteralPath $releaseEnv)) {
    throw "Missing release environment helper at '$releaseEnv'."
}

if (-not (Test-Path -LiteralPath $gradleWrapper)) {
    throw "Missing Gradle wrapper at '$gradleWrapper'."
}

function Assert-FileContains {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Pattern,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing $Description file at '$Path'."
    }

    $content = Get-Content -LiteralPath $Path -Raw
    if ($content -notmatch [regex]::Escape($Pattern)) {
        throw "Tracked contract drift detected: expected $Description to include '$Pattern'. Update docs and release tooling intentionally before using the v7.0 lane."
    }
}

& $releaseEnv | Out-Null

Assert-FileContains -Path $settingsFile -Pattern ("id(""com.android.application"") version ""{0}""" -f $expectedAgpVersion) -Description "AGP pin"
Assert-FileContains -Path $settingsFile -Pattern ("id(""org.jetbrains.kotlin.android"") version ""{0}""" -f $expectedKotlinVersion) -Description "Kotlin pin"
Assert-FileContains -Path $gradleWrapperProperties -Pattern ("gradle-{0}-all.zip" -f $expectedGradleVersion) -Description "Gradle wrapper pin"
Assert-FileContains -Path $contractDoc -Pattern ("Flutter {0}" -f $expectedFlutterVersion) -Description "release contract doc"
Assert-FileContains -Path $contractDoc -Pattern ("AGP {0}" -f $expectedAgpVersion) -Description "release contract doc"
Assert-FileContains -Path $contractDoc -Pattern ("Gradle {0}" -f $expectedGradleVersion) -Description "release contract doc"
Assert-FileContains -Path $contractDoc -Pattern ("Kotlin {0}" -f $expectedKotlinVersion) -Description "release contract doc"
Assert-FileContains -Path $contractDoc -Pattern $expectedJavaLine -Description "release contract doc"

function Invoke-PreflightStage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Command
    )

    Write-Host ""
    Write-Host "==> $Name"
    $global:LASTEXITCODE = 0
    & $Command
    $exitCode = if ($null -eq $global:LASTEXITCODE) { 0 } else { [int]$global:LASTEXITCODE }
    if ($exitCode -ne 0) {
        Write-Host "Preflight stopped at '$Name' with exit code $exitCode."
        exit $exitCode
    }
}

Write-Host "ABSENKOK release preflight"
Write-Host "Stages: flutter analyze -> flutter test -> android\\gradlew.bat :app:compileReleaseSources"
Write-Host "Contract: Flutter $expectedFlutterVersion / AGP $expectedAgpVersion / Gradle $expectedGradleVersion / Kotlin $expectedKotlinVersion / $expectedJavaLine"
Write-Host "Packaging and signing tasks are intentionally excluded from this lane."

Push-Location $repoRoot
try {
    Invoke-PreflightStage -Name "Flutter analyze" -Command {
        & $flutterCli analyze
    }

    Invoke-PreflightStage -Name "Flutter test" -Command {
        & $flutterCli test
    }

    Invoke-PreflightStage -Name "Release-only compile" -Command {
        & $gradleWrapper ":app:compileReleaseSources"
    }
}
finally {
    Pop-Location
}
