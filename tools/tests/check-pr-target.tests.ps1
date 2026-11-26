<#
.SYNOPSIS
  Test the mainline-only pull request target contract.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$script:Failures = 0
$script:Ran = 0

function Assert($condition, [string] $label) {
    $script:Ran++
    if ($condition) { return }
    $script:Failures++
    Write-Host "FAIL  $label" -ForegroundColor Red
}

$toolsDir = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$repoRoot = Split-Path -Parent $toolsDir
$check = Join-Path $toolsDir 'check-pr-target.ps1'
if (-not (Test-Path -LiteralPath $check)) { throw "check-pr-target.ps1 not found at $check" }
$shellName = if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' }
$shellPath = Join-Path $PSHOME $shellName

function Invoke-TargetCheck([string] $baseBranch, [string] $defaultBranch) {
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $shellPath
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in @('-NoProfile', '-File', $check)) { $startInfo.ArgumentList.Add($argument) }
    if ($baseBranch) {
        $startInfo.ArgumentList.Add('-BaseBranch')
        $startInfo.ArgumentList.Add($baseBranch)
    }
    if ($defaultBranch) {
        $startInfo.ArgumentList.Add('-DefaultBranch')
        $startInfo.ArgumentList.Add($defaultBranch)
    }
    $process = [System.Diagnostics.Process]::Start($startInfo)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    return @{ code = $process.ExitCode; text = "$stdout`n$stderr" }
}

$r = Invoke-TargetCheck 'main' 'main'
Assert ($r.code -eq 0) 'the default branch is accepted'

$r = Invoke-TargetCheck 'feature/stack' 'main'
Assert ($r.code -eq 6) 'a feature branch target is rejected'
Assert ($r.text -match 'must target the repository default branch') 'the rejection explains the required target'

$r = Invoke-TargetCheck 'main' 'trunk'
Assert ($r.code -eq 6) 'the repository default branch is supplied instead of hard-coded'

$r = Invoke-TargetCheck '' 'main'
Assert ($r.code -eq 4) 'missing branch data fails closed'

$workflow = Get-Content -Raw -LiteralPath (Join-Path $repoRoot '.github\workflows\pr-readiness.yml')
Assert ($workflow -match 'mainline-target:') 'the target gate has its own stable status name'
Assert ($workflow -match 'tools/check-pr-target\.ps1') 'the workflow runs the mainline target gate'
Assert ($workflow -match "- edited") 'changing a PR base reruns the target gate'

$guide = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'docs\PR-CONFLICT-PREVENTION.md')
Assert ($guide -match 'GitHub does not provide a safe repository-wide required-check rule') 'the guide records why non-default branch protection is not configured globally'
Assert (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'config\github\non-default-branch-target-ruleset.json'))) 'the invalid repository-wide ruleset is not shipped'

if ($script:Failures -gt 0) {
    Write-Host ("check-pr-target.tests: {0} assertion(s) failed out of {1}" -f $script:Failures, $script:Ran) -ForegroundColor Red
    exit 1
}

Write-Host ("check-pr-target.tests: {0} assertions passed" -f $script:Ran) -ForegroundColor Green
exit 0
