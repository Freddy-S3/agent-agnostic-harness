<#
.SYNOPSIS
  Bounded convergence step for a single queue item: run its exit predicate, account for
  the iteration, and block the item when the cap trips.

.DESCRIPTION
  /queue advances one item per firing. A nearly-done item has no honest status: 'done' is
  a lie, 'blocked' invents a decision Faruk does not have, and 'in-progress' treats
  resumption as an exception rather than the plan. The missing construct is a second and
  third attempt at the SAME item, bounded, gated on a check that actually ran.

  This script is that gate. It is deliberately not the loop - the loop is the agent
  re-entering the item's brief with a fresh context window, which no script can do. What
  the script owns is everything a prose contract cannot enforce:

    - The predicate is a COMMAND that runs and returns an exit code. A loop whose exit
      condition is the model's own opinion of doneness is the failure mode this exists to
      prevent, so an item whose 'Done when:' reads as prose is rejected rather than
      charitably interpreted.
    - The iteration count is written to the queue file BEFORE the next attempt, not after
      it succeeds. A session killed on a usage limit mid-iteration resumes with an
      accurate count, on the same terms as any other interrupted /queue run.
    - The cap has defined behaviour: it persists a blocked entry carrying the predicate's
      actual failing output, and stops. Not 'silently give up', not 'keep going'.
    - Predicate output is silent on success and surfaced only on failure, so a passing
      check costs the next iteration's context window nothing.

  Backward compatible: an item with no 'Done when:' line returns 'no-predicate' and
  /queue behaves exactly as it did before - one pass, then done.

.PARAMETER Action
  step   - run the predicate for one item and account for the result.
  status - print an item's predicate, iteration count, and remaining budget.
  reset  - clear the per-run counter for a session (used when an item reaches done).

.EXAMPLE
  .\converge.ps1 step -Queue $q -Item 'Fix the dead route button' -Session sess-1
  .\converge.ps1 status -Queue $q -Item 'Fix the dead route button'

.NOTES
  Exit codes:
    0 converged        - the predicate passed. Mark the item done.
    0 no-predicate     - the item declares no 'Done when:'. Legacy behaviour.
    6 reiterate        - the predicate failed and budget remains. Re-enter the brief with
                         a fresh context window.
    7 capped           - the predicate failed and the cap tripped. The item has been set
                         to blocked with the failing output. Move to the next item.
    4 usage            - bad arguments, missing item, or a prose 'Done when:'.
    5 conflict         - the queue file changed under us. Re-read and re-decide.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet('step', 'status', 'reset')]
    [string]$Action,

    [Parameter(Mandatory)]
    [string]$Queue,

    [Parameter(Mandatory)]
    [string]$Item,

    [string]$Session = 'default',

    [int]$PerRunCap = 3,

    [int]$TotalCap = 5,

    [int]$MaxOutputLines = 40,

    [string]$StateDir
)

$ErrorActionPreference = 'Stop'

$EXIT_OK        = 0
$EXIT_USAGE     = 4
$EXIT_CONFLICT  = 5
$EXIT_REITERATE = 6
$EXIT_CAPPED    = 7

function Fail($message) {
    # Write-Error under ErrorActionPreference=Stop is terminating and would exit 1, which
    # a caller cannot tell apart from the predicate itself failing.
    [Console]::Error.WriteLine($message)
    exit $EXIT_USAGE
}

function Get-StateDir {
    if ($StateDir) { return $StateDir }
    if ($env:CLAUDE_HARNESS_CONVERGE_DIR) { return $env:CLAUDE_HARNESS_CONVERGE_DIR }
    return (Join-Path $HOME '.claude-harness\converge')
}

function Get-RunCounterPath {
    $dir = Get-StateDir
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $key = "$Session|$((Resolve-Path $Queue).Path)|$Item".ToLowerInvariant()
    $hash = ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($key)) | ForEach-Object { $_.ToString('x2') }) -join ''
    return (Join-Path $dir "$($hash.Substring(0, 24)).count")
}

function Get-RunCount {
    $p = Get-RunCounterPath
    if (-not (Test-Path $p)) { return 0 }
    $raw = (Get-Content -Raw -LiteralPath $p).Trim()
    $n = 0
    if ([int]::TryParse($raw, [ref]$n)) { return $n }
    return 0
}

function Set-RunCount($n) {
    [System.IO.File]::WriteAllText((Get-RunCounterPath), [string]$n)
}

function Get-Shell {
    $p = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($p) { return $p.Source }
    return 'powershell'
}

function Get-Fingerprint($p) {
    $bytes = [System.IO.File]::ReadAllBytes($p)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    return ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join ''
}

# --- item location -----------------------------------------------------------------

if (-not (Test-Path $Queue)) { Fail "Queue file not found: $Queue" }

