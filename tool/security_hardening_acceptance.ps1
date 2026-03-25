#Requires -Version 5.1
<#
.SYNOPSIS
    Phase 53 read-only security hardening acceptance helper.

.DESCRIPTION
    Runs the focused repo-local Flutter and Astro verification commands that
    correspond to the Phase 50-52 security hardening work.

    IMPORTANT: This helper is READ-ONLY with respect to the live database.
    It does NOT execute SQL files, does NOT call Supabase APIs, and does NOT
    run the portal recovery script.

    Live Supabase rollout confirmation (applying the Phase 50, 51, and 52 SQL
    migrations in the Supabase SQL Editor) is STILL MANUAL EVIDENCE that must
    be captured separately by the operator outside this helper.

.PARAMETER CheckOnly
    Print the planned command surface without executing any commands.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tool/security_hardening_acceptance.ps1 -CheckOnly
    powershell -ExecutionPolicy Bypass -File tool/security_hardening_acceptance.ps1
#>

param(
    [switch]$CheckOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Flutter = 'C:\flutter\bin\flutter.bat'

# The exact acceptance command surface for Phase 53.
# Order is fixed: kiosk -> admin -> portal Flutter tests, then Astro checks.
$Commands = @(
    @{ Label = 'Phase 50 kiosk device model regression'; Cmd = $Flutter; Args = @('test', 'test/phase50/kiosk_device_model_test.dart') }
    @{ Label = 'Phase 51 admin session claims regression'; Cmd = $Flutter; Args = @('test', 'test/phase51/admin_session_claims_test.dart') }
    @{ Label = 'Phase 51 SQL role guard contract';        Cmd = $Flutter; Args = @('test', 'test/phase51/sql_role_guard_contract_test.dart') }
    @{ Label = 'Phase 52 portal recovery contract';       Cmd = $Flutter; Args = @('test', 'test/phase52/portal_recovery_contract_test.dart') }
    @{ Label = 'Astro check (portal website)';            Cmd = 'npm';    Args = @('run', 'check') }
    @{ Label = 'Astro build (portal website)';            Cmd = 'npm';    Args = @('run', 'build') }
)

Write-Host ''
Write-Host '================================================='
Write-Host ' Phase 53 Security Hardening Acceptance Helper'
Write-Host '================================================='
Write-Host ''
Write-Host 'SCOPE: Repo-local Flutter and Astro verification only.'
Write-Host 'NOT IN SCOPE: SQL execution, Supabase API calls, recovery scripts.'
Write-Host ''
Write-Host 'Live Supabase rollout (Phase 50, 51, 52 SQL migrations) must be'
Write-Host 'confirmed MANUALLY by the operator in the Supabase SQL Editor.'
Write-Host ''

if ($CheckOnly) {
    Write-Host '--- CheckOnly mode: printing acceptance command surface ---'
    Write-Host ''
    $i = 1
    foreach ($step in $Commands) {
        $display = "$($step.Cmd) $($step.Args -join ' ')"
        Write-Host "  [$i] $($step.Label)"
        Write-Host "      $display"
        Write-Host ''
        $i++
    }
    Write-Host '--- End of acceptance command surface ---'
    Write-Host ''
    Write-Host 'Run without -CheckOnly to execute all commands.'
    exit 0
}

Write-Host '--- Running acceptance checks ---'
Write-Host ''

$failed = $false

foreach ($step in $Commands) {
    Write-Host ">> $($step.Label)"
    Write-Host "   $($step.Cmd) $($step.Args -join ' ')"

    & $step.Cmd @($step.Args)
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        Write-Host ''
        Write-Host "FAILED [$exitCode]: $($step.Label)" -ForegroundColor Red
        Write-Host "Command: $($step.Cmd) $($step.Args -join ' ')" -ForegroundColor Red
        Write-Host ''
        $failed = $true
        break
    }

    Write-Host "PASSED: $($step.Label)" -ForegroundColor Green
    Write-Host ''
}

if ($failed) {
    Write-Host 'Acceptance run FAILED. Fix the failing command and rerun.' -ForegroundColor Red
    Write-Host ''
    Write-Host 'Reminder: live Supabase rollout is still manual evidence outside this helper.'
    exit 1
}

Write-Host '================================================='
Write-Host ' All repo-local acceptance checks PASSED.'
Write-Host '================================================='
Write-Host ''
Write-Host 'Remaining manual evidence required before closing Phase 53:'
Write-Host '  - Apply sql/phase_50_kiosk_boundary_hardening_20260325.sql in Supabase SQL Editor'
Write-Host '  - Apply sql/phase_51_admin_session_trust_20260325.sql in Supabase SQL Editor'
Write-Host '  - Apply sql/phase_52_portal_search_minimization_20260325.sql in Supabase SQL Editor'
Write-Host '  - Run sql/repair_employee_portal_accounts_20260325.sql ONLY in an approved repair scenario'
Write-Host ''
exit 0
