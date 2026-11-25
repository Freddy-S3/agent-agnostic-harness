<#
.SYNOPSIS
  Check whether the current branch is ready to open or update a pull request.

.DESCRIPTION
  A branch is not ready when it is behind origin/<BaseBranch>, overlaps another open pull
  request, or carries a generated coordination file that should not be part of a feature
  branch. The check is intentionally read-only. It reports the decision and exits with a
  distinct non-zero code so /pr and CI can stop before creating another conflict.

.PARAMETER RepoRoot
  Repository root. Defaults to the parent of this script's directory.

.PARAMETER BaseBranch
  Remote base branch. Defaults to main.

.PARAMETER HeadBranch
  Branch to inspect. Defaults to the checked-out branch.

.PARAMETER OpenPullRequestsJson
  Optional JSON file used by tests or offline callers instead of querying gh.

.PARAMETER CurrentPullRequestNumber
  Optional current PR number. CI uses this to avoid comparing a pull request with itself.
  When supplied, the check also blocks an enabled auto-merge request.

.PARAMETER Json
  Emit one JSON result instead of the human-readable report.

.PARAMETER BranchOnly
  Ignore unstaged and staged working-tree paths. Useful for checking a committed branch while
  unrelated local coordination state is present.

.EXIT CODES
  0  Ready.
  2  Branch is behind the remote base branch.
  3  Changed paths overlap another open pull request.
  4  A generated coordination path is in the branch or the check could not run.
  5  The current pull request has auto-merge enabled.
