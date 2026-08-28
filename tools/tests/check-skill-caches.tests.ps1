<#
.SYNOPSIS
  Tests for tools/check-skill-caches.ps1, driven by constructing the drift.

.DESCRIPTION
  A drift check that has only ever been observed passing is the same artifact as no
  check. Each case below builds a fake host home in a temp directory, puts a consumer
  into the exact broken state this script exists to catch, and asserts on the exit code
  and the message.

.EXAMPLE
  powershell -NoProfile -File tools\tests\check-skill-caches.tests.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$script:Failures = 0
$script:Ran = 0

function Assert($condition, $label, $context) {
    $script:Ran++
    if ($condition) { return }
    $script:Failures++
    Write-Host "FAIL  $label" -ForegroundColor Red
    if ($context) { Write-Host ($context -split "`n" | ForEach-Object { "      $_" }) -ForegroundColor DarkGray }
}

$checker = Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) 'check-skill-caches.ps1'
$repoRoot = Split-Path -Parent (Split-Path -Parent $checker)
if (-not (Test-Path $checker)) { throw "check-skill-caches.ps1 not found at $checker" }

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("cache-tests-" + [guid]::NewGuid().ToString('n').Substring(0, 8))

function New-Home {
    $h = Join-Path $root ([guid]::NewGuid().ToString('n').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path (Join-Path $h '.claude\scheduled-tasks\queue-runner') | Out-Null
    return $h
}

function Invoke-Check($hostHome, $extra) {
    $a = @('-NoProfile', '-File', $checker, '-RepoRoot', $repoRoot, '-HostHome', $hostHome)
    if ($extra) { $a += $extra }
    $o = New-TemporaryFile
    $e = New-TemporaryFile
    try {
        $p = Start-Process -FilePath 'powershell' -ArgumentList $a `
            -RedirectStandardOutput $o -RedirectStandardError $e -NoNewWindow -PassThru -Wait
        return [pscustomobject]@{
            Code   = $p.ExitCode
            Output = ((Get-Content -Raw -LiteralPath $o) + "`n" + (Get-Content -Raw -LiteralPath $e))
        }
    }
    finally { Remove-Item -LiteralPath $o, $e -Force -ErrorAction SilentlyContinue }
}

Write-Host 'check-skill-caches.ps1 tests' -ForegroundColor Cyan

$template = Join-Path $repoRoot 'templates\scheduled-tasks\queue-runner\SKILL.md'
Assert (Test-Path $template) 'the queue-runner template is tracked in this repo'

# --- 1. the real historical drift, reconstructed ------------------------------------
# This is verbatim the shape the installed prompt was in: the pre-rename repository name
# and a single queue/QUEUE.md that no longer exists.
$h = New-Home
$dst = Join-Path $h '.claude\scheduled-tasks\queue-runner\SKILL.md'
Set-Content -LiteralPath $dst -Encoding utf8 -Value @'
---
name: queue-runner
---
Invoke the /queue skill from the claude-harness harness (see C:\Users\Faruk\Repo\claude-harness\skills\queue\SKILL.md).
Read C:\Users\Faruk\Repo\claude-harness\queue\QUEUE.md and take the first pending item.
'@
$r = Invoke-Check $h
Assert ($r.Code -eq 1) 'a drifted scheduled-task prompt fails the check'
Assert ($r.Output -match 'pre-2026-08-12 repository name') 'the old repository name is named in the failure'
Assert ($r.Output -match 'pre-split single queue file') 'the old single queue file is named in the failure'
Assert ($r.Output -match 'differs from its template') 'the template mismatch is reported'

# --- 2. -Fix repairs it, and the repair is idempotent --------------------------------
$r = Invoke-Check $h @('-Fix')
Assert ($r.Output -match 'REWRITTEN from template') '-Fix rewrites the drifted prompt'
$r = Invoke-Check $h
Assert ($r.Code -eq 0) 'after -Fix the check passes' $r.Output
Assert ($r.Output -match 'queue-runner: current') 'after -Fix the prompt reports current'
$r = Invoke-Check $h @('-Fix')
Assert ($r.Output -notmatch 'REWRITTEN') '-Fix on a current prompt changes nothing'

# --- 3. the queue DATA directory is not treated as a stale repo name -----------------
# ~/.claude-harness/ is named after the old repo on purpose and was deliberately left
# alone. A check that flags it would relitigate a settled decision on every run.
$h2 = New-Home
Copy-Item -LiteralPath $template -Destination (Join-Path $h2 '.claude\scheduled-tasks\queue-runner\SKILL.md')
New-Item -ItemType Directory -Force -Path (Join-Path $h2 '.codex') | Out-Null
Set-Content -LiteralPath (Join-Path $h2 '.codex\AGENTS.md') -Encoding utf8 -Value 'Queue data lives in ~/.claude-harness/queue/ outside any repo.'
$r = Invoke-Check $h2
Assert ($r.Code -eq 0) 'the ~/.claude-harness data directory is not flagged as a stale repo name' $r.Output

# --- 4. a link into a stale checkout fails, even though it resolves ------------------
# The weaker question - does the link resolve - is the one that reports success during an
# outage. Constructed with a worktree deliberately left one commit behind.
$stale = Join-Path $root 'stale-checkout'
& git -C $repoRoot worktree add --detach $stale 'HEAD~1' | Out-Null
if (Test-Path $stale) {
    $h3 = New-Home
    Copy-Item -LiteralPath $template -Destination (Join-Path $h3 '.claude\scheduled-tasks\queue-runner\SKILL.md')
    & cmd /c mklink /J "$(Join-Path $h3 '.claude\skills')" "$(Join-Path $stale 'skills')" | Out-Null
    $r = Invoke-Check $h3
    Assert ($r.Code -eq 1) 'a link into a behind-origin checkout fails the check'
    Assert ($r.Output -match 'commits behind origin/main') 'the failure says how far behind the checkout is'
    Remove-Item -LiteralPath (Join-Path $h3 '.claude\skills') -Force -Recurse -ErrorAction SilentlyContinue
    & git -C $repoRoot worktree remove --force $stale | Out-Null
}
else {
    Write-Host 'SKIP  stale-checkout case: could not create a worktree' -ForegroundColor Yellow
}

# --- 5. the off-machine cache is never claimed clean ---------------------------------
$r = Invoke-Check $h2
Assert ($r.Output -match 'not reachable from this machine') 'the account-side cache is reported rather than passed'
Assert ($r.Output -notmatch 'every reachable consumer is current[\s\S]*Cowork') 'the pass line does not cover the unreachable cache'

Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ''
if ($script:Failures -eq 0) {
    Write-Host "$($script:Ran) assertions passed" -ForegroundColor Green
    exit 0
}
Write-Host "$($script:Failures) of $($script:Ran) assertions FAILED" -ForegroundColor Red
exit 1
