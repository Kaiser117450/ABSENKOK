[CmdletBinding()]
param(
    [switch]$CheckOnly,
    [Alias("IncludeSideLoadApk")]
    [switch]$IncludeAppBundle,
    [switch]$SmokeVerify
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$releaseEnv = Join-Path $PSScriptRoot "release_env.ps1"
$releasePreflight = Join-Path $PSScriptRoot "release_preflight.ps1"
$pubspecPath = Join-Path $repoRoot "pubspec.yaml"
$buildGradlePath = Join-Path $repoRoot "android\app\build.gradle.kts"
$localPropertiesPath = Join-Path $repoRoot "android\local.properties"
$artifactRoot = Join-Path $repoRoot "build\releases\android"
$bundleOutputRoot = Join-Path $repoRoot "build\app\outputs\bundle\release"
$apkOutputRoots = @(
    (Join-Path $repoRoot "build\app\outputs\flutter-apk"),
    (Join-Path $repoRoot "build\app\outputs\apk\release")
)
$mappingSourcePath = Join-Path $repoRoot "build\app\outputs\mapping\release\mapping.txt"
$manifestName = "release-manifest.json"
$smokeEvidenceName = "smoke-check.txt"

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
        $basePath = [System.IO.Path]::GetFullPath($RepositoryRoot)
        if (-not $basePath.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
            $basePath += [System.IO.Path]::DirectorySeparatorChar
        }

        $targetPath = [System.IO.Path]::GetFullPath($Path)
        $baseUri = [System.Uri]$basePath
        $targetUri = [System.Uri]$targetPath
        $relativeUri = $baseUri.MakeRelativeUri($targetUri)
        $relativePath = [System.Uri]::UnescapeDataString($relativeUri.ToString()) -replace '/', '\'

        if (-not [string]::IsNullOrWhiteSpace($relativePath)) {
            return $relativePath
        }
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
    $smokeEvidencePath = Join-Path $releaseDirectory $smokeEvidenceName

    return [pscustomobject]@{
        ReleaseDirectory  = $releaseDirectory
        SymbolsDirectory  = $symbolsDirectory
        BundlePath        = $bundlePath
        ApkPath           = $apkPath
        MappingPath       = $mappingPath
        ManifestPath      = $manifestPath
        SmokeEvidencePath = $smokeEvidencePath
    }
}

function Get-LocalPropertyValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $content = Get-Content -LiteralPath $Path -Raw
    $match = [regex]::Match(
        $content,
        '(?m)^\s*' + [regex]::Escape($Key) + '\s*=\s*(?<value>.+?)\s*$'
    )

    if (-not $match.Success) {
        return $null
    }

    return ($match.Groups["value"].Value.Trim() -replace '\\\\', '\')
}

function Resolve-AdbCli {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,
        [Parameter(Mandatory = $true)]
        [string]$LocalPropertiesPath
    )

    $candidates = @()

    $command = Get-Command adb.exe -ErrorAction SilentlyContinue
    if (-not $command) {
        $command = Get-Command adb -ErrorAction SilentlyContinue
    }
    if ($command) {
        $candidates += $command.Path
    }

    $sdkRoots = @(
        $env:ANDROID_HOME,
        $env:ANDROID_SDK_ROOT,
        (Get-LocalPropertyValue -Path $LocalPropertiesPath -Key "sdk.dir")
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $sdkRoots += Join-Path $env:LOCALAPPDATA "Android\Sdk"
    }

    foreach ($sdkRoot in ($sdkRoots | Select-Object -Unique)) {
        $candidates += Join-Path $sdkRoot "platform-tools\adb.exe"
    }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    throw "Smoke verification requires adb.exe. Add Android platform-tools to PATH, set ANDROID_HOME/ANDROID_SDK_ROOT, or keep android/local.properties sdk.dir available."
}

