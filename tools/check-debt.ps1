<#
.SYNOPSIS
  Report agent-generated debt: things this harness created and then stopped using. Proposes
  removals; never removes anything.

.DESCRIPTION
  /learn only adds. Every incident produces a new rule, a new check, a new skill, a new
  worktree, and nothing in the harness has ever been responsible for noticing that
  something stopped being used. Ng names this directly as agent-generated debt.

  This reports six classes:

    A. Orphaned scheduled-task prompts - a prompt directory under ~/.claude/scheduled-tasks
       with no Windows scheduled task behind it. The prompt looks live, is maintained by
       check-skill-caches.ps1, and nothing ever runs it.
    B. Merged worktrees - a git worktree whose branch is fully contained in origin/main.
       Its work has landed; the tree is a checkout nobody needs, and a stale checkout is
       not inert. One 29 commits behind produced a wrong answer about a file's existence.
    C. Stale harness caches - .harness-cache checkouts in sibling repositories that are
       behind their origin.
    D. Long-unused skills - a skill no instruction file, router, or other skill points at.
       Nothing can route to it, so only a typed slash command reaches it.
    E. Dangling rule references - a rules/ file that AGENTS.md never triggers. The mirror
       of what check-rule-triggers.ps1 catches: that one finds triggers with no file, this
       finds files with no trigger.
    F. Orphaned templates - a templates/scheduled-tasks entry with no installed task and no
       scheduled task of that name anywhere.

  IT NEVER DELETES. Not with a -Fix flag, not with -Force, because there is no such flag.
  This harness has already lost a skill file to an over-eager cleanup, and a reporter that
  can also delete is one bad heuristic away from repeating that. Every finding prints the
  exact command a human would run, and a human runs it.

  A finding is a proposal, not a verdict. Several classes here are genuinely ambiguous - a
  skill nothing points at may be deliberately user-invoked-only, and a worktree whose branch
  has merged may be where someone is working right now. The output says which class each
  finding belongs to so the reader can apply that judgement, and says nothing about
  confidence it does not have.

.PARAMETER RepoRoot
  Harness repository root. Defaults to the parent of this script's directory.

.PARAMETER HostHome
  Home directory holding ~/.claude. Defaults to the current user's profile.

.PARAMETER Class
  Report only one class (A-F). Everything by default.

.EXAMPLE
  powershell -NoProfile -File tools\check-debt.ps1
  powershell -NoProfile -File tools\check-debt.ps1 -Class B
#>
[CmdletBinding()]
param(
    [string] $RepoRoot,
    [string] $HostHome = $env:USERPROFILE,
    [ValidateSet('A', 'B', 'C', 'D', 'E', 'F')]
    [string] $Class
)

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }

$findings = New-Object System.Collections.Generic.List[object]

function Add-Finding($class, $what, $why, $proposal) {
    $findings.Add([pscustomobject]@{ Class = $class; What = $what; Why = $why; Proposal = $proposal })
}

function Want($c) { return (-not $Class) -or ($Class -eq $c) }

