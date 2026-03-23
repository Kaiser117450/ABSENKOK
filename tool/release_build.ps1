[CmdletBinding()]
param(
    [switch]$CheckOnly,
    [switch]$IncludeSideLoadApk
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$releaseEnv = Join-Path $PSScriptRoot "release_env.ps1"
$releasePreflight = Join-Path $PSScriptRoot "release_preflight.ps1"
$pubspecPath = Join-Path $repoRoot "pubspec.yaml"
$artifactRoot = Join-Path $repoRoot "build\releases\android"
$bundleOutputRoot = Join-Path $repoRoot "build\app\outputs\bundle\release"
$apkOutputRoots = @(
    (Join-Path $repoRoot "build\app\outputs\flutter-apk"),
    (Join-Path $repoRoot "build\app\outputs\apk\release")
)
$mappingSourcePath = Join-Path $repoRoot "build\app\outputs\mapping\release\mapping.txt"
$manifestName = "release-manifest.json"

function Assert-PathExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing $Description at '$Path'."
    }
}

function Get-TrackedReleaseVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $content = Get-Content -LiteralPath $Path -Raw
    $match = [regex]::Match($content, '(?m)^version:\s*(?<name>[0-9A-Za-z\.\-_]+)\+(?<code>\d+)\s*$')
    if (-not $match.Success) {
        throw "Unable to resolve versionName and versionCode from tracked metadata in '$Path'."
    }

    $versionName = $match.Groups["name"].Value
    $versionCode = [int]$match.Groups["code"].Value
    $releaseLabel = "ABSENKOK-v{0}+{1}" -f $versionName, $versionCode

    return [pscustomobject]@{
        VersionName   = $versionName
        VersionCode   = $versionCode
        VersionString = "{0}+{1}" -f $versionName, $versionCode
        ReleaseLabel  = $releaseLabel
    }
}

function Get-GitMetadata {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot
    )

    $revision = $null
    $shortRevision = $null
    $dirty = $false

    $global:LASTEXITCODE = 0
    $revisionOutput = & git -C $RepositoryRoot rev-parse HEAD 2>$null
    if (($null -ne $revisionOutput) -and ($LASTEXITCODE -eq 0)) {
        $revision = ($revisionOutput | Select-Object -First 1).Trim()
    }

    $global:LASTEXITCODE = 0
    $shortOutput = & git -C $RepositoryRoot rev-parse --short HEAD 2>$null
    if (($null -ne $shortOutput) -and ($LASTEXITCODE -eq 0)) {
        $shortRevision = ($shortOutput | Select-Object -First 1).Trim()
    }

    $global:LASTEXITCODE = 0
    & git -C $RepositoryRoot diff --quiet --ignore-submodules HEAD -- 2>$null
    if ($LASTEXITCODE -eq 1) {
        $dirty = $true
    }

    return [ordered]@{
        revision      = $revision
        shortRevision = $shortRevision
        dirty         = $dirty
    }
}

function Get-RelativePathOrOriginal {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ($Path.StartsWith($RepositoryRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return [System.IO.Path]::GetRelativePath($RepositoryRoot, $Path)
    }

    return $Path
}

function New-ReleasePaths {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,
        [Parameter(Mandatory = $true)]
        [string]$ReleaseLabel
    )

    $releaseDirectory = Join-Path $Root $ReleaseLabel
    $symbolsDirectory = Join-Path $releaseDirectory "symbols"
    $bundlePath = Join-Path $releaseDirectory ("{0}.aab" -f $ReleaseLabel)
    $apkPath = Join-Path $releaseDirectory ("{0}.apk" -f $ReleaseLabel)
    $mappingPath = Join-Path $releaseDirectory "mapping.txt"
    $manifestPath = Join-Path $releaseDirectory $manifestName

    return [pscustomobject]@{
        ReleaseDirectory = $releaseDirectory
        SymbolsDirectory = $symbolsDirectory
        BundlePath       = $bundlePath
        ApkPath          = $apkPath
        MappingPath      = $mappingPath
        ManifestPath     = $manifestPath
    }
}