function Get-AndroidApplicationId {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    Assert-PathExists -Path $Path -Description "Android app build config"

    $content = Get-Content -LiteralPath $Path -Raw
    $match = [regex]::Match($content, '(?m)^\s*applicationId\s*=\s*"(?<id>[^"]+)"')
    if (-not $match.Success) {
        throw "Unable to resolve Android applicationId from '$Path'."
    }

    return $match.Groups["id"].Value
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

function Format-CommandLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [string[]]$Arguments = @()
    )

    if ($Arguments.Count -eq 0) {
        return '"{0}"' -f $FilePath
    }

    $formattedArguments = foreach ($argument in $Arguments) {
        if ($argument -match '\s') {
            '"{0}"' -f $argument
        } else {
            $argument
        }
    }

    return '"{0}" {1}' -f $FilePath, ($formattedArguments -join ' ')
}

function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [string[]]$Arguments = @(),
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    $global:LASTEXITCODE = 0
    $output = & $FilePath @Arguments 2>&1 | Out-String
    $exitCode = if ($null -eq $global:LASTEXITCODE) { 0 } else { [int]$global:LASTEXITCODE }

    return [ordered]@{
        description = $Description
        command     = Format-CommandLine -FilePath $FilePath -Arguments $Arguments
        exitCode    = $exitCode
        output      = $output.TrimEnd()
    }
}

function Get-ConnectedAndroidTargets {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AdbCli
    )

    $deviceList = Invoke-ExternalCommand -FilePath $AdbCli -Arguments @("devices") -Description "adb devices"
    $targets = @()

    foreach ($line in ($deviceList.output -split "`r?`n")) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed -eq "List of devices attached") {
            continue
        }

        $parts = $trimmed -split '\s+'
        if ($parts.Count -lt 2) {
            continue
        }

        $targets += [pscustomobject]@{
            Serial = $parts[0]
            State  = $parts[1]
        }
    }

    return [pscustomobject]@{
        Command = $deviceList
        Targets = @($targets | Where-Object { $_.State -eq "device" })
    }
}

function Write-SmokeEvidence {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [hashtable]$SmokeRecord
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("ABSENKOK smoke verification")
    $lines.Add(("Checked at (UTC): {0}" -f $SmokeRecord.checkedAtUtc))
    $lines.Add(("Status: {0}" -f $SmokeRecord.status))
    $lines.Add(("Version: {0}" -f $SmokeRecord.version))
    $lines.Add(("Application ID: {0}" -f $SmokeRecord.applicationId))
    $lines.Add(("Device serial: {0}" -f ($(if ($SmokeRecord.deviceSerial) { $SmokeRecord.deviceSerial } else { "<none>" }))))
    $lines.Add(("ADB: {0}" -f $SmokeRecord.adbPath))
    $lines.Add(("APK source: {0}" -f $SmokeRecord.apkInstallSource))
    $lines.Add(("Evidence file: {0}" -f $SmokeRecord.evidencePath))

    if ($SmokeRecord.error) {
        $lines.Add(("Error: {0}" -f $SmokeRecord.error))
    }

    foreach ($command in $SmokeRecord.commands) {
        $lines.Add("")
        $lines.Add(("Command: {0}" -f $command.command))
        $lines.Add(("Exit code: {0}" -f $command.exitCode))
        $lines.Add("Output:")
        if ([string]::IsNullOrWhiteSpace($command.output)) {
            $lines.Add("<no output>")
        } else {
            foreach ($line in ($command.output -split "`r?`n")) {
                $lines.Add($line)
            }
        }
    }

    Set-Content -LiteralPath $Path -Value $lines -Encoding UTF8
}

