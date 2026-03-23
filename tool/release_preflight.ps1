[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$releaseEnv = Join-Path $PSScriptRoot "release_env.ps1"
$flutterCli = "C:\flutter\bin\flutter.bat"
$gradleWrapper = Join-Path $repoRoot "android\gradlew.bat"

if (-not (Test-Path -LiteralPath $releaseEnv)) {
    throw "Missing release environment helper at '$releaseEnv'."
}

if (-not (Test-Path -LiteralPath $gradleWrapper)) {
    throw "Missing Gradle wrapper at '$gradleWrapper'."
}

& $releaseEnv | Out-Null

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