# Fingerprint taken at read time, not at write time: the predicate itself runs between
# the two, and a peer that appends while it runs must be a conflict rather than a lost
# update.
$lines = [System.IO.File]::ReadAllLines($Queue)
$fingerprintAtRead = Get-Fingerprint $Queue

$headings = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^##\s+(.+?)\s*$') { $headings += [pscustomobject]@{ Index = $i; Title = $Matches[1] } }
}

$matched = @($headings | Where-Object { $_.Title -eq $Item })
if ($matched.Count -eq 0) { Fail "No queue item titled '$Item' in $Queue." }
if ($matched.Count -gt 1) { Fail "Queue item title '$Item' is ambiguous - $($matched.Count) entries match. Titles are the match key; rename one." }

$start = $matched[0].Index
$end = $lines.Count - 1
foreach ($h in $headings) { if ($h.Index -gt $start) { $end = $h.Index - 1; break } }

# --- field parsing -----------------------------------------------------------------
# The field block is the contiguous run of 'Name:' lines under the heading. The queue
# dashboard's own parser ends a field at the next line matching this shape, so anything
# written outside the block is absorbed into the description and rendered as prose on
# Faruk's phone. Writes below therefore go INSIDE the block, never after the brief.

$fieldPattern = '^[A-Z][a-z]+ ?[a-z]*:'

$fieldEnd = $start
for ($i = $start + 1; $i -le $end; $i++) {
    if ($lines[$i] -match $fieldPattern) { $fieldEnd = $i }
    elseif ($lines[$i].Trim() -eq '') { continue }
    else { break }
}

function Get-Field($name) {
    for ($i = $start + 1; $i -le $fieldEnd; $i++) {
        if ($lines[$i] -match "^$([regex]::Escape($name)):\s*(.*)$") { return $Matches[1].Trim() }
    }
    return $null
}

function Get-FieldIndex($name) {
    for ($i = $start + 1; $i -le $fieldEnd; $i++) {
        if ($lines[$i] -match "^$([regex]::Escape($name)):") { return $i }
    }
    return -1
}

$predicate = Get-Field 'Done when'
$iterRaw = Get-Field 'Iterations'
$iterations = 0
if ($iterRaw) { [void][int]::TryParse($iterRaw, [ref]$iterations) }

# --- predicate validation ----------------------------------------------------------
# 'Done when:' is a reward function. Prose here is the whole failure mode: it reads as a
# gate and enforces nothing, and the loop reaches it by declaring itself finished.

function Test-IsProse($text) {
    if (-not $text) { return $false }
    if ($text -match '^`.*`$') { return $false }
    $words = @($text -split '\s+' | Where-Object { $_ })
    # A command's first token is an executable or a path, never a sentence opener, and a
    # command does not end in a full stop.
    if ($text -match '\.\s*$') { return $true }
    if ($words[0] -match '^(the|a|an|all|every|no|when|until|it|there|ensure|make|verify|confirm|check)$') { return $true }
    if ($words.Count -gt 25) { return $true }
    return $false
}

# --- status ------------------------------------------------------------------------

if ($Action -eq 'status') {
    $runCount = Get-RunCount
    if (-not $predicate) {
        Write-Output 'no-predicate'
        exit $EXIT_OK
    }
    Write-Output "predicate: $predicate"
    Write-Output "iterations: $iterations / $TotalCap total, $runCount / $PerRunCap this run"
    exit $EXIT_OK
}

if ($Action -eq 'reset') {
    $p = Get-RunCounterPath
    if (Test-Path $p) { Remove-Item -LiteralPath $p -Force }
    Write-Output 'reset'
    exit $EXIT_OK
}

# --- step --------------------------------------------------------------------------

if (-not $predicate) {
    Write-Output 'no-predicate'
    exit $EXIT_OK
}

if (Test-IsProse $predicate) {
    Fail @"
'Done when:' on '$Item' is prose, not a runnable command:
    $predicate
A convergence loop whose exit condition is the agent's own opinion of doneness is the
failure this gate exists to prevent. Replace it with a command whose exit code defines
completion, or remove the field and let the item run once.
"@
}

$command = $predicate -replace '^`', '' -replace '`$', ''

