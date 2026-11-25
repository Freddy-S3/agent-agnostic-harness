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

$jsonRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pr-readiness-tests-" + [guid]::NewGuid().ToString('n').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $jsonRoot | Out-Null

function Invoke-Check([string] $pullRequestJson, [string] $headBranch = 'HEAD', [int] $currentPullRequestNumber = 0, [bool] $branchOnly = $true) {
    $out = New-TemporaryFile
    $err = New-TemporaryFile
    try {
        $args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $check, '-RepoRoot', $repoRoot, '-HeadBranch', $headBranch, '-OpenPullRequestsJson', $pullRequestJson)
        if ($branchOnly) { $args += '-BranchOnly' }
        if ($currentPullRequestNumber -gt 0) { $args += @('-CurrentPullRequestNumber', $currentPullRequestNumber) }
        $p = Start-Process -FilePath 'powershell' -ArgumentList $args -RedirectStandardOutput $out.FullName -RedirectStandardError $err.FullName -NoNewWindow -PassThru -Wait
        $text = (Get-Content -LiteralPath $out.FullName -Raw -ErrorAction SilentlyContinue) + "`n" + (Get-Content -LiteralPath $err.FullName -Raw -ErrorAction SilentlyContinue)
        return @{ code = $p.ExitCode; text = $text }
    } finally {
        foreach ($f in $out, $err) { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue }
    }
}

$cleanJson = Join-Path $jsonRoot 'clean.json'
@(@{ number = 999; headRefName = 'feature'; files = @(@{ path = 'other.txt' }) }) | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $cleanJson -Encoding UTF8
$r = Invoke-Check $cleanJson
Assert ($r.code -eq 0) 'a fresh branch with no overlap exits zero'
Assert ($r.text -match 'READY') 'a fresh branch reports ready'

$r = Invoke-Check $cleanJson 'HEAD' 0 $false
Assert ($r.code -eq 0) 'unstaged generated coordination output does not block a PR check'

$sharedPath = (& git.exe -C $repoRoot diff --name-only origin/main...HEAD | Select-Object -First 1).Trim()
$overlapJson = Join-Path $jsonRoot 'overlap.json'
@(@{ number = 42; headRefName = 'other-feature'; files = @(@{ path = $sharedPath }) }) | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $overlapJson -Encoding UTF8
$r = Invoke-Check $overlapJson
Assert ($r.code -eq 3) 'an open PR path overlap exits three'
Assert ($r.text -match 'PR #42') 'the overlapping PR number is reported'
Assert ($r.text -match [regex]::Escape($sharedPath)) 'the overlapping path is reported'

$r = Invoke-Check $cleanJson 'c5b7fdd'
Assert ($r.code -eq 2) 'a branch behind origin/main exits two'
Assert ($r.text -match 'BLOCKED') 'a stale branch reports blocked'

$autoMergeJson = Join-Path $jsonRoot 'auto-merge.json'
@(@{ number = 108; headRefName = 'feature'; autoMergeRequest = @{ mergeMethod = 'SQUASH' }; files = @() }) | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $autoMergeJson -Encoding UTF8
$r = Invoke-Check $autoMergeJson 'HEAD' 108
Assert ($r.code -eq 5) 'an enabled auto-merge request exits five'
Assert ($r.text -match 'auto-merge is enabled') 'an enabled auto-merge request is reported'

$source = Get-Content -LiteralPath $check -Raw -Encoding UTF8
Assert ($source -match 'docs/CHAT-HANDOFF\.md') 'generated coordination paths are part of the readiness gate'
Assert ($source -match 'exit 3') 'overlap has a distinct non-zero exit code'
Assert ($source -match 'exit 5') 'auto-merge has a distinct non-zero exit code'

Remove-Item -LiteralPath $jsonRoot -Recurse -Force -ErrorAction SilentlyContinue

if ($script:Failures -gt 0) {
    Write-Host ("check-pr-readiness.tests: {0} assertion(s) failed out of {1}" -f $script:Failures, $script:Ran) -ForegroundColor Red
    exit 1
}
Write-Host ("check-pr-readiness.tests: {0} assertions passed" -f $script:Ran) -ForegroundColor Green
exit 0