function Invoke-Git($gitArgs, $cwd = $RepoRoot) {
    $o = New-TemporaryFile
    $e = New-TemporaryFile
    try {
        $p = Start-Process -FilePath 'git' -ArgumentList (@('-C', "`"$cwd`"") + $gitArgs) `
                -RedirectStandardOutput $o.FullName -RedirectStandardError $e.FullName `
                -NoNewWindow -PassThru -Wait
        $out = Get-Content -LiteralPath $o.FullName -Raw -ErrorAction SilentlyContinue
        # Coerced to a single string: an empty file yields $null and a multi-value read yields
        # an array, and both reach .Trim() at the call sites.
        return @{ code = $p.ExitCode; out = ([string]($out | Out-String) -replace "`r", '') }
    } finally {
        foreach ($f in $o, $e) { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue }
    }
}

# --- A. orphaned scheduled-task prompts ---------------------------------------------
if (Want 'A') {
    $taskRoot = Join-Path $HostHome '.claude\scheduled-tasks'
    if (Test-Path -LiteralPath $taskRoot) {
        # schtasks is the authority on what actually fires. Its absence is reported rather
        # than assumed to mean "no tasks", because assuming that would flag every prompt.
        # A Windows machine always has system tasks, so an EMPTY successful enumeration means
        # the enumeration failed, not that nothing is scheduled. Treating empty as authoritative
        # flags every prompt on the strength of a tool that did not work - an absence of
        # evidence promoted to a fact, which is the failure instructions/rules/
        # premise-interrogation.md exists to catch. Seen for real: under Git Bash, MSYS path
        # conversion rewrites /query into a drive path and schtasks returns nothing at all.
        $known = $null
        try {
            $raw = & schtasks /query /fo csv /nh 2>$null
            if ($LASTEXITCODE -eq 0) {
                $text = ($raw | Out-String)
                if ($text.Trim().Length -gt 0) { $known = $text }
            }
        } catch { $known = $null }

        foreach ($d in Get-ChildItem -Directory -LiteralPath $taskRoot -ErrorAction SilentlyContinue) {
            if ($null -eq $known) {
                Add-Finding 'A' "~/.claude/scheduled-tasks/$($d.Name)" `
                    'UNVERIFIED - schtasks returned no tasks at all, so this run could not tell whether a task backs this prompt. Not evidence of an orphan.' `
                    "run from a real PowerShell console, not Git Bash: schtasks /query /tn `"$($d.Name)`""
                continue
            }
            if ($known -notmatch [regex]::Escape($d.Name)) {
                Add-Finding 'A' "~/.claude/scheduled-tasks/$($d.Name)" `
                    'no Windows scheduled task carries this name, so this prompt is maintained by check-skill-caches.ps1 and never runs' `
                    "confirm with: schtasks /query /tn `"$($d.Name)`"  then, if genuinely dead: Remove-Item -Recurse `"$($d.FullName)`""
            }
        }
    }
}

# --- B. worktrees whose branch has already landed -----------------------------------
if (Want 'B') {
    $wt = Invoke-Git @('worktree', 'list', '--porcelain')
    if ($wt.code -eq 0) {
        $current = @{}
        foreach ($line in ($wt.out -split "`n")) {
            if ($line -match '^worktree (.+)$')      { $current = @{ path = $Matches[1] } }
            elseif ($line -match '^branch refs/heads/(.+)$') { $current['branch'] = $Matches[1] }
            elseif ($line -eq '') {
                if ($current.path -and $current.branch) {
                    $b = $current.branch
                    $p = $current.path
                    # The default branch is not debt, and the clone that holds it is the one
                    # every junction points at. An earlier run proposed removing it.
                    if ($b -eq 'main' -or $b -eq 'master') { $current = @{}; continue }
                    if ($p -replace '/', '\' -eq ($RepoRoot -replace '/', '\')) { $current = @{}; continue }
                    $behind = Invoke-Git @('rev-list', '--count', "origin/main..$b")
                    $dirty  = Invoke-Git @('status', '--porcelain') $p
                    if ($behind.code -eq 0 -and $behind.out.Trim() -eq '0') {
                        $note = if ($dirty.out.Trim()) { ' - HAS UNCOMMITTED CHANGES, read them before removing' } else { '' }
                        Add-Finding 'B' $p "branch '$b' is fully contained in origin/main, so its work has landed$note" `
                            "git worktree remove `"$p`"  then: git branch -d $b"
                    }
                }
                $current = @{}
            }
        }
    }
}

# --- C. stale harness caches in sibling repositories --------------------------------
if (Want 'C') {
    $siblings = Split-Path -Parent $RepoRoot
    foreach ($repo in Get-ChildItem -Directory -LiteralPath $siblings -ErrorAction SilentlyContinue) {
        $cache = Join-Path $repo.FullName '.harness-cache\agent-agnostic-harness'
        if (-not (Test-Path -LiteralPath (Join-Path $cache '.git'))) { continue }
        $b = Invoke-Git @('rev-list', '--count', 'HEAD..origin/main') $cache
        if ($b.code -eq 0 -and $b.out.Trim() -ne '0' -and $b.out.Trim() -ne '') {
            Add-Finding 'C' $cache "$($b.out.Trim()) commits behind origin/main" `
                "git -C `"$cache`" fetch origin; git -C `"$cache`" merge --ff-only origin/main"
        }
    }
}

# --- D. skills nothing points at -----------------------------------------------------
if (Want 'D') {
    $skillsDir = Join-Path $RepoRoot 'skills'
    if (Test-Path -LiteralPath $skillsDir) {
        # Read every .md and .ps1 once, keeping the path with the text, so a skill's own
        # files can be excluded when counting references to it. An earlier version split one
        # concatenated blob on a marker line and mis-attributed text to the wrong file, which
        # reported /voice as unreferenced while skills/wiki/SKILL.md plainly references it.
        $docs = @()
        foreach ($f in Get-ChildItem -LiteralPath $RepoRoot -Recurse -Include '*.md', '*.ps1' -ErrorAction SilentlyContinue) {
            if ($f.FullName -like '*\.git\*') { continue }
            $docs += [pscustomobject]@{
                Path = $f.FullName
                Text = (Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue)
            }
        }

        foreach ($sk in Get-ChildItem -Directory -LiteralPath $skillsDir) {
            $name = $sk.Name
            $own  = [regex]::Escape((Join-Path $skillsDir $name))
            $hits = @($docs | Where-Object {
                $_.Path -notmatch "^$own" -and $_.Text -match [regex]::Escape($name)
            })
            if ($hits.Count -eq 0) {
                Add-Finding 'D' "skills/$name" `
                    'no instruction file, router, rule or other skill mentions it anywhere, so nothing can route to it and only a typed slash command reaches it' `
                    "decide whether it is deliberately user-invoked-only; if not, either reference it from a router or: git rm -r skills/$name"
            }
        }
    }
}

# --- E. rule files nothing triggers ---------------------------------------------------
if (Want 'E') {
    $rulesDir = Join-Path $RepoRoot 'instructions\rules'
    $corePath = Join-Path $RepoRoot 'instructions\AGENTS.md'
    if ((Test-Path -LiteralPath $rulesDir) -and (Test-Path -LiteralPath $corePath)) {
        $core = Get-Content -LiteralPath $corePath -Raw -Encoding UTF8
        foreach ($r in Get-ChildItem -LiteralPath $rulesDir -Filter '*.md') {
            if ($r.Name -eq 'README.md') { continue }
            if ($core -notmatch [regex]::Escape($r.Name)) {
                Add-Finding 'E' "instructions/rules/$($r.Name)" `
                    'AGENTS.md never triggers it, so no session will read it - the mirror of the dangling reference check-rule-triggers.ps1 catches' `
                    "add a trigger row to instructions/AGENTS.md, or: git rm instructions/rules/$($r.Name)"
            }
        }
    }
}

# --- F. templates with no installed task ----------------------------------------------
if (Want 'F') {
    $templateRoot = Join-Path $RepoRoot 'templates\scheduled-tasks'
    $taskRoot     = Join-Path $HostHome '.claude\scheduled-tasks'
    if (Test-Path -LiteralPath $templateRoot) {
        foreach ($t in Get-ChildItem -Directory -LiteralPath $templateRoot) {
            if (-not (Test-Path -LiteralPath (Join-Path $taskRoot $t.Name))) {
                Add-Finding 'F' "templates/scheduled-tasks/$($t.Name)" `
                    'no installed task of this name on this machine - it may be installed elsewhere, so this is the weakest signal here' `
                    "check your other machines before acting; this is reported, not recommended"
            }
        }
    }
}

# --- report ---------------------------------------------------------------------------
$labels = @{
    A = 'orphaned scheduled-task prompts'
    B = 'worktrees whose branch already landed'
    C = 'stale harness caches'
    D = 'skills nothing references'
    E = 'rule files nothing triggers'
    F = 'templates with no installed task'
}

Write-Host 'agent-generated debt' -ForegroundColor Cyan
Write-Host '  proposals only - this script deletes nothing and has no flag that would'
Write-Host ''

if ($findings.Count -eq 0) {
    Write-Host '  nothing to prune' -ForegroundColor Green
    exit 0
}

foreach ($c in 'A', 'B', 'C', 'D', 'E', 'F') {
    $group = @($findings | Where-Object { $_.Class -eq $c })
    if ($group.Count -eq 0) { continue }
    Write-Host ("{0}. {1} ({2})" -f $c, $labels[$c], $group.Count) -ForegroundColor Yellow
    foreach ($f in $group) {
        Write-Host "   $($f.What)"
        Write-Host "     why:     $($f.Why)" -ForegroundColor DarkGray
        Write-Host "     propose: $($f.Proposal)" -ForegroundColor DarkGray
    }
    Write-Host ''
}

Write-Host ("{0} proposal(s). Nothing was removed." -f $findings.Count)
Write-Host 'Read each one before acting: a skill nothing points at may be deliberately'
Write-Host 'user-invoked-only, and a landed worktree may be where someone is working now.'

# Exit 0: this is a report, not a gate. A pruning pass that fails a build would get muted,
# and a muted report is worse than none because people believe it is running.
exit 0
