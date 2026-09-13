<#
.SYNOPSIS
  Add a Git worktree only after the three-folder family guard passes.

.EXAMPLE
  powershell -NoProfile -File tools\worktree-add.ps1 -RepoRoot C:\Users\Faruk\Repo\agent-agnostic-harness -Path C:\Users\Faruk\Repo\aah-next -Branch chore/next -StartPoint origin/main -Family agent-agnostic-harness
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RepoRoot,
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Branch,
    [string]$StartPoint = 'origin/main',
    [string]$Family,
    [string]$WorkspaceRoot
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path -LiteralPath $RepoRoot -ErrorAction Stop).ProviderPath
$target = [IO.Path]::GetFullPath($Path)
if (-not $WorkspaceRoot) { $WorkspaceRoot = Split-Path -Parent $repo }

$guard = Join-Path $PSScriptRoot 'check-folder-hygiene.ps1'
# -ErrorAction Stop on a name list throws on the first missing name, so a machine without
# pwsh never reached powershell.exe and the guard failed before it ran (2026-09-13).
$ps = (Get-Command pwsh, powershell.exe, powershell -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $ps) { throw 'No PowerShell executable found on PATH.' }
$guardArgs = @('-NoProfile', '-NonInteractive', '-File', $guard, '-Action', 'assert-add', '-WorkspaceRoot', $WorkspaceRoot, '-CandidatePath', $target)
if ($Family) { $guardArgs += @('-Family', $Family) }
& $ps @guardArgs
if ($LASTEXITCODE -ne 0) { throw 'Folder-family guard refused the new worktree.' }

& git -c safe.directory="$repo" -C $repo worktree add $target -b $Branch $StartPoint
if ($LASTEXITCODE -ne 0) { throw 'git worktree add failed.' }
