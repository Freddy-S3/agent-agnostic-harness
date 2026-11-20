<#
.SYNOPSIS
  Tests the queue-runner boundary by constructing resumable and blocked states.

.DESCRIPTION
  The assertions are on the queue file and checkpoint, because those are the durable
  surfaces a fresh scheduled firing can read after usage, permission, network, or tool
  failure. The test also proves the runner selects one item rather than draining the
  queue and refuses a route that does not name exactly one Git repository.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$script:Failures = 0
$script:Ran = 0

function Assert($condition, $label) {
    $script:Ran++
    if ($condition) { return }
    $script:Failures++
    Write-Host "FAIL  $label" -ForegroundColor Red
}

function Assert-Eq($actual, $expected, $label) {
    Assert ($actual -eq $expected) "$label (expected '$expected', got '$actual')"
}

$testRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$runner = Join-Path $testRoot 'tools\queue-runner.ps1'
$repo = (Resolve-Path $testRoot).Path
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("queue-runner-tests-" + [guid]::NewGuid().ToString('n'))
$queueDir = Join-Path $root 'queue'
New-Item -ItemType Directory -Force -Path $queueDir | Out-Null

function Invoke-Runner([string[]]$Arguments) {
    $out = Join-Path $root ((New-Guid).ToString('n') + '.out')
    $err = Join-Path $root ((New-Guid).ToString('n') + '.err')
    try {
        $argv = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $runner) + @($Arguments | ForEach-Object {
            if ($_ -match '\s') { "`"$_`"" } else { $_ }
        })
        $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $argv -NoNewWindow -Wait -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
        return [pscustomobject]@{
            Code = $p.ExitCode
            Output = (Get-Content -Raw -ErrorAction SilentlyContinue $out)
            Error = (Get-Content -Raw -ErrorAction SilentlyContinue $err)
        }
    }
    finally { Remove-Item -LiteralPath $out, $err -Force -ErrorAction SilentlyContinue }
}

function Write-Queues([string]$phone, [string]$pc = '# Queue`n') {
    [System.IO.File]::WriteAllText((Join-Path $queueDir 'QUEUE-PHONE.md'), $phone)
    [System.IO.File]::WriteAllText((Join-Path $queueDir 'QUEUE-PC.md'), $pc)
}

function Json($result) {
    if ($result.Code -ne 0) { throw "runner failed ($($result.Code)): $($result.Output) $($result.Error)" }
    return $result.Output.Trim() | ConvertFrom-Json
}

Write-Host 'queue-runner.ps1 tests' -ForegroundColor Cyan

# --- 1. fan-out ordering and one-item claim -----------------------------------------
$phone = @(
    '# Queue', '',
    '## Low impact', 'Status: pending', "Repo: $repo", '',
    '## High impact', 'Status: pending', "Repo: $repo", '',
    '## Dependent work', 'Status: pending', "Repo: $repo", 'Depends on: High impact', ''
) -join "`n"
Write-Queues $phone
$r = Invoke-Runner @('start', '-QueueDir', $queueDir, '-Gate', 'phone', '-Session', 'runner-test')
$started = Json $r
Assert-Eq $started.item 'High impact' 'highest downstream impact is selected first'
Assert ((Get-Content -Raw (Join-Path $queueDir 'QUEUE-PHONE.md')) -match '(?m)^Status: in-progress\s*$') 'the selected item is marked in-progress'
Assert (Test-Path -LiteralPath $started.checkpoint) 'claim creates a checkpoint before work'
$checkpoint = Get-Content -Raw $started.checkpoint | ConvertFrom-Json
Assert-Eq $checkpoint.repo $repo 'checkpoint carries the one owning repository route'

# --- 2. checkpoint intent and clean pause/resume -------------------------------------
$r = Invoke-Runner @('checkpoint', '-QueueDir', $queueDir, '-RunId', $started.runId, '-Operation', 'push branch', '-Partial', 'branch may exist remotely', '-Discriminator', "git -C `"$repo`" status --short --branch", '-Phase', 'publish', '-NextAction', 'Inspect remote branch before retrying')
Assert-Eq $r.Code 0 'write-ahead intent is recorded'
$r = Invoke-Runner @('stop', '-QueueDir', $queueDir, '-RunId', $started.runId, '-Reason', 'network unavailable', '-NextAction', 'Retry the push from the publish phase')
$paused = Json $r
Assert-Eq $paused.status 'paused' 'stop leaves the run paused'
$checkpoint = Get-Content -Raw $started.checkpoint | ConvertFrom-Json
Assert-Eq $checkpoint.status 'paused' 'pause status is durable in the checkpoint'
Assert ((Get-Content -Raw (Join-Path $queueDir 'QUEUE-PHONE.md')) -match 'network unavailable') 'pause reason is logged in the queue'
$r = Invoke-Runner @('start', '-QueueDir', $queueDir, '-Gate', 'phone', '-Session', 'runner-test-resume')
$resumed = Json $r
Assert-Eq $resumed.item 'High impact' 'an in-progress item is resumed before pending work'
Assert-Eq $resumed.runId $started.runId 'resume keeps the same run identity'
Assert-Eq $resumed.phase 'publish' 'resume returns the last checkpoint phase'

# --- 3. finish requires bounded verification and a PR handoff ------------------------
$r = Invoke-Runner @('checkpoint', '-QueueDir', $queueDir, '-RunId', $started.runId, '-Operation', 'retry push', '-Partial', 'the branch may already exist remotely', '-Discriminator', "git -C `"$repo`" ls-remote --heads origin", '-Phase', 'publish', '-NextAction', 'Verify the remote branch before opening the PR')
Assert-Eq $r.Code 0 'a resumed run opens a new intent for the retry'
$r = Invoke-Runner @('checkpoint', '-QueueDir', $queueDir, '-RunId', $started.runId, '-Outcome', 'done', '-Reason', 'push completed')
Assert-Eq $r.Code 0 'write-ahead intent can be closed with an outcome'
$r = Invoke-Runner @('finish', '-QueueDir', $queueDir, '-RunId', $started.runId, '-Verification', 'tools/tests/queue-runner.tests.ps1 exit 0', '-PullRequest', 'not-a-pr')
Assert-Eq $r.Code 4 'finish rejects a missing PR handoff'
$r = Invoke-Runner @('finish', '-QueueDir', $queueDir, '-RunId', $started.runId, '-Verification', 'tools/tests/queue-runner.tests.ps1 exit 0', '-PullRequest', 'https://github.com/example/repo/pull/1')
$finished = Json $r
Assert-Eq $finished.status 'done' 'finish marks the item done'
$phoneAfter = Get-Content -Raw (Join-Path $queueDir 'QUEUE-PHONE.md')
Assert ($phoneAfter -match '(?m)^Status: done\s*$') 'done state is persisted'
Assert ($phoneAfter -match 'bounded verification') 'finish records the verification path'
Assert ($phoneAfter -match 'merge and public release remain human-gated') 'finish records the human gate'

# --- 4. exactly one owning repository is required ------------------------------------
$invalid = @('# Queue', '', '## Ambiguous route', 'Status: pending', "Repo: $repo and another-repo", '') -join "`n"
Write-Queues $invalid
$r = Invoke-Runner @('start', '-QueueDir', $queueDir, '-Gate', 'phone')
Assert-Eq $r.Code 3 'an ambiguous repository route is refused'
Assert ($r.Output -match 'owning repository') 'route failure explains the contract'
Assert ((Get-Content -Raw (Join-Path $queueDir 'QUEUE-PHONE.md')) -match '(?m)^Status: pending\s*$') 'invalid route is not marked in-progress'

# --- 5. no actionable item is a quiet stop -------------------------------------------
Write-Queues "# Queue`n`n## External work`nStatus: pending`nRepo: none`n"
$r = Invoke-Runner @('start', '-QueueDir', $queueDir, '-Gate', 'phone')
Assert-Eq $r.Code 3 'an unroutable pending item is surfaced rather than skipped'

Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
if ($script:Failures -eq 0) {
    Write-Host "$($script:Ran) assertions passed" -ForegroundColor Green
    exit 0
}
Write-Host "$($script:Failures) of $($script:Ran) assertions FAILED" -ForegroundColor Red
exit 1