function Invoke-SmokeVerification {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,
        [Parameter(Mandatory = $true)]
        [string]$AdbCli,
        [Parameter(Mandatory = $true)]
        [string]$ApplicationId,
        [Parameter(Mandatory = $true)]
        [string]$ApkPath,
        [Parameter(Mandatory = $true)]
        [string]$EvidencePath,
        [Parameter(Mandatory = $true)]
        [string]$VersionString
    )

    $record = [ordered]@{
        requested        = $true
        status           = "pending"
        checkedAtUtc     = (Get-Date).ToUniversalTime().ToString("o")
        version          = $VersionString
        applicationId    = $ApplicationId
        adbPath          = Get-RelativePathOrOriginal -RepositoryRoot $RepositoryRoot -Path $AdbCli
        apkInstallSource = Get-RelativePathOrOriginal -RepositoryRoot $RepositoryRoot -Path $ApkPath
        evidencePath     = Get-RelativePathOrOriginal -RepositoryRoot $RepositoryRoot -Path $EvidencePath
        deviceSerial     = $null
        commands         = @()
        error            = $null
    }

    if (-not (Test-Path -LiteralPath $ApkPath)) {
        $record.status = "failed-missing-apk"
        $record.error = "Smoke verification expected a signed release APK at '$ApkPath', but it was not found."
        Write-SmokeEvidence -Path $EvidencePath -SmokeRecord $record
        return $record
    }

    $deviceSnapshot = Get-ConnectedAndroidTargets -AdbCli $AdbCli
    $record.commands += $deviceSnapshot.Command

    if ($deviceSnapshot.Targets.Count -eq 0) {
        $record.status = "failed-no-device"
        $record.error = "Smoke verification requires an attached Android device or emulator visible to adb devices."
        Write-SmokeEvidence -Path $EvidencePath -SmokeRecord $record
        return $record
    }

    $target = $deviceSnapshot.Targets | Select-Object -First 1
    $record.deviceSerial = $target.Serial

    $installResult = Invoke-ExternalCommand `
        -FilePath $AdbCli `
        -Arguments @("-s", $target.Serial, "install", "-r", $ApkPath) `
        -Description "adb install -r"
    $record.commands += $installResult

    if ($installResult.exitCode -ne 0) {
        $record.status = "failed-install"
        $record.error = "Smoke verification failed while installing the signed release APK on device '$($target.Serial)'."
        Write-SmokeEvidence -Path $EvidencePath -SmokeRecord $record
        return $record
    }

    $launchResult = Invoke-ExternalCommand `
        -FilePath $AdbCli `
        -Arguments @(
            "-s",
            $target.Serial,
            "shell",
            "monkey",
            "-p",
            $ApplicationId,
            "-c",
            "android.intent.category.LAUNCHER",
            "1"
        ) `
        -Description "adb shell monkey launch"
    $record.commands += $launchResult

    if ($launchResult.exitCode -ne 0) {
        $record.status = "failed-launch"
        $record.error = "Smoke verification failed while launching '$ApplicationId' on device '$($target.Serial)'."
        Write-SmokeEvidence -Path $EvidencePath -SmokeRecord $record
        return $record
    }

    $record.status = "passed"
    Write-SmokeEvidence -Path $EvidencePath -SmokeRecord $record
    return $record
}

Assert-PathExists -Path $releaseEnv -Description "release environment helper"
Assert-PathExists -Path $releasePreflight -Description "release preflight helper"
Assert-PathExists -Path $pubspecPath -Description "tracked project metadata"
Assert-PathExists -Path $buildGradlePath -Description "Android app build config"

$releaseVersion = Get-TrackedReleaseVersion -Path $pubspecPath
$releasePaths = New-ReleasePaths -Root $artifactRoot -ReleaseLabel $releaseVersion.ReleaseLabel
$shouldBuildBundle = [bool]$IncludeAppBundle
$bundleRetentionState = if ($IncludeAppBundle) {
    "retained"
} else {
    "omitted"
}
$applicationId = if ($SmokeVerify) {
    Get-AndroidApplicationId -Path $buildGradlePath
} else {
    $null
}

