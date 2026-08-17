[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repository,
    [string]$Purpose = 'Continue project coordination'
)

$ErrorActionPreference = 'Stop'
$repoPath = (Resolve-Path $Repository).Path
$repoName = Split-Path $repoPath -Leaf
$branch = git -C $repoPath branch --show-current
$status = @(git -C $repoPath status --short)
$recent = @(git -C $repoPath log -3 --oneline)
$agentsPath = Join-Path $repoPath 'AGENTS.md'
$agentsNote = if (Test-Path $agentsPath) { 'Read AGENTS.md before acting.' } else { 'No repository AGENTS.md exists yet.' }

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("Continue the $repoName project.")
$lines.Add('')
$lines.Add("Purpose: $Purpose")
$lines.Add("Repository: $repoPath")
$lines.Add("Current branch: $branch")
$lines.Add($agentsNote)
$lines.Add('')
$lines.Add('Operating rules:')
$lines.Add('- Keep work agent-agnostic and use repository files, queue, tracker, and pull requests as the source of truth.')
$lines.Add('- Inspect the repository before planning or editing.')
$lines.Add('- Keep this chat focused on coordination; create a separate outcome chat for implementation.')
$lines.Add('')
$lines.Add('Recent commits:')
if ($recent) { $recent | ForEach-Object { $lines.Add("- $_") } } else { $lines.Add('- None') }
$lines.Add('')
$lines.Add('Working-tree status:')
if ($status) { $status | ForEach-Object { $lines.Add("- $_") } } else { $lines.Add('- Clean') }
$lines.Add('')
$lines.Add('First action: read the repository guidance and report the current goals, blockers, and next recommended action.')

$handoff = $lines -join [Environment]::NewLine
$handoff | Set-Clipboard
$handoff
Write-Host ''
Write-Host 'Copied the handoff to the clipboard.'