$stdout = New-TemporaryFile
$stderr = New-TemporaryFile
try {
    $proc = Start-Process -FilePath (Get-Shell) `
        -ArgumentList @('-NoProfile', '-NonInteractive', '-Command', $command) `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr `
        -NoNewWindow -PassThru -Wait
    $code = $proc.ExitCode
    $output = @()
    $output += @(Get-Content -LiteralPath $stdout -ErrorAction SilentlyContinue)
    $output += @(Get-Content -LiteralPath $stderr -ErrorAction SilentlyContinue)
}
finally {
    Remove-Item -LiteralPath $stdout, $stderr -Force -ErrorAction SilentlyContinue
}

$today = (Get-Date).ToString('yyyy-MM-dd')

if ($code -eq 0) {
    # Silent on success. A passing check that prints its whole test suite into the next
    # iteration's context window is how a loop starts hallucinating about files it just
    # read; the signal here is the exit code and nothing else.
    Set-RunCount 0
    Write-Output 'converged'
    exit $EXIT_OK
}

# --- failure: account for the iteration before anything else -----------------------

$failing = @($output | Where-Object { $_ -ne $null -and $_.Trim() -ne '' })
if ($failing.Count -gt $MaxOutputLines) {
    $kept = $failing[($failing.Count - $MaxOutputLines)..($failing.Count - 1)]
    $failing = @("... $($failing.Count - $MaxOutputLines) earlier lines omitted") + $kept
}
if ($failing.Count -eq 0) { $failing = @("(no output; exit code $code)") }
$failingText = ($failing -join ' | ')
if ($failingText.Length -gt 600) { $failingText = $failingText.Substring(0, 600) + ' ...' }

$iterations = $iterations + 1
$runCount = (Get-RunCount) + 1
$capped = ($iterations -ge $TotalCap) -or ($runCount -ge $PerRunCap)

$fp = $fingerprintAtRead
$new = [System.Collections.Generic.List[string]]::new()
$new.AddRange([string[]]$lines)

# Iterations: written in place, or inserted into the field block.
$idx = Get-FieldIndex 'Iterations'
if ($idx -ge 0) { $new[$idx] = "Iterations: $iterations" }
else { $new.Insert($fieldEnd + 1, "Iterations: $iterations"); $fieldEnd++; $end++ }

if ($capped) {
    $sIdx = Get-FieldIndex 'Status'
    if ($sIdx -ge 0) { $new[$sIdx] = 'Status: blocked' }
    else { $new.Insert($start + 1, 'Status: blocked'); $fieldEnd++; $end++ }

    $reason = "The convergence loop on this item ran $iterations attempts and its completion check still fails. The check is ``$command`` and its last failing output was: $failingText. Nothing here is a judgment call the loop can make - either the check is asking for the wrong thing, or the work needs a different approach than repeating the brief."
    $options = @(
        '- Keep iterating on this item with the cap raised',
        '- Change the completion check on this item and retry',
        '- Drop the completion check and I will judge it myself',
        '- Leave it blocked for now'
    )

    $block = [System.Collections.Generic.List[string]]::new()
    $block.Add("Blocked reason: $reason")
    $block.Add('Options:')
    foreach ($o in $options) { $block.Add($o) }

    # Remove any prior Blocked reason:/Options: pair so repeated caps do not stack.
    $bIdx = Get-FieldIndex 'Blocked reason'
    if ($bIdx -ge 0) {
        $stop = $bIdx + 1
        while ($stop -le $fieldEnd -and -not ($new[$stop] -match $fieldPattern)) { $stop++ }
        $new.RemoveRange($bIdx, $stop - $bIdx)
        $fieldEnd -= ($stop - $bIdx)
        $end -= ($stop - $bIdx)
    }
    $new.InsertRange($fieldEnd + 1, [string[]]$block)
    $fieldEnd += $block.Count
    $end += $block.Count
}

# Log: the audit reader, not the dashboard reader. Dates and measurements live here and
# never in Blocked reason:.
$logIdx = -1
for ($i = $start; $i -le $end; $i++) { if ($new[$i] -match '^Log:\s*$') { $logIdx = $i; break } }
$logLine = "- ${today}: convergence iteration $iterations failed the check ``$command``: $failingText"
if ($logIdx -ge 0) {
    $insertAt = $logIdx + 1
    while ($insertAt -le $end -and $new[$insertAt] -match '^\s*-\s') { $insertAt++ }
    $new.Insert($insertAt, $logLine)
}
else {
    $tail = $end
    while ($tail -gt $start -and $new[$tail].Trim() -eq '') { $tail-- }
    $new.InsertRange($tail + 1, [string[]]@('', 'Log:', $logLine))
}

if ((Get-Fingerprint $Queue) -ne $fp) {
    [Console]::Error.WriteLine("Queue file changed while this step was running. Re-read and re-decide: $Queue")
    exit $EXIT_CONFLICT
}
[System.IO.File]::WriteAllLines($Queue, $new.ToArray())
Set-RunCount $runCount

if ($capped) {
    Write-Output "capped after $iterations iterations ($runCount this run); item set to blocked"
    Write-Output $failingText
    exit $EXIT_CAPPED
}

Write-Output "reiterate: attempt $iterations of $TotalCap failed"
Write-Output $failingText
exit $EXIT_REITERATE
