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
$core = Get-Content -Raw -LiteralPath (Join-Path $root 'instructions\AGENTS.md')
$router = Get-Content -Raw -LiteralPath (Join-Path $root 'skills\faruk\ROUTER-CONTRACT.md')
$harness = Get-Content -Raw -LiteralPath (Join-Path $root 'HARNESS.md')

Write-Host 'check-ship-contract.tests' -ForegroundColor Cyan

Assert ($ship -match '## Human-visible gates') 'ship names the human-visible gate contract'
Assert (($ship -split 'Stop with the complete Gate 1 block').Count -eq 2) 'Gate 1 is required as a standalone response'
Assert (($ship -split 'Stop with the complete Gate 2 block').Count -eq 2) 'Gate 2 is required as a standalone response'
Assert (($ship -split 'Stop with the complete Gate 3 block').Count -eq 2) 'Gate 3 is required as a standalone response'
Assert ($ship -match 'Elapsed-time.*never replace') 'telemetry cannot replace gate text'
Assert ($ship -match 'After every `proceed`, always schedule one context worker') 'proceed always schedules context capture'
Assert ($ship -match 'After every approved implementation, always run the context worker') 'every approved implementation reviews and refreshes project context'
Assert ($ship -notmatch 'proceed \+ context') 'ship no longer exposes the optional context shortcut'
Assert ($harness -notmatch 'proceed \+ context') 'harness guide no longer exposes the optional context shortcut'
Assert ($ship -match 'Planning reminder: default = auto \+ no time limit') 'Ship displays the quick mode and timing reminder'
Assert ($ship -match 'Planning setup\? Reply `default`') 'Ship asks one compact mode and timing question'
Assert ($ship -match 'tools/check-repository\.ps1 -Path <target>') 'professional Ship checks the target repository'
Assert ($ship -match 'Personal mode skips this preflight') 'personal mode skips repository initialization'
Assert ($ship -match 'Repository: <resolved Git root and commit state') 'Gate 1 shows repository state'
Assert ($ship -match 'missing - initialization required') 'missing repositories are visible at Gate 1'
Assert ($ship -match 'tools/check-repository\.ps1 -Path <target> -Initialize') 'initialization happens only after proceed'
Assert ($harness -match 'tools/check-repository\.ps1') 'harness guide documents repository preflight'
Assert ($core -match 'human-typed `/ship` also runs delivery mode') 'direct Ship invocation selects delivery mode'
Assert ($core -match 'automatically.*`/ship` inherits the current route') 'automatic Ship preserves the active route'
Assert ($router -match 'human-typed `/ship <task>` starts a delivery-mode route') 'router contract records direct Ship mode'
Assert ($router -match 'selected automatically by `/faruk`.*preserves the existing') 'router contract preserves personal auto-Ship mode'
Assert ($ship -match 'human-typed `/ship <task>` selects professional delivery mode') 'Ship records direct invocation behavior'
Assert ($ship -match 'automatically for an ordinary request.*inherit the current') 'Ship records automatic invocation behavior'
Assert ($ship -match 'pull request target is always the repository default branch') 'Ship requires PRs to target the repository default branch'
Assert ($ship -match 'At closeout, verify `gh pr view <number> --json baseRefName` reports that default branch') 'Ship verifies the actual GitHub PR base at closeout'
Assert ($ship -match 'Never count a merge into a feature branch as delivery') 'Ship does not count feature-branch merges as completion'
Assert ($harness -match 'When you type `/ship` yourself.*professional delivery mode') 'harness guide explains direct Ship mode'

if ($script:Failures -gt 0) {
    Write-Host ("check-ship-contract.tests: {0} assertion(s) failed out of {1}" -f $script:Failures, $script:Ran) -ForegroundColor Red
    exit 1
}
Write-Host ("check-ship-contract.tests: {0} assertions passed" -f $script:Ran) -ForegroundColor Green
exit 0
