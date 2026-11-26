<#
.SYNOPSIS
  Tests the read-only PR readiness gate against the checked-out repository and offline PR data.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$script:Failures = 0
$script:Ran = 0

function Assert($condition, $label) {
    $script:Ran++
    if ($condition) { return }
    $script:Failures++
    Write-Host "FAIL  $label" -ForegroundColor Red
}

$toolsDir = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$repoRoot = Split-Path -Parent $toolsDir
$check = Join-Path $toolsDir 'check-pr-readiness.ps1'
if (-not (Test-Path -LiteralPath $check)) { throw "check-pr-readiness.ps1 not found at $check" }
$shellName = if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' }
$shellPath = Join-Path $PSHOME $shellName

$jsonRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pr-readiness-tests-" + [guid]::NewGuid().ToString('n').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $jsonRoot | Out-Null

function Invoke-Check([string] $pullRequestJson, [string] $headBranch = 'HEAD', [int] $currentPullRequestNumber = 0, [bool] $branchOnly = $true, [bool] $professionalMode = $false, [string] $baseBranch = 'main', [string] $defaultBranch = 'main') {
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $shellPath
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $processArguments = @('-NoProfile', '-File', $check, '-RepoRoot', $repoRoot, '-BaseBranch', $baseBranch, '-DefaultBranch', $defaultBranch, '-HeadBranch', $headBranch, '-OpenPullRequestsJson', $pullRequestJson)
    if ($branchOnly) { $processArguments += '-BranchOnly' }
    if ($currentPullRequestNumber -gt 0) { $processArguments += @('-CurrentPullRequestNumber', $currentPullRequestNumber) }
    if ($professionalMode) { $processArguments += '-ProfessionalMode' }
    foreach ($argument in $processArguments) { $startInfo.ArgumentList.Add([string]$argument) }
    $process = [System.Diagnostics.Process]::Start($startInfo)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    return @{ code = $process.ExitCode; text = "$stdout`n$stderr" }
}

$cleanJson = Join-Path $jsonRoot 'clean.json'
@(@{ number = 999; headRefName = 'feature'; files = @(@{ path = 'other.txt' }) }) | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $cleanJson -Encoding UTF8
$r = Invoke-Check $cleanJson
Assert ($r.code -eq 0) 'a fresh branch with no overlap exits zero'
Assert ($r.text -match 'READY') 'a fresh branch reports ready'

$r = Invoke-Check $cleanJson 'HEAD' 0 $false
Assert ($r.code -eq 0) 'unstaged generated coordination output does not block a PR check'

$sharedPath = (& git -C $repoRoot diff --name-only origin/main...HEAD | Select-Object -First 1).Trim()
$overlapJson = Join-Path $jsonRoot 'overlap.json'
@(@{ number = 42; headRefName = 'other-feature'; files = @(@{ path = $sharedPath }) }) | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $overlapJson -Encoding UTF8
$r = Invoke-Check $overlapJson
Assert ($r.code -eq 3) 'an open PR path overlap exits three'
Assert ($r.text -match 'PR #42') 'the overlapping PR number is reported'
Assert ($r.text -match [regex]::Escape($sharedPath)) 'the overlapping path is reported'

$nonDefaultJson = Join-Path $jsonRoot 'non-default-base.json'
@(@{ number = 109; headRefName = 'stacked-feature'; baseRefName = 'feature'; files = @() }) | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $nonDefaultJson -Encoding UTF8
$r = Invoke-Check $nonDefaultJson 'HEAD' 109 $true $false 'feature' 'main'
Assert ($r.code -eq 6) 'a pull request targeting a feature branch is blocked before branch comparison'
$r = Invoke-Check $nonDefaultJson 'HEAD' 109 $true $false 'main' 'main'
Assert ($r.code -eq 6) 'the supplied base must match the PR actual base even when it is the default branch'
$r = Invoke-Check $cleanJson 'HEAD' 0 $true $false 'main' 'master'
Assert ($r.code -eq 6) 'the configured repository default branch is honored instead of assuming main'

$r = Invoke-Check $cleanJson 'c5b7fdd'
Assert ($r.code -eq 2) 'a branch behind origin/main exits two'
Assert ($r.text -match 'BLOCKED') 'a stale branch reports blocked'

$autoMergeJson = Join-Path $jsonRoot 'auto-merge.json'
@(@{ number = 108; headRefName = 'feature'; autoMergeRequest = @{ mergeMethod = 'SQUASH' }; files = @() }) | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $autoMergeJson -Encoding UTF8
$r = Invoke-Check $autoMergeJson 'HEAD' 108
Assert ($r.code -eq 0) 'personal mode leaves an enabled auto-merge request allowed'
$r = Invoke-Check $autoMergeJson 'HEAD' 108 $true $true
Assert ($r.code -eq 5) 'professional mode blocks an enabled auto-merge request'
Assert ($r.text -match 'auto-merge is enabled') 'professional mode reports the auto-merge block'

$source = Get-Content -LiteralPath $check -Raw -Encoding UTF8
Assert ($source -match 'docs/CHAT-HANDOFF\.md') 'generated coordination paths are part of the readiness gate'
Assert ($source -match 'exit 3') 'overlap has a distinct non-zero exit code'
Assert ($source -match 'exit 6') 'a non-default target has a distinct non-zero exit code'
Assert ($source -match 'exit 5') 'auto-merge has a distinct non-zero exit code'
Assert ($source -match 'ProfessionalMode') 'auto-merge enforcement is explicitly mode-scoped'

Remove-Item -LiteralPath $jsonRoot -Recurse -Force -ErrorAction SilentlyContinue

if ($script:Failures -gt 0) {
    Write-Host ("check-pr-readiness.tests: {0} assertion(s) failed out of {1}" -f $script:Failures, $script:Ran) -ForegroundColor Red
    exit 1
}
Write-Host ("check-pr-readiness.tests: {0} assertions passed" -f $script:Ran) -ForegroundColor Green
exit 0