if ($CheckOnly) {
    $contract = & $releaseEnv -CheckOnly
    $adbCli = if ($SmokeVerify) {
        Resolve-AdbCli -RepositoryRoot $repoRoot -LocalPropertiesPath $localPropertiesPath
    } else {
        $null
    }

    Write-Host ""
    Write-Host "ABSENKOK release packaging lane (check only)"
    Write-Host "  Release version : $($releaseVersion.VersionString)"
    Write-Host "  Release label   : $($releaseVersion.ReleaseLabel)"
    Write-Host "  Release dir     : $($releasePaths.ReleaseDirectory)"
    Write-Host "  Canonical .apk  : $($releasePaths.ApkPath)"
    Write-Host "  Bundle target   : $($releasePaths.BundlePath)"
    Write-Host "  Symbols dir     : $($releasePaths.SymbolsDirectory) (--split-debug-info, obfuscate disabled)"
    Write-Host "  Mapping target  : $($releasePaths.MappingPath)"
    Write-Host "  Bundle retention: $bundleRetentionState"
    Write-Host "  Manifest        : $($releasePaths.ManifestPath)"
    Write-Host "  Preflight gate  : $releasePreflight"
    if ($SmokeVerify) {
        Write-Host "  Smoke verify   : enabled"
        Write-Host "  ADB            : $adbCli"
        Write-Host "  App package    : $applicationId"
        Write-Host "  Smoke APK      : $($releasePaths.ApkPath)"
        Write-Host "  Smoke evidence : $($releasePaths.SmokeEvidencePath)"
    } else {
        Write-Host "  Smoke verify   : not requested"
    }
    Write-Host "  Real build flow : release_env.ps1 -> release_preflight.ps1 -> flutter build apk --release --split-debug-info -> optional flutter build appbundle --release --split-debug-info -> optional adb smoke verification -> stage release-manifest.json"

    $response = [ordered]@{
        Mode               = "check-only"
        ReleaseLabel       = $releaseVersion.ReleaseLabel
        ReleaseDirectory   = $releasePaths.ReleaseDirectory
        CanonicalArtifact  = $releasePaths.ApkPath
        BundleArtifactPath = $releasePaths.BundlePath
        SymbolsDirectory   = $releasePaths.SymbolsDirectory
        MappingTarget      = $releasePaths.MappingPath
        BundleRetentionState = $bundleRetentionState
        ManifestPath       = $releasePaths.ManifestPath
        SmokeEvidencePath  = $releasePaths.SmokeEvidencePath
        FlutterCli         = $contract.FlutterCli
        ObfuscationEnabled = $false
    }

    if ($SmokeVerify) {
        $response["SmokeVerify"] = [ordered]@{
            AdbCli         = $adbCli
            ApplicationId  = $applicationId
            SmokeApkPath   = $releasePaths.ApkPath
            EvidencePath   = $releasePaths.SmokeEvidencePath
            BundleRetention = $bundleRetentionState
        }
    }

    return [pscustomobject]$response
}

$contract = & $releaseEnv
$gitMetadata = Get-GitMetadata -RepositoryRoot $repoRoot
$generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
$adbCli = if ($SmokeVerify) {
    Resolve-AdbCli -RepositoryRoot $repoRoot -LocalPropertiesPath $localPropertiesPath
} else {
    $null
}

Write-Host "ABSENKOK release packaging"
Write-Host "  Release version : $($releaseVersion.VersionString)"
Write-Host "  Canonical .apk  : retained"
Write-Host "  Bundle output   : $bundleRetentionState"
Write-Host "  Symbols dir     : $($releasePaths.SymbolsDirectory)"
Write-Host "  Mapping target  : $($releasePaths.MappingPath)"
Write-Host "  Smoke verify    : $SmokeVerify"
Write-Host "  Staging dir     : $($releasePaths.ReleaseDirectory)"

