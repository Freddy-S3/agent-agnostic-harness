<#
.SYNOPSIS
  Failure-first tests for evaluate-factory.ps1.
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

function Invoke-Evaluator([string]$manifest, [string]$output, [string]$caseId = '') {
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $shellPath
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script:evaluator, '-Manifest', $manifest, '-Output', $output, '-RepoRoot', $script:repoRoot)
    if ($caseId) { $arguments += @('-CaseId', $caseId) }
    foreach ($argument in $arguments) { $startInfo.ArgumentList.Add([string]$argument) }
    $process = [System.Diagnostics.Process]::Start($startInfo)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    return [pscustomobject]@{ Code = $process.ExitCode; Out = $stdout; Err = $stderr }
}

function Write-Manifest([hashtable]$value) {
    $path = Join-Path $script:root ([guid]::NewGuid().ToString('n') + '.json')
    ($value | ConvertTo-Json -Depth 12) | Set-Content -LiteralPath $path -Encoding UTF8
    return $path
}

$script:repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$script:evaluator = Join-Path $script:repoRoot 'evaluate-factory.ps1'
if (-not (Test-Path -LiteralPath $script:evaluator)) { throw "evaluator not found: $script:evaluator" }
$shellName = if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' }
$shellPath = Join-Path $PSHOME $shellName
$script:root = Join-Path ([System.IO.Path]::GetTempPath()) ('factory-eval-tests-' + [guid]::NewGuid().ToString('n').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $script:root | Out-Null

Write-Host 'evaluate-factory.tests' -ForegroundColor Cyan

$manifest = @{
    schemaVersion = 1
    name = 'fixture-evaluation'
    cases = @(
        @{ id = 'pass'; origin = 'fixture'; command = 'exit 0'; expectExit = 0 },
        @{ id = 'fail'; origin = 'fixture'; command = 'exit 1'; expectExit = 0 }
    )
}
$manifestPath = Write-Manifest $manifest
$reportPath = Join-Path $script:root 'report.json'
$r = Invoke-Evaluator $manifestPath $reportPath 'pass'
Assert ($r.Code -eq 0) 'a selected passing case exits zero'
Assert ([string]::IsNullOrWhiteSpace($r.Out)) 'a passing evaluation is silent on stdout'
Assert (Test-Path -LiteralPath $reportPath) 'a passing evaluation writes a report'
$report = Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json
Assert ($report.passed -eq 1 -and $report.failed -eq 0) 'the report records selected case counts'
Assert ($report.cases[0].durationMs -ge 0) 'the report records case latency'

$nestedManifest = Write-Manifest @{
    schemaVersion = 1
    name = 'nested-fixture-evaluation'
    evaluation = @{ cases = @(@{ id = 'nested-pass'; origin = 'fixture'; command = 'exit 0'; expectExit = 0 }) }
}
$r = Invoke-Evaluator $nestedManifest (Join-Path $script:root 'nested-report.json')
Assert ($r.Code -eq 0) 'the template-style nested evaluation cases are supported'

$reportPath = Join-Path $script:root 'failed-report.json'
$r = Invoke-Evaluator $manifestPath $reportPath
Assert ($r.Code -ne 0 -and $r.Err -match 'evaluation failed') 'a failing case exits non-zero with a useful error'
$report = Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json
Assert ($report.failed -eq 1) 'the report records the failed case'
Assert ($report.cases | Where-Object { $_.status -eq 'failed' }) 'the failed case preserves its status'

$timeoutManifest = Write-Manifest @{
    schemaVersion = 1
    name = 'timeout-fixture-evaluation'
    cases = @(@{ id = 'timeout'; origin = 'fixture'; command = 'Start-Sleep -Seconds 2'; expectExit = 0; maxDurationMs = 100 })
}
$timeoutReportPath = Join-Path $script:root 'timeout-report.json'
$r = Invoke-Evaluator $timeoutManifest $timeoutReportPath
Assert ($r.Code -ne 0 -and $r.Err -match 'timeout') 'a timed-out case fails the evaluation'
$timeoutReport = Get-Content -Raw -LiteralPath $timeoutReportPath | ConvertFrom-Json
Assert ($timeoutReport.timedOut -eq 1) 'the report distinguishes timeout from ordinary failure'

$badManifest = Write-Manifest @{ schemaVersion = 1; name = 'bad'; cases = @(@{ id = 'missing-origin'; command = 'exit 0' }) }
$r = Invoke-Evaluator $badManifest (Join-Path $script:root 'bad.json')
Assert ($r.Code -ne 0 -and $r.Err -match 'origin') 'cases without origin are rejected'

$r = Invoke-Evaluator $manifestPath (Join-Path $script:root 'missing-case.json') 'not-here'
Assert ($r.Code -ne 0 -and $r.Err -match 'not found') 'unknown case selection is rejected'

Remove-Item -LiteralPath $script:root -Recurse -Force -ErrorAction SilentlyContinue

if ($script:Failures -gt 0) {
    Write-Host ("evaluate-factory.tests: {0} assertion(s) failed out of {1}" -f $script:Failures, $script:Ran) -ForegroundColor Red
    exit 1
}
Write-Host ("evaluate-factory.tests: {0} assertions passed" -f $script:Ran) -ForegroundColor Green
exit 0
