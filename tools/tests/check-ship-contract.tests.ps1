<#
.SYNOPSIS
  Check the user-visible /ship gate and automatic context contract.
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

$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
$ship = Get-Content -Raw -LiteralPath (Join-Path $root 'skills\ship\SKILL.md')
$harness = Get-Content -Raw -LiteralPath (Join-Path $root 'HARNESS.md')

Write-Host 'check-ship-contract.tests' -ForegroundColor Cyan

Assert ($ship -match '## Human-visible gates') 'ship names the human-visible gate contract'
Assert (($ship -split 'Stop with the complete Gate 1 block').Count -eq 2) 'Gate 1 is required as a standalone response'
Assert (($ship -split 'Stop with the complete Gate 2 block').Count -eq 2) 'Gate 2 is required as a standalone response'
Assert (($ship -split 'Stop with the complete Gate 3 block').Count -eq 2) 'Gate 3 is required as a standalone response'
Assert ($ship -match 'Elapsed-time.*never replace') 'telemetry cannot replace gate text'
Assert ($ship -match 'After every `proceed`, schedule one context worker') 'proceed always schedules context capture'
Assert ($ship -notmatch 'proceed \+ context') 'ship no longer exposes the optional context shortcut'
Assert ($harness -notmatch 'proceed \+ context') 'harness guide no longer exposes the optional context shortcut'

if ($script:Failures -gt 0) {
    Write-Host ("check-ship-contract.tests: {0} assertion(s) failed out of {1}" -f $script:Failures, $script:Ran) -ForegroundColor Red
    exit 1
}
Write-Host ("check-ship-contract.tests: {0} assertions passed" -f $script:Ran) -ForegroundColor Green
exit 0
