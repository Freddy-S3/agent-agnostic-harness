<#
.SYNOPSIS
  Audit every repository under the workspace root for a harness entry point.

.DESCRIPTION
  The rules live in this repository. Every other repository is a place agents write, and a
  session that never opens the rules is not bound by them. docs/REPO-ENTRYPOINTS.md is the
  convention; this is the check, because a convention documented and not checked is the
  thing the harness keeps rediscovering.

  A repository passes when it has a root AGENTS.md containing the pointer marker and a root
  CLAUDE.md importing it. Worktrees are skipped: they share the tracked files of their
  parent repository, so fixing the parent fixes them on checkout.

.PARAMETER Root
  Workspace root to scan. Defaults to $HOME/Repo.

.PARAMETER Fix
  Not implemented on purpose. Each repository's entry point goes in through its own pull
  request so someone reads it; a bulk writer would defeat that.

.NOTES
  Exit codes: 0 all repositories pass, 1 at least one is missing an entry point.
#>
[CmdletBinding()]
param(
    [string]$Root = (Join-Path $HOME 'Repo')
)

$ErrorActionPreference = 'Stop'

# The marker is the heading rather than the path, so a repository that points at the rules
# in its own words still passes, and one that merely mentions the harness in passing
# does not.
$Marker = 'Harness rules - read this first'

if (-not (Test-Path -LiteralPath $Root)) {
    Write-Error "Workspace root not found: $Root"
    exit 1
}

$rows = @()
foreach ($dir in Get-ChildItem -LiteralPath $Root -Directory) {
    $dotGit = Join-Path $dir.FullName '.git'
    if (-not (Test-Path -LiteralPath $dotGit)) { continue }

    # A worktree's .git is a file pointing at the parent's gitdir, not a directory.
    if (Test-Path -LiteralPath $dotGit -PathType Leaf) { continue }

    $agents = Join-Path $dir.FullName 'AGENTS.md'
    $claude = Join-Path $dir.FullName 'CLAUDE.md'

    $hasAgents = Test-Path -LiteralPath $agents
    $pointer = $hasAgents -and ((Get-Content -LiteralPath $agents -Raw) -match [regex]::Escape($Marker))
    $hasClaude = (Test-Path -LiteralPath $claude) -and ((Get-Content -LiteralPath $claude -Raw) -match '@')

    $state = if ($pointer -and $hasClaude) { 'ok' }
             elseif ($pointer) { 'no CLAUDE.md import' }
             elseif ($hasAgents) { 'AGENTS.md has no harness pointer' }
             else { 'no AGENTS.md' }

    $rows += [pscustomobject]@{ Repo = $dir.Name; State = $state }
}

# The harness repository is the source of the rules and points at instructions/AGENTS.md in
# its own words, so it is reported like any other row rather than exempted. An exemption is
# how a checker starts lying.
$rows | Sort-Object State, Repo | Format-Table -AutoSize | Out-String | Write-Output

$bad = @($rows | Where-Object { $_.State -ne 'ok' })
if ($bad.Count -gt 0) {
    Write-Output "$($bad.Count) of $($rows.Count) repositories have no usable harness entry point."
    Write-Output 'See docs/REPO-ENTRYPOINTS.md for the convention and the pointer block to add.'
    exit 1
}
Write-Output "All $($rows.Count) repositories carry a harness entry point."
exit 0
