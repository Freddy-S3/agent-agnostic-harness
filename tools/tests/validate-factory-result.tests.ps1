<#
.SYNOPSIS
  Failure-first tests for validate-factory-result.ps1.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$script:Failures = 0
$script:Ran = 0

function Assert($condition, [string]$label) {
    $script:Ran++
    if ($condition) { return }
    $script:Failures++
    Write-Host "FAIL  $label" -ForegroundColor Red
}

function Invoke-Validator([string]$path, [int]$maxFanOut = 3) {
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $shellPath
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script:validator, '-Path', $path, '-MaxFanOut', $maxFanOut)
    foreach ($argument in $arguments) { $startInfo.ArgumentList.Add([string]$argument) }
    $process = [System.Diagnostics.Process]::Start($startInfo)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    return [pscustomobject]@{ Code = $process.ExitCode; Out = $stdout; Err = $stderr }
}

function New-Result([hashtable]$overrides = @{}) {
    $base = @{
        schemaVersion = 1
        runId = 'run-test-1'
        phase = 'implement'
        status = 'completed'
        summary = 'fixture completed'
        startedAt = '2026-11-24T20:00:00Z'
        endedAt = '2026-11-24T20:00:01Z'
        evidence = @(@{
            kind = 'test'
            ref = 'tools/tests/example.tests.ps1'
            source = 'local'
            revision = 'HEAD'
            asOf = '2026-11-24T20:00:01Z'
        })
        sideEffects = @(@{ status = 'none' })
        progress = @{ events = 2; stalled = $false }
        resources = @{ fanOut = 1; fanOutBudget = 3; tokens = 10; latencyMs = 100; cost = 0 }
    }
    foreach ($key in $overrides.Keys) { $base[$key] = $overrides[$key] }
    return $base
}

$script:validator = Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) 'validate-factory-result.ps1'
if (-not (Test-Path -LiteralPath $script:validator)) { throw "validator not found: $script:validator" }
$shellName = if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' }
$shellPath = Join-Path $PSHOME $shellName
$root = Join-Path ([System.IO.Path]::GetTempPath()) ('factory-result-tests-' + [guid]::NewGuid().ToString('n').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $root | Out-Null

function Write-Result([hashtable]$value) {
    $path = Join-Path $root ([guid]::NewGuid().ToString('n') + '.json')
    ($value | ConvertTo-Json -Depth 12) | Set-Content -LiteralPath $path -Encoding UTF8
    return $path
}

Write-Host 'validate-factory-result.tests' -ForegroundColor Cyan

$valid = Invoke-Validator (Write-Result (New-Result))
Assert ($valid.Code -eq 0) 'a complete result with evidence passes'
Assert ([string]::IsNullOrWhiteSpace($valid.Out)) 'success is silent on stdout'

$noEvidence = New-Result
$noEvidence.evidence = @()
$r = Invoke-Validator (Write-Result $noEvidence)
Assert ($r.Code -ne 0 -and $r.Err -match 'at least one evidence') 'completed result needs evidence'

$badStatus = New-Result @{ status = 'succeeded' }
$r = Invoke-Validator (Write-Result $badStatus)
Assert ($r.Code -ne 0 -and $r.Err -match 'status') 'unknown status is rejected'

$unknown = New-Result @{
    status = 'unknown'
    failureReason = 'worker timed out'
    unknownReason = 'the provider did not return a terminal result'
    nextAction = 'reconcile the provider run before retrying'
}
$r = Invoke-Validator (Write-Result $unknown)
Assert ($r.Code -eq 0) 'unknown result with reason and next action is valid'

$unknownMissingReason = New-Result @{
    status = 'unknown'
    failureReason = 'worker timed out'
    nextAction = 'reconcile the provider run'
}
$r = Invoke-Validator (Write-Result $unknownMissingReason)
Assert ($r.Code -ne 0 -and $r.Err -match 'unknownReason') 'unknown result needs an unknown reason'

$submitted = New-Result
$submitted.sideEffects = @(@{ id = 'deploy-1'; operation = 'deploy'; status = 'submitted'; idempotencyKey = 'deploy-1' })
$r = Invoke-Validator (Write-Result $submitted)
Assert ($r.Code -ne 0 -and $r.Err -match 'unconfirmed side effect') 'completed result cannot hide an unconfirmed effect'

$failedEffect = New-Result
$failedEffect.sideEffects = @(@{ id = 'deploy-2'; operation = 'deploy'; status = 'failed'; idempotencyKey = 'deploy-2' })
$r = Invoke-Validator (Write-Result $failedEffect)
Assert ($r.Code -ne 0 -and $r.Err -match 'unconfirmed side effect') 'completed result cannot hide a failed effect'

$confirmedWithoutReadBack = New-Result
$confirmedWithoutReadBack.sideEffects = @(@{ id = 'write-1'; operation = 'write'; status = 'confirmed'; idempotencyKey = 'write-1' })
$r = Invoke-Validator (Write-Result $confirmedWithoutReadBack)
Assert ($r.Code -ne 0 -and $r.Err -match 'readBack') 'confirmed effect needs read-back evidence'

$overFanOut = New-Result
$overFanOut.resources = @{ fanOut = 4; fanOutBudget = 5 }
$r = Invoke-Validator (Write-Result $overFanOut)
Assert ($r.Code -ne 0 -and $r.Err -match 'validator budget') 'fan-out above the validator budget is rejected'

$stalled = New-Result
$stalled.progress = @{ events = 4; stalled = $true }
$r = Invoke-Validator (Write-Result $stalled)
Assert ($r.Code -ne 0 -and $r.Err -match 'stalled') 'a completed stalled result is rejected'

Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue

if ($script:Failures -gt 0) {
    Write-Host ("validate-factory-result.tests: {0} assertion(s) failed out of {1}" -f $script:Failures, $script:Ran) -ForegroundColor Red
    exit 1
}
Write-Host ("validate-factory-result.tests: {0} assertions passed" -f $script:Ran) -ForegroundColor Green
exit 0
