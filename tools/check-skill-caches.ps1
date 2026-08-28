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
    E. The Cowork skill cache, materialised per workspace under
       %APPDATA%\Claude\local-agent-mode-sessions\skills-plugin\. This one DOES refresh
       - but it refreshes from the claude.ai account, not from this repository, so a
       user-authored skill goes stale in the account and the refresh faithfully
       re-materialises the stale copy. Checked and reported; deliberately not fixed,
       because a local rewrite is overwritten on the next materialisation and the repair
       is an account-side re-upload.

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
    [string]$HostHome,
    [string]$CoworkRoot
)

$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent $PSScriptRoot }
if (-not $HostHome) { $HostHome = $env:USERPROFILE }
if (-not $HostHome) { $HostHome = $HOME }

$script:Problems = @()
$script:Notes = @()

function Add-Problem($where, $what, $fix) {
    # One defect, one line. A stale name that appears on six lines of a file is still one
    # thing to fix, and a report that repeats it buries the other findings.
    foreach ($p in $script:Problems) { if ($p.Where -eq $where -and $p.What -eq $what) { return } }
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

function Test-StaleNames($path, $label, $fix) {
    if (-not $fix) { $fix = 'regenerate this copy from the repository' }
    $text = Get-Content -Raw -LiteralPath $path -ErrorAction SilentlyContinue
    if (-not $text) { return $false }
    $found = $false
    foreach ($line in ($text -split "`n")) {
        if ($line -match $staleAllowed) { continue }
        foreach ($t in $staleTokens) {
            if ($line -match $t.Pattern) {
                Add-Problem $label "names $($t.Means)" $fix
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

Write-Section 'E. Cowork skill cache'

function Get-FrontmatterDescription($path) {
    # Parsed line by line rather than with one big regex: the frontmatter block is
    # trivially delimited, and a regex over the whole file is the kind of thing that
    # silently returns nothing and makes the check pass by accident.
    $text = Get-Content -Raw -LiteralPath $path -ErrorAction SilentlyContinue
    if (-not $text) { return $null }
    $lines = $text -split "`r?`n"
    if ($lines.Count -eq 0) { return $null }
    if ($lines[0].TrimStart([char]0xFEFF).Trim() -ne '---') { return $null }
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '---') { break }
        if ($lines[$i] -match '^\s*description:\s*(.+?)\s*$') {
            return $Matches[1].Trim('"').Trim("'")
        }
    }
    return $null
}

$pluginRoot = Join-Path $env:APPDATA 'Claude\local-agent-mode-sessions\skills-plugin'
if ($CoworkRoot) { $pluginRoot = $CoworkRoot }

if (-not $pluginRoot -or -not (Test-Path -LiteralPath $pluginRoot)) {
    Write-Host '  (no Cowork skill cache on this machine)'
}
else {
    $manifests = @(Get-ChildItem -Recurse -File -LiteralPath $pluginRoot -Filter 'manifest.json' -ErrorAction SilentlyContinue)
    if ($manifests.Count -eq 0) { Write-Host '  (Cowork cache present but holds no manifest)' }
    foreach ($m in $manifests) {
        $workspace = Split-Path -Leaf (Split-Path -Parent $m.FullName)
        $manifest = $null
        try { $manifest = Get-Content -Raw -LiteralPath $m.FullName | ConvertFrom-Json } catch { }
        if (-not $manifest) {
            Add-Problem "Cowork cache $workspace" 'manifest.json is unreadable' 'let Cowork re-materialise the cache'
            continue
        }
        foreach ($entry in @($manifest.skills)) {
            # Anthropic-authored skills are not ours and are not compared.
            if ($entry.creatorType -ne 'user') { continue }
            $repoSkill = Join-Path (Join-Path $RepoRoot 'skills') (Join-Path $entry.name 'SKILL.md')
            if (-not (Test-Path -LiteralPath $repoSkill)) {
                Write-Host "  $($entry.name): uploaded to the account but absent from this repo"
                continue
            }
            $label = "Cowork cache $workspace / $($entry.name)"
            $accountFix = 're-upload this skill to the claude.ai account - rewriting the local cache is overwritten on the next materialisation'
            $drifted = $false

            # The manifest description is what the model routes on, so a stale one sends a
            # Cowork session to the wrong skill before any file is read.
            $repoDesc = Get-FrontmatterDescription $repoSkill
            if ($repoDesc -and $entry.description -ne $repoDesc) {
                Add-Problem $label "the account's copy was last updated $($entry.updatedAt) and its description no longer matches skills/$($entry.name)/SKILL.md" $accountFix
                $drifted = $true
            }

            # The body matters too, and a matching description does not imply one. Compare
            # the materialised file, and sweep it for the pre-rename names separately, so a
            # copy that drifted without changing its summary line is still caught.
            $cached = Join-Path (Join-Path (Split-Path -Parent $m.FullName) 'skills') (Join-Path $entry.name 'SKILL.md')
            if (Test-Path -LiteralPath $cached) {
                $a = ((Get-Content -Raw -LiteralPath $cached) -replace "`r`n", "`n").TrimEnd()
                $b = ((Get-Content -Raw -LiteralPath $repoSkill) -replace "`r`n", "`n").TrimEnd()
                if ($a -ne $b) {
                    Add-Problem $label "the materialised SKILL.md body differs from skills/$($entry.name)/SKILL.md" $accountFix
                    $drifted = $true
                }
                if (Test-StaleNames $cached $label $accountFix) { $drifted = $true }
            }

            if (-not $drifted) { Write-Host "  $($entry.name): matches this repo" }
        }
    }
    $script:Notes += 'The Cowork cache refreshes from the claude.ai account, not from this repository. A user-authored skill that has gone stale in the account is re-materialised stale on every refresh, so a mismatch here is repaired by re-uploading the skill, never by editing the cache.'
}

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
