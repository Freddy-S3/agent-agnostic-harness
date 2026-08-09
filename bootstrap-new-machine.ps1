<#
.SYNOPSIS
    One-time setup for a fresh PC: clones every repo under C:\Users\Faruk\Repo and
    installs this harness.

.DESCRIPTION
    Replaces a manual zip-and-copy migration. The repos already live on GitHub, so
    this script re-derives the local workspace instead of dragging .git history,
    node_modules, and build artifacts across machines. It does NOT touch auth -
    sign in with `claude` and `gh auth login` separately (see NEW-MACHINE-SETUP.md).

    Steps:
      1. Create C:\Users\Faruk\Repo if it doesn't exist.
      2. List every repo under the Freddy-S3 GitHub account (`gh repo list`) and
         clone whichever aren't already present locally.
      3. Run install.ps1 -Target claude -Mcp from the freshly cloned claude-harness,
         so the skill/memory junctions and CLAUDE.md stub are set up the same way
         they are on this machine.

.PARAMETER GitHubUser
    GitHub account to enumerate repos from. Defaults to Freddy-S3.

.PARAMETER RepoRoot
    Where repos live. Defaults to C:\Users\Faruk\Repo.

.PARAMETER Only
    Optional list of repo names to clone instead of everything the account has.
    Use this to skip old practice/test repos that don't belong on a fresh machine.

.PARAMETER DryRun
    Report every action without writing or cloning anything.

.EXAMPLE
    .\bootstrap-new-machine.ps1

.EXAMPLE
    .\bootstrap-new-machine.ps1 -Only claude-harness,Portfolio-Website,unattended-runs

.EXAMPLE
    .\bootstrap-new-machine.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [string]$GitHubUser = 'Freddy-S3',
    [string]$RepoRoot = (Join-Path $env:USERPROFILE 'Repo'),
    [string[]]$Only,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Invoke-Step {
    param([string]$Description, [scriptblock]$Action)
    Write-Host "==> $Description"
    if ($DryRun) {
        Write-Host "    (dry run, skipped)"
        return
    }
    & $Action
}

# --- prerequisite check -----------------------------------------------------

foreach ($tool in @('git', 'gh')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "$tool is not on PATH. Install it first - see NEW-MACHINE-SETUP.md."
    }
}

$whoami = gh api user --jq '.login' 2>$null
if (-not $whoami) {
    throw "gh is not authenticated. Run 'gh auth login' first."
}

# --- 1. repo root -------------------------------------------------------

if (-not (Test-Path $RepoRoot)) {
    Invoke-Step "Create $RepoRoot" { New-Item -ItemType Directory -Path $RepoRoot -Force | Out-Null }
} else {
    Write-Host "==> $RepoRoot already exists"
}

# --- 2. clone every repo not already present -----------------------------

Write-Host "==> Listing repos for $GitHubUser"
$repos = gh repo list $GitHubUser --limit 200 --json name,url | ConvertFrom-Json

if ($Only) {
    $repos = $repos | Where-Object { $Only -contains $_.name }
}

foreach ($repo in $repos) {
    $dest = Join-Path $RepoRoot $repo.name
    if (Test-Path $dest) {
        Write-Host "==> $($repo.name) already cloned, skipping"
        continue
    }
    Invoke-Step "Clone $($repo.name)" { gh repo clone "$GitHubUser/$($repo.name)" $dest }
}

# --- 3. install the harness -----------------------------------------------

$harnessInstall = Join-Path $RepoRoot 'claude-harness\install.ps1'
if (Test-Path $harnessInstall) {
    Invoke-Step "Install harness (claude, with MCP config)" {
        & $harnessInstall -Target claude -Mcp
    }
} else {
    Write-Warning "claude-harness\install.ps1 not found under $RepoRoot - clone it manually and run install.ps1 -Target claude yourself."
}

Write-Host ""
Write-Host "Done. Remaining manual steps (not automatable, see NEW-MACHINE-SETUP.md):"
Write-Host "  - Sign in: run 'claude' and complete login (writes ~/.claude/.credentials.json)."
Write-Host "  - Review ~/.claude/settings.json - it is local-only and NOT reproduced by this script."
Write-Host "  - Fill in any MCP env vars (JIRA_URL, JIRA_PERSONAL_TOKEN, etc.) if you use the Atlassian MCP server."
Write-Host "  - Restart the host so it rediscovers skills, then confirm /faruk and /pr are listed."