Push-Location $repoRoot
try {
    & $releasePreflight

    Clear-GeneratedArtifacts -Roots $apkOutputRoots -Filter "*.apk"
    if ($shouldBuildBundle) {
        Clear-GeneratedArtifacts -Roots @($bundleOutputRoot) -Filter "*.aab"
    }

    if (Test-Path -LiteralPath $releasePaths.ReleaseDirectory) {
        Remove-Item -LiteralPath $releasePaths.ReleaseDirectory -Recurse -Force
    }

    New-Item -ItemType Directory -Path $releasePaths.ReleaseDirectory -Force | Out-Null
    New-Item -ItemType Directory -Path $releasePaths.SymbolsDirectory -Force | Out-Null

    & $contract.FlutterCli @(
        "build",
        "apk",
        "--release",
        "--split-debug-info=$($releasePaths.SymbolsDirectory)"
    )
    $apkSource = Find-GeneratedArtifact -Roots $apkOutputRoots -Filter "*.apk" -Description "release .apk"
    Copy-Item -LiteralPath $apkSource.FullName -Destination $releasePaths.ApkPath -Force

    $artifacts = @(
        (New-ArtifactRecord `
            -RepositoryRoot $repoRoot `
            -Kind "apk" `
            -Purpose "canonical-release" `
            -SourcePath $apkSource.FullName `
            -StagedPath $releasePaths.ApkPath)
    )

    if ($shouldBuildBundle) {
        & $contract.FlutterCli @(
            "build",
            "appbundle",
            "--release",
            "--split-debug-info=$($releasePaths.SymbolsDirectory)"
        )
        $bundleSource = Find-GeneratedArtifact -Roots @($bundleOutputRoot) -Filter "*.aab" -Description "release .aab"
        Copy-Item -LiteralPath $bundleSource.FullName -Destination $releasePaths.BundlePath -Force
        $artifacts += New-ArtifactRecord `
            -RepositoryRoot $repoRoot `
            -Kind "aab" `
            -Purpose "supplementary-bundle" `
            -SourcePath $bundleSource.FullName `
            -StagedPath $releasePaths.BundlePath
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

    $smokeVerification = [ordered]@{
        requested        = [bool]$SmokeVerify
        status           = if ($SmokeVerify) { "pending" } else { "not-requested" }
        checkedAtUtc     = $null
        version          = $releaseVersion.VersionString
        applicationId    = $applicationId
        adbPath          = if ($adbCli) { Get-RelativePathOrOriginal -RepositoryRoot $repoRoot -Path $adbCli } else { $null }
        apkInstallSource = Get-RelativePathOrOriginal -RepositoryRoot $repoRoot -Path $releasePaths.ApkPath
        evidencePath     = Get-RelativePathOrOriginal -RepositoryRoot $repoRoot -Path $releasePaths.SmokeEvidencePath
        deviceSerial     = $null
        commands         = @()
        error            = $null
    }

    if ($SmokeVerify) {
        $smokeVerification = Invoke-SmokeVerification `
            -RepositoryRoot $repoRoot `
            -AdbCli $adbCli `
            -ApplicationId $applicationId `
            -ApkPath $releasePaths.ApkPath `
            -EvidencePath $releasePaths.SmokeEvidencePath `
            -VersionString $releaseVersion.VersionString
    }

    $notes = @(
        "Signed .apk is the canonical retained Android release artifact.",
        "Dart symbols are retained with --split-debug-info while obfuscation stays disabled for v7.0.",
        "Signed .aab is retained only when tool/release_build.ps1 runs with -IncludeAppBundle."
    )
    if ($SmokeVerify) {
        $notes += "Smoke verification records install and launch evidence in smoke-check.txt before distribution."
    }

    $manifest = [ordered]@{
        releaseLabel       = $releaseVersion.ReleaseLabel
        versionName        = $releaseVersion.VersionName
        versionCode        = $releaseVersion.VersionCode
        generatedAtUtc     = $generatedAtUtc
        releaseDirectory   = Get-RelativePathOrOriginal -RepositoryRoot $repoRoot -Path $releasePaths.ReleaseDirectory
        canonicalArtifact  = Get-RelativePathOrOriginal -RepositoryRoot $repoRoot -Path $releasePaths.ApkPath
        bundleRetentionState = $bundleRetentionState
        supportedBundleStates = @("retained", "omitted")
        git                = $gitMetadata
        artifacts          = $artifacts
        debugArtifacts     = [ordered]@{
            obfuscationEnabled = $false
            splitDebugInfoPath = Get-RelativePathOrOriginal -RepositoryRoot $repoRoot -Path $releasePaths.SymbolsDirectory
            symbolFiles        = $symbolRecords
            mappingFile        = $mappingRecord
        }
        smokeVerification  = $smokeVerification
        notes              = $notes
    }

    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $releasePaths.ManifestPath -Encoding UTF8

    if ($SmokeVerify -and $smokeVerification.error) {
        throw $smokeVerification.error
    }

    Write-Host "Release artifacts staged at '$($releasePaths.ReleaseDirectory)'."

    return [pscustomobject]@{
        Mode              = "build"
        ReleaseLabel      = $releaseVersion.ReleaseLabel
        ReleaseDirectory  = $releasePaths.ReleaseDirectory
        CanonicalArtifact = $releasePaths.ApkPath
        SymbolsDirectory  = $releasePaths.SymbolsDirectory
        MappingPath       = $releasePaths.MappingPath
        BundleRetentionState = $bundleRetentionState
        ManifestPath      = $releasePaths.ManifestPath
        SmokeEvidencePath = if ($SmokeVerify) { $releasePaths.SmokeEvidencePath } else { $null }
    }
}
finally {
    Pop-Location
}