#>
[CmdletBinding()]
param(
    [string] $RepoRoot,
    [string] $BaseBranch = 'main',
    [string] $HeadBranch,
    [string] $OpenPullRequestsJson,
    [int] $CurrentPullRequestNumber,
    [switch] $BranchOnly,
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path

function Invoke-Tool([string] $FilePath, [string[]] $Arguments) {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = @(& $FilePath @Arguments 2>&1)
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($code -ne 0) {
        throw "$FilePath $($Arguments -join ' ') failed with exit code ${code}: $($output -join ' ')"
    }
    return [string]($output -join [Environment]::NewLine)
}

function Invoke-Git([string[]] $Arguments) {
    return Invoke-Tool 'git' (@('-C', $RepoRoot) + $Arguments)
}

function Normalize-Path([string] $Path) {
    return (($Path -replace '\\', '/') -replace '^\./', '').Trim()
}

try {
    if (-not $HeadBranch) { $HeadBranch = (Invoke-Git @('branch', '--show-current')).Trim() }
    if (-not $HeadBranch) { throw 'The current checkout is detached; no head branch is available.' }

    $counts = (Invoke-Git @('rev-list', '--left-right', '--count', "origin/$BaseBranch...$HeadBranch")).Trim() -split '\s+'
    if ($counts.Count -lt 2) { throw "Could not parse origin/$BaseBranch...$HeadBranch divergence: $counts" }
    $behind = [int]$counts[0]
    $ahead = [int]$counts[1]

    $branchOutput = Invoke-Git @('diff', '--name-only', "origin/$BaseBranch...$HeadBranch")
    $branchPaths = @($branchOutput -split '\r?\n')
    $workingPaths = @()
    $cachedPaths = @()
    if (-not $BranchOnly) {
        $workingOutput = Invoke-Git @('diff', '--name-only')
        $cachedOutput = Invoke-Git @('diff', '--cached', '--name-only')
        $workingPaths = @(
            ($workingOutput -split '\r?\n')
        )
        $cachedPaths = @($cachedOutput -split '\r?\n')
    }
    $changedPaths = @($branchPaths + $workingPaths |
        Where-Object { $_.Trim() } |
        ForEach-Object { Normalize-Path $_ } |
        Sort-Object -Unique)

    $openPullRequests = @()
    if ($OpenPullRequestsJson) {
        $jsonPath = (Resolve-Path -LiteralPath $OpenPullRequestsJson).Path
        $openPullRequests = @(Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json)
    } else {
        $listed = Invoke-Tool 'gh' @('pr', 'list', '--state', 'open', '--json', 'number,headRefName')
        $openPullRequests = @($listed | ConvertFrom-Json)
    }

    $autoMergeEnabled = $false
    if ($CurrentPullRequestNumber -gt 0) {
        if ($OpenPullRequestsJson) {
            $currentPullRequest = @($openPullRequests | Where-Object { [int]$_.number -eq $CurrentPullRequestNumber } | Select-Object -First 1)
            $autoMergeEnabled = $null -ne $currentPullRequest.autoMergeRequest
        } else {
            $currentPullRequest = Invoke-Tool 'gh' @('pr', 'view', [string]$CurrentPullRequestNumber, '--json', 'autoMergeRequest') | ConvertFrom-Json
            $autoMergeEnabled = $null -ne $currentPullRequest.autoMergeRequest
        }
    }

    $overlaps = @()
    foreach ($pr in $openPullRequests) {
        if (-not $pr) { continue }
        if ($CurrentPullRequestNumber -gt 0 -and [int]$pr.number -eq $CurrentPullRequestNumber) { continue }
        if ([string]$pr.headRefName -eq $HeadBranch) { continue }
        $files = @()
        if ($OpenPullRequestsJson) {
            $files = @($pr.files | ForEach-Object {
                if ($_ -is [string]) { $_ } else { $_.path }
            })
        } else {
            $detail = Invoke-Tool 'gh' @('pr', 'view', [string]$pr.number, '--json', 'files') | ConvertFrom-Json
            $files = @($detail.files | ForEach-Object { $_.path })
        }
        $otherPaths = @($files | Where-Object { $_ } | ForEach-Object { Normalize-Path $_ })
        $shared = @($changedPaths | Where-Object { $otherPaths -contains $_ } | Sort-Object -Unique)
        if ($shared.Count -gt 0) {
            $overlaps += [pscustomobject]@{
                Number = [int]$pr.number
                HeadBranch = [string]$pr.headRefName
                Paths = $shared
            }
        }
    }

    $generatedPaths = @('docs/CHAT-HANDOFF.md')
    $prContentPaths = @($branchPaths + $cachedPaths |
        Where-Object { $_.Trim() } |
        ForEach-Object { Normalize-Path $_ } |
        Sort-Object -Unique)
    $generatedChanges = @($prContentPaths | Where-Object { $generatedPaths -contains $_ })
    $result = [pscustomobject]@{
        Ready = ($behind -eq 0 -and $overlaps.Count -eq 0 -and $generatedChanges.Count -eq 0 -and -not $autoMergeEnabled)
        BaseBranch = $BaseBranch
        HeadBranch = $HeadBranch
        Behind = $behind
        Ahead = $ahead
        AutoMergeEnabled = $autoMergeEnabled
        ChangedPaths = $changedPaths
        Overlaps = $overlaps
        GeneratedChanges = $generatedChanges
    }

    if ($Json) {
        $result | ConvertTo-Json -Depth 6
    } else {
        Write-Host "PR readiness: $($result.HeadBranch) -> $($result.BaseBranch)"
        Write-Host "  divergence: $behind behind, $ahead ahead"
        if ($behind -gt 0) {
            Write-Host "  BLOCKED: rebase or update the branch before opening or updating the PR." -ForegroundColor Red
        }
        if ($overlaps.Count -gt 0) {
            foreach ($overlap in $overlaps) {
                Write-Host "  REVIEW: overlaps PR #$($overlap.Number) ($($overlap.HeadBranch)): $($overlap.Paths -join ', ')" -ForegroundColor Yellow
            }
        }
        if ($generatedChanges.Count -gt 0) {
            Write-Host "  BLOCKED: generated coordination paths must not be included: $($generatedChanges -join ', ')" -ForegroundColor Red
        }
        if ($autoMergeEnabled) {
            Write-Host '  BLOCKED: auto-merge is enabled for the current PR; disable it before continuing professional review.' -ForegroundColor Red
        }
        if ($result.Ready) {
            Write-Host '  READY: no stale-base, open-PR overlap, or generated-file issue found.' -ForegroundColor Green
        }
    }

    if ($generatedChanges.Count -gt 0) { exit 4 }
    if ($behind -gt 0) { exit 2 }
    if ($overlaps.Count -gt 0) { exit 3 }
    if ($autoMergeEnabled) { exit 5 }
    exit 0
} catch {
    if ($Json) {
        [pscustomobject]@{ Ready = $false; Error = $_.Exception.Message } | ConvertTo-Json -Depth 4
    } else {
        Write-Error $_.Exception.Message
    }
    exit 4
}