function Clear-GeneratedArtifacts {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Roots,
        [Parameter(Mandatory = $true)]
        [string]$Filter
    )

    foreach ($root in $Roots) {
        if (-not (Test-Path -LiteralPath $root)) {
            continue
        }

        Get-ChildItem -LiteralPath $root -Filter $Filter -File -Recurse -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

function Find-GeneratedArtifact {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Roots,
        [Parameter(Mandatory = $true)]
        [string]$Filter,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    $matches = foreach ($root in $Roots) {
        if (-not (Test-Path -LiteralPath $root)) {
            continue
        }

        Get-ChildItem -LiteralPath $root -Filter $Filter -File -Recurse -ErrorAction SilentlyContinue
    }

    $artifact = $matches | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    if ($null -eq $artifact) {
        throw "Unable to locate the built $Description under: $($Roots -join ', ')"
    }

    return $artifact
}

function New-ArtifactRecord {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,
        [Parameter(Mandatory = $true)]
        [string]$Kind,
        [Parameter(Mandatory = $true)]
        [string]$Purpose,
        [Parameter(Mandatory = $true)]
        [string]$StagedPath,
        [string]$SourcePath = $StagedPath,
        [bool]$Retained = $true
    )

    $hash = Get-FileHash -LiteralPath $StagedPath -Algorithm SHA256
    $item = Get-Item -LiteralPath $StagedPath

    return [ordered]@{
        kind         = $Kind
        purpose      = $Purpose
        sourcePath   = Get-RelativePathOrOriginal -RepositoryRoot $RepositoryRoot -Path $SourcePath
        stagedPath   = Get-RelativePathOrOriginal -RepositoryRoot $RepositoryRoot -Path $StagedPath
        fileName     = [System.IO.Path]::GetFileName($StagedPath)
        sizeBytes    = $item.Length
        sha256       = $hash.Hash
        retained     = $Retained
        generatedUtc = $item.LastWriteTimeUtc.ToString("o")
    }
}

function Get-SymbolArtifactRecords {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,
        [Parameter(Mandatory = $true)]
        [string]$SymbolsDirectory
    )

    if (-not (Test-Path -LiteralPath $SymbolsDirectory)) {
        return @()
    }

    $files = Get-ChildItem -LiteralPath $SymbolsDirectory -File -Recurse -ErrorAction SilentlyContinue |
        Sort-Object FullName

    return @(
        foreach ($file in $files) {
            New-ArtifactRecord `
                -RepositoryRoot $RepositoryRoot `
                -Kind "dart-symbol" `
                -Purpose "split-debug-info" `
                -StagedPath $file.FullName
        }
    )
}

Assert-PathExists -Path $releaseEnv -Description "release environment helper"
Assert-PathExists -Path $releasePreflight -Description "release preflight helper"
Assert-PathExists -Path $pubspecPath -Description "tracked project metadata"

$releaseVersion = Get-TrackedReleaseVersion -Path $pubspecPath
$releasePaths = New-ReleasePaths -Root $artifactRoot -ReleaseLabel $releaseVersion.ReleaseLabel
$apkRetentionState = if ($IncludeSideLoadApk) { "retained" } else { "omitted" }

if ($CheckOnly) {
    $contract = & $releaseEnv -CheckOnly

    Write-Host ""
    Write-Host "ABSENKOK release packaging lane (check only)"
    Write-Host "  Release version : $($releaseVersion.VersionString)"
    Write-Host "  Release label   : $($releaseVersion.ReleaseLabel)"
    Write-Host "  Release dir     : $($releasePaths.ReleaseDirectory)"
    Write-Host "  Canonical .aab  : $($releasePaths.BundlePath)"
    Write-Host "  Symbols dir     : $($releasePaths.SymbolsDirectory) (--split-debug-info, obfuscate disabled)"
    Write-Host "  Mapping target  : $($releasePaths.MappingPath)"
    Write-Host "  APK retention   : $apkRetentionState"
    Write-Host "  Manifest        : $($releasePaths.ManifestPath)"
    Write-Host "  Preflight gate  : $releasePreflight"
    Write-Host "  Real build flow : release_env.ps1 -> release_preflight.ps1 -> flutter build appbundle --release --split-debug-info -> optional flutter build apk --release --split-debug-info -> stage release-manifest.json"

    return [pscustomobject]@{
        Mode               = "check-only"
        ReleaseLabel       = $releaseVersion.ReleaseLabel
        ReleaseDirectory   = $releasePaths.ReleaseDirectory
        CanonicalArtifact  = $releasePaths.BundlePath
        SymbolsDirectory   = $releasePaths.SymbolsDirectory
        MappingTarget      = $releasePaths.MappingPath
        ApkRetentionState  = $apkRetentionState
        ManifestPath       = $releasePaths.ManifestPath
        FlutterCli         = $contract.FlutterCli
        ObfuscationEnabled = $false
    }
}

$contract = & $releaseEnv
$gitMetadata = Get-GitMetadata -RepositoryRoot $repoRoot
$generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")

Write-Host "ABSENKOK release packaging"
Write-Host "  Release version : $($releaseVersion.VersionString)"
Write-Host "  Canonical .aab  : retained"
Write-Host "  Symbols dir     : $($releasePaths.SymbolsDirectory)"
Write-Host "  Mapping target  : $($releasePaths.MappingPath)"
Write-Host "  APK retention   : $apkRetentionState"
Write-Host "  Staging dir     : $($releasePaths.ReleaseDirectory)"

