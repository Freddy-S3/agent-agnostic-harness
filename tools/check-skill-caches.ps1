<#
.SYNOPSIS
  Fail loudly when any cached, copied, or linked view of the harness skills and
  instructions has drifted from this repository.

.DESCRIPTION
  The harness is consumed through more than one path. Some hosts read the repository
  live through a junction; others take a copy at setup time and never look again. A copy
  is indistinguishable from the real thing on the day it is made and diverges silently
  afterwards, which is why the 2026-08-12 rename was clean inside the repository and
  stale in three consumers nobody had enumerated.

  This is the enumeration, as a check that runs rather than a paragraph that advises.
  Each consumer class below is either verified or reported as unverifiable. A class that
  cannot be reached from this machine is NOT silently passed - the whole reason this file
  exists is a consumer that looked fine because nobody asked it anything.

  Classes checked:

    A. Scheduled-task prompts under ~/.claude/scheduled-tasks/. These are copies taken
       when the task was created and refreshed by nothing. Generated from
       templates/scheduled-tasks/ in this repo; -Fix rewrites them.
    B. Linked skill directories (~/.claude/skills, ~/.codex/skills/*). These read live,
       so the question is not whether the link resolves but whether the checkout it
       resolves INTO is current. A junction into a worktree left on a merged branch reads
       fine and serves code that no longer exists.
    C. Cached checkouts of this repo inside sibling repos (*/.harness-cache/*).
    D. A stale-name sweep across everything above, for the pre-rename repository name and
       the pre-split single queue file.
    E. Off-machine copies - the Cowork / claude.ai account-side skill cache. Reported,
       never claimed clean, because this script cannot read it.

.PARAMETER Fix
  Rewrite what can be safely regenerated (class A). Everything else is reported with the
  command that repairs it, because repointing a link or moving a checkout is the
  installer's job and not a side effect of a health check.

.EXAMPLE
  powershell -NoProfile -File tools\check-skill-caches.ps1
  powershell -NoProfile -File tools\check-skill-caches.ps1 -Fix

.NOTES
  Exit codes: 0 all reachable consumers current, 1 drift found.
#>
[CmdletBinding()]
param(
    [switch]$Fix,
    [string]$RepoRoot,
    [string]$HostHome
)

$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent $PSScriptRoot }
if (-not $HostHome) { $HostHome = $env:USERPROFILE }
if (-not $HostHome) { $HostHome = $HOME }

$script:Problems = @()
$script:Notes = @()

function Add-Problem($where, $what, $fix) {
    $script:Problems += [pscustomobject]@{ Where = $where; What = $what; Fix = $fix }
}

function Write-Section($name) { Write-Host $name -ForegroundColor Green }

# The names that mean 'this copy predates a change nobody propagated'. Each is paired
# with what it should say now, so the failure message tells the reader what to do.
$staleTokens = @(
    @{ Pattern = 'Repo[\\/]claude-harness'; Means = 'the pre-2026-08-12 repository name; it is agent-agnostic-harness now' },
    @{ Pattern = 'claude-harness-public';    Means = 'the pre-rename public mirror name' },
    @{ Pattern = 'queue[\\/]QUEUE\.md';      Means = 'the pre-split single queue file; it is QUEUE-PC.md / QUEUE-PHONE.md now, outside the repo' }
)
# ~/.claude-harness/ is the on-disk queue DATA directory. It is named after the old repo
# and was deliberately left alone (it is not a repo path, and renaming it would move live
# data the dashboard reads). Excluded so this check does not relitigate a settled call.
$staleAllowed = '~?[\\/]?\.claude-harness[\\/]'

function Test-StaleNames($path, $label) {
    $text = Get-Content -Raw -LiteralPath $path -ErrorAction SilentlyContinue
    if (-not $text) { return $false }
    $found = $false
    foreach ($line in ($text -split "`n")) {
        if ($line -match $staleAllowed) { continue }
        foreach ($t in $staleTokens) {
            if ($line -match $t.Pattern) {
                Add-Problem $label "names $($t.Means)" 'regenerate this copy from the repository'
                $found = $true
            }
        }
    }
    return $found
}

# --- A. scheduled-task prompt snapshots --------------------------------------------

Write-Section 'A. scheduled-task prompts'
$templateRoot = Join-Path $RepoRoot 'templates\scheduled-tasks'
$taskRoot = Join-Path $HostHome '.claude\scheduled-tasks'

if (-not (Test-Path -LiteralPath $templateRoot)) {
    Write-Host "  (no templates/scheduled-tasks in this repo)"
}
elseif (-not (Test-Path -LiteralPath $taskRoot)) {
    Write-Host "  (no scheduled tasks installed on this machine)"
}
else {
    foreach ($tpl in Get-ChildItem -Directory -LiteralPath $templateRoot) {
        $src = Join-Path $tpl.FullName 'SKILL.md'
        $dst = Join-Path (Join-Path $taskRoot $tpl.Name) 'SKILL.md'
        if (-not (Test-Path -LiteralPath $src)) { continue }
        if (-not (Test-Path -LiteralPath $dst)) {
            Write-Host "  ($($tpl.Name) not installed on this machine)"
            continue
        }
        $srcText = (Get-Content -Raw -LiteralPath $src) -replace "`r`n", "`n"
        $dstText = (Get-Content -Raw -LiteralPath $dst) -replace "`r`n", "`n"
        if ($srcText.TrimEnd() -eq $dstText.TrimEnd()) {
            Write-Host "  $($tpl.Name): current"
            continue
        }
        # Stale names in this file are reported by the class D sweep, which reads the same
        # path; reporting them here too would double-count one defect.
        if ($Fix) {
            Set-Content -LiteralPath $dst -Value $srcText -Encoding utf8
            Write-Host "  $($tpl.Name): REWRITTEN from template" -ForegroundColor Yellow
        }
        else {
            Add-Problem "scheduled task '$($tpl.Name)'" 'differs from its template in this repo' "check-skill-caches.ps1 -Fix"
        }
    }
}

# --- B. linked skill directories ---------------------------------------------------

Write-Section 'B. linked skill directories'

function Resolve-LinkTarget($path) {
    $item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    if (-not $item) { return $null }
    if ($item.Target) { return @($item.Target)[0] }
    return $item.FullName
}

function Test-CheckoutCurrent($path, $label) {
    # The weaker question - 'does this link resolve' - is the one that reports success
    # during an outage. The real question is whether the checkout it lands in is current.
    $top = & git -C $path rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $top) {
        Add-Problem $label "resolves to $path, which is not inside a git checkout" 'reinstall from the harness repo'
        return
    }
    $default = 'main'
    $behind = & git -C $path rev-list --count "HEAD..origin/$default" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Add-Problem $label "cannot compare $path against origin/$default" 'git -C <path> fetch origin'
        return
    }
    $branch = (& git -C $path rev-parse --abbrev-ref HEAD 2>$null)
    if ([int]$behind -gt 0) {
        Add-Problem $label "resolves into $path, which is $behind commits behind origin/$default (on '$branch')" `
            "run install.ps1 from ~/Repo/agent-agnostic-harness on origin/$default, or bring that checkout forward"
    }
    else {
        Write-Host "  $label -> $path (current, on '$branch')"
    }
}

$linkRoots = @(
    @{ Path = (Join-Path $HostHome '.claude\skills'); PerChild = $false; Label = '~/.claude/skills' },
    @{ Path = (Join-Path $HostHome '.codex\skills');  PerChild = $true;  Label = '~/.codex/skills' }
)

foreach ($root in $linkRoots) {
    if (-not (Test-Path -LiteralPath $root.Path)) {
        Write-Host "  ($($root.Label) not present)"
        continue
    }
    if (-not $root.PerChild) {
        $t = Resolve-LinkTarget $root.Path
        if ($t) { Test-CheckoutCurrent $t $root.Label }
        continue
    }
    # Codex links each skill individually so its own .system survives; a single stale
    # install run repoints all of them at once, so check the distinct targets, not all N.
    $targets = @{}
    foreach ($child in Get-ChildItem -LiteralPath $root.Path -Directory -Force -ErrorAction SilentlyContinue) {
        if ($child.Name -eq '.system') { continue }
        $t = Resolve-LinkTarget $child.FullName
        if (-not $t) { continue }
        $parent = Split-Path -Parent (Split-Path -Parent $t)
        if (-not $targets.ContainsKey($parent)) { $targets[$parent] = $child.Name }
    }
    if ($targets.Count -eq 0) { Write-Host "  ($($root.Label) has no linked harness skills)" }
    foreach ($k in $targets.Keys) { Test-CheckoutCurrent $k "$($root.Label) (via $($targets[$k]))" }
}

# --- C. cached checkouts in sibling repos ------------------------------------------

Write-Section 'C. cached checkouts in sibling repos'
$repoParent = Split-Path -Parent $RepoRoot
$cacheHits = 0
foreach ($sibling in Get-ChildItem -Directory -LiteralPath $repoParent -ErrorAction SilentlyContinue) {
    $cacheDir = Join-Path $sibling.FullName '.harness-cache'
    if (-not (Test-Path -LiteralPath $cacheDir)) { continue }
    foreach ($cached in Get-ChildItem -Directory -LiteralPath $cacheDir -ErrorAction SilentlyContinue) {
        $cacheHits++
        if (-not (Test-Path -LiteralPath (Join-Path $cached.FullName '.git'))) {
            Add-Problem "$($sibling.Name)/.harness-cache/$($cached.Name)" 'exists but holds no usable checkout' 'delete it and let the generator re-clone'
            continue
        }
        Test-CheckoutCurrent $cached.FullName "$($sibling.Name)/.harness-cache/$($cached.Name)"
    }
}
if ($cacheHits -eq 0) { Write-Host '  (no sibling repo caches a checkout of the harness)' }

# --- D. stale-name sweep -----------------------------------------------------------

Write-Section 'D. stale-name sweep'
$sweepTargets = @()
if (Test-Path -LiteralPath $taskRoot) {
    $sweepTargets += (Get-ChildItem -Recurse -File -LiteralPath $taskRoot -Filter '*.md' -ErrorAction SilentlyContinue).FullName
}
$codexRulebook = Join-Path $HostHome '.codex\AGENTS.md'
if (Test-Path -LiteralPath $codexRulebook) { $sweepTargets += $codexRulebook }
$claudeStub = Join-Path $HostHome '.claude\CLAUDE.md'
if (Test-Path -LiteralPath $claudeStub) { $sweepTargets += $claudeStub }

$dirty = 0
foreach ($f in $sweepTargets) {
    if (Test-StaleNames $f ("stale name in " + ($f -replace [regex]::Escape($HostHome), '~'))) { $dirty++ }
}
Write-Host "  swept $($sweepTargets.Count) files; $dirty carry a pre-rename name"

# --- E. off-machine copies ---------------------------------------------------------

Write-Section 'E. off-machine copies'
$script:Notes += 'The Cowork / claude.ai account-side skill cache is NOT checked here and is not claimed clean. It holds its own copies of faruk, queue, sleep and status-report, it is not on this filesystem, and nothing in this repository writes to it. It refreshes only when the skills are re-uploaded to the account. Verify it by reading the skill descriptions a Cowork session actually reports and comparing them with skills/<name>/SKILL.md.'
Write-Host '  not reachable from this machine - reported, not passed'

# --- report ------------------------------------------------------------------------

Write-Host ''
foreach ($n in $script:Notes) { Write-Host "note: $n" -ForegroundColor DarkGray }

if ($script:Problems.Count -eq 0) {
    Write-Host 'skill caches: every reachable consumer is current.' -ForegroundColor Green
    exit 0
}

Write-Host ''
foreach ($p in $script:Problems) {
    Write-Host "DRIFT  $($p.Where)" -ForegroundColor Red
    Write-Host "       $($p.What)"
    Write-Host "       fix: $($p.Fix)"
}
Write-Host ''
Write-Host "$($script:Problems.Count) drifted consumer(s)." -ForegroundColor Red
exit 1
