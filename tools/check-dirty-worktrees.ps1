<#!
.SYNOPSIS
  Fail when a project checkout still contains unclassified dirty work.

.DESCRIPTION
  A dirty checkout must be resolved before a session closes: commit it on a
  named branch, stash it with a durable handoff, or explicitly discard it.
  Host-managed memories, local settings, temporary output, Python caches, and
  dated skill backups are excluded by tools/dirty-worktree.psm1.

.EXAMPLE
  powershell -NoProfile -File tools/check-dirty-worktrees.ps1 -WorkspaceRoot C:\Users\Faruk\Repo

.EXAMPLE
  powershell -NoProfile -File tools/check-dirty-worktrees.ps1 -RepositoryPath C:\Users\Faruk\Repo\my-project
#>
[CmdletBinding()]
param(
    [string]$WorkspaceRoot,
    [string[]]$RepositoryPath
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'dirty-worktree.psm1') -Force

function Test-GitCheckout([string]$Path) {
    try {
        $answer = (& git -c "safe.directory=$Path" -c core.excludesFile= -C $Path rev-parse --is-inside-work-tree 2>$null | Select-Object -Last 1)
        return $LASTEXITCODE -eq 0 -and $answer -eq 'true'
    } catch { return $false }
}

try {
    $paths = @()
    if ($RepositoryPath) {
        $paths = @($RepositoryPath)
    } elseif ($WorkspaceRoot) {
        $root = (Resolve-Path -LiteralPath $WorkspaceRoot -ErrorAction Stop).ProviderPath
        $paths = @(Get-ChildItem -LiteralPath $root -Directory -Force |
            Where-Object { $_.Name -notmatch '^\.|^_' -and $_.Name -notin @('Dispatch images', 'archive-view-screenshots', 'unattended-runs', 'temp', 'tmp') } |
            ForEach-Object { $_.FullName })
    } else {
        throw 'Pass -WorkspaceRoot or -RepositoryPath.'
    }

    $violations = @()
    foreach ($path in $paths) {
        if (-not (Test-Path -LiteralPath $path -PathType Container)) { continue }
        if (-not (Test-GitCheckout $path)) { continue }
        $dirty = @(Get-DirtyWorktreePaths $path | Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_)
        })
        if ($dirty.Count -gt 0) {
            $branch = (& git -c "safe.directory=$path" -c core.excludesFile= -C $path branch --show-current 2>$null)
            $violations += [pscustomobject]@{ Path = $path; Branch = $branch; Changes = $dirty }
        }
    }

    if ($violations.Count -eq 0) { exit 0 }
    foreach ($violation in $violations) {
        Write-Output ("DIRTY_WORKTREE: {0} (branch {1})" -f $violation.Path, $violation.Branch)
        foreach ($change in $violation.Changes) { Write-Output ("  {0}" -f $change) }
    }
    exit 1
} catch {
    Write-Error $_
    exit 2
}