Push-Location $repoRoot
try {
    & $releasePreflight

    Clear-GeneratedArtifacts -Roots @($bundleOutputRoot) -Filter "*.aab"
    if ($IncludeSideLoadApk) {
        Clear-GeneratedArtifacts -Roots $apkOutputRoots -Filter "*.apk"
    }

    if (Test-Path -LiteralPath $releasePaths.ReleaseDirectory) {
        Remove-Item -LiteralPath $releasePaths.ReleaseDirectory -Recurse -Force
    }

    New-Item -ItemType Directory -Path $releasePaths.ReleaseDirectory -Force | Out-Null
    New-Item -ItemType Directory -Path $releasePaths.SymbolsDirectory -Force | Out-Null

    & $contract.FlutterCli @(
        "build",
        "appbundle",
        "--release",
        "--split-debug-info=$($releasePaths.SymbolsDirectory)"
    )
    $bundleSource = Find-GeneratedArtifact -Roots @($bundleOutputRoot) -Filter "*.aab" -Description "release .aab"
    Copy-Item -LiteralPath $bundleSource.FullName -Destination $releasePaths.BundlePath -Force

    $artifacts = @(
        (New-ArtifactRecord `
            -RepositoryRoot $repoRoot `
            -Kind "aab" `
            -Purpose "canonical-release" `
            -SourcePath $bundleSource.FullName `
            -StagedPath $releasePaths.BundlePath)
    )

    if ($IncludeSideLoadApk) {
        & $contract.FlutterCli @(
            "build",
            "apk",
            "--release",
            "--split-debug-info=$($releasePaths.SymbolsDirectory)"
        )
        $apkSource = Find-GeneratedArtifact -Roots $apkOutputRoots -Filter "*.apk" -Description "release .apk"
        Copy-Item -LiteralPath $apkSource.FullName -Destination $releasePaths.ApkPath -Force
        $artifacts += New-ArtifactRecord `
            -RepositoryRoot $repoRoot `
            -Kind "apk" `
            -Purpose "side-load-retained" `
            -SourcePath $apkSource.FullName `
            -StagedPath $releasePaths.ApkPath
    }

    $symbolRecords = Get-SymbolArtifactRecords -RepositoryRoot $repoRoot -SymbolsDirectory $releasePaths.SymbolsDirectory
    if ($symbolRecords.Count -eq 0) {
        throw "No split-debug-info files were generated under '$($releasePaths.SymbolsDirectory)'."
    }

    $mappingRecord = $null
    if (Test-Path -LiteralPath $mappingSourcePath) {
        Copy-Item -LiteralPath $mappingSourcePath -Destination $releasePaths.MappingPath -Force
        $mappingRecord = New-ArtifactRecord `
            -RepositoryRoot $repoRoot `
            -Kind "android-mapping" `
            -Purpose "r8-shrinker-mapping" `
            -SourcePath $mappingSourcePath `
            -StagedPath $releasePaths.MappingPath
    }

    $manifest = [ordered]@{
        releaseLabel       = $releaseVersion.ReleaseLabel
        versionName        = $releaseVersion.VersionName
        versionCode        = $releaseVersion.VersionCode
        generatedAtUtc     = $generatedAtUtc
        releaseDirectory   = [System.IO.Path]::GetRelativePath($repoRoot, $releasePaths.ReleaseDirectory)
        canonicalArtifact  = [System.IO.Path]::GetRelativePath($repoRoot, $releasePaths.BundlePath)
        apkRetentionState  = $apkRetentionState
        supportedApkStates = @("retained", "omitted", "smoke-only")
        git                = $gitMetadata
        artifacts          = $artifacts
        debugArtifacts     = [ordered]@{
            obfuscationEnabled = $false
            splitDebugInfoPath = [System.IO.Path]::GetRelativePath($repoRoot, $releasePaths.SymbolsDirectory)
            symbolFiles        = $symbolRecords
            mappingFile        = $mappingRecord
        }
        notes              = @(
            "Signed .aab is the canonical retained Android release artifact.",
            "Dart symbols are retained with --split-debug-info while obfuscation stays disabled for v7.0.",
            "Signed release .apk is retained only when tool/release_build.ps1 runs with -IncludeSideLoadApk."
        )
    }

    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $releasePaths.ManifestPath -Encoding UTF8

    Write-Host "Release artifacts staged at '$($releasePaths.ReleaseDirectory)'."

    return [pscustomobject]@{
        Mode              = "build"
        ReleaseLabel      = $releaseVersion.ReleaseLabel
        ReleaseDirectory  = $releasePaths.ReleaseDirectory
        CanonicalArtifact = $releasePaths.BundlePath
        SymbolsDirectory  = $releasePaths.SymbolsDirectory
        MappingPath       = $releasePaths.MappingPath
        ApkRetentionState = $apkRetentionState
        ManifestPath      = $releasePaths.ManifestPath
    }
}
finally {
    Pop-Location
}
