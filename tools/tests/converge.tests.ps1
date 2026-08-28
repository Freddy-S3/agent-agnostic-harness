<#
.SYNOPSIS
  Tests for tools/converge.ps1, written by constructing the failures rather than by
  reading the code.

.DESCRIPTION
  A guard only ever observed passing has not been tested. Every case below drives the
  gate into the state it exists to catch: a predicate that never passes, a predicate that
  is prose pretending to be a check, a cap reached inside one run, and a cap reached
  across runs. The assertions are on the queue file that results, because that file is
  the only thing a successor session and Faruk's dashboard actually read.

.EXAMPLE
  powershell -NoProfile -File tools\tests\converge.tests.ps1
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

$converge = Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) 'converge.ps1'
if (-not (Test-Path $converge)) { throw "converge.ps1 not found at $converge" }

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("converge-tests-" + [guid]::NewGuid().ToString('n').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $root | Out-Null
$stateDir = Join-Path $root 'state'

function New-Queue($fields, $extra) {
    $p = Join-Path $root ("q-" + [guid]::NewGuid().ToString('n').Substring(0, 8) + '.md')
    $body = @('# Queue', '', '## Sample item', '')
    $body += $fields
    $body += @('', 'Some free prose describing the brief, which must never be absorbed', 'into a field block.', '', 'Log:', '- 2026-01-01: created')
    if ($extra) { $body += $extra }
    [System.IO.File]::WriteAllLines($p, [string[]]$body)
    return $p
}

function Invoke-Converge($argList) {
    # Redirect to files rather than piping: 5.1 wraps a native command's stderr in an
    # ErrorRecord, which under ErrorActionPreference=Stop aborts the test run on the very
    # cases these tests exist to exercise.
    $o = New-TemporaryFile
    $e = New-TemporaryFile
    try {
        $p = Start-Process -FilePath 'powershell' -ArgumentList $argList `
            -RedirectStandardOutput $o -RedirectStandardError $e -NoNewWindow -PassThru -Wait
        $text = ((Get-Content -Raw -LiteralPath $o) + "`n" + (Get-Content -Raw -LiteralPath $e))
        return [pscustomobject]@{ Code = $p.ExitCode; Output = $text }
    }
    finally { Remove-Item -LiteralPath $o, $e -Force -ErrorAction SilentlyContinue }
}

function Invoke-Step($queue, $session, $extraArgs) {
    $a = @('-NoProfile', '-File', $converge, 'step', '-Queue', $queue, '-Item', '"Sample item"',
           '-Session', $session, '-StateDir', $stateDir)
    if ($extraArgs) { $a += $extraArgs }
    return Invoke-Converge $a
}

Write-Host "converge.ps1 tests" -ForegroundColor Cyan

# --- 1. no predicate: unchanged legacy behaviour -----------------------------------
$q = New-Queue @('Status: pending', 'Repo: example')
$r = Invoke-Step $q 'sess-none'
Assert-Eq $r.Code 0 'no Done when: exits 0'
Assert ($r.Output -match 'no-predicate') 'no Done when: reports no-predicate'
Assert ((Get-Content -Raw $q) -notmatch 'Iterations:') 'no Done when: leaves the item untouched'

# --- 2. prose predicate is rejected, not charitably interpreted ---------------------
# This is the failure the whole design exists to prevent: an exit condition that is the
# agent's own opinion of doneness.
foreach ($prose in @('The site renders correctly at every width.',
                     'all the tests pass',
                     'Verify the button does something')) {
    $q = New-Queue @('Status: pending', "Done when: $prose")
    $r = Invoke-Step $q 'sess-prose'
    Assert-Eq $r.Code 4 "prose predicate rejected: '$prose'"
    Assert ((Get-Content -Raw $q) -notmatch 'Iterations:') "prose predicate does not consume an iteration: '$prose'"
}

# A real command that happens to be short is NOT rejected.
$q = New-Queue @('Status: pending', 'Done when: exit 0')
$r = Invoke-Step $q 'sess-ok'
Assert-Eq $r.Code 0 'passing predicate exits 0'
Assert ($r.Output -match 'converged') 'passing predicate reports converged'

# --- 3. silent on success ----------------------------------------------------------
$q = New-Queue @('Status: pending', 'Done when: Write-Output "a lot of noise"; Write-Output "more noise"; exit 0')
$r = Invoke-Step $q 'sess-quiet'
Assert-Eq $r.Code 0 'noisy passing predicate still exits 0'
Assert ($r.Output -notmatch 'noise') 'passing predicate output is swallowed'

# --- 4. failing predicate: exit 6, counted, logged, status untouched ----------------
$q = New-Queue @('Status: in-progress', 'Repo: example', 'Done when: Write-Error "route button is dead"; exit 1')
$r = Invoke-Step $q 'sess-fail'
$text = Get-Content -Raw $q
Assert-Eq $r.Code 6 'failing predicate exits 6 (reiterate)'
Assert ($text -match '(?m)^Iterations: 1\s*$') 'first failure writes Iterations: 1'
Assert ($text -match '(?m)^Status: in-progress\s*$') 'first failure leaves Status alone'
Assert ($text -match 'route button is dead') 'failing output reaches the Log'
Assert ($text -notmatch 'Blocked reason:') 'a first failure is not a blocker'

# The count is written before the next attempt, so a session killed here resumes accurately.
$r2 = Invoke-Step $q 'sess-fail'
Assert-Eq $r2.Code 6 'second failure still reiterates under the default cap'
Assert ((Get-Content -Raw $q) -match '(?m)^Iterations: 2\s*$') 'the count is persisted between attempts, not recomputed'

# --- 5. per-run cap: constructed, not assumed --------------------------------------
$q = New-Queue @('Status: in-progress', 'Done when: exit 1')
$codes = @()
for ($i = 1; $i -le 3; $i++) { $codes += (Invoke-Step $q 'sess-cap' @('-PerRunCap', '3', '-TotalCap', '9')).Code }
Assert-Eq ($codes -join ',') '6,6,7' 'per-run cap of 3 yields reiterate, reiterate, capped'
$text = Get-Content -Raw $q
Assert ($text -match '(?m)^Status: blocked\s*$') 'cap sets Status: blocked'
Assert ($text -match '(?m)^Iterations: 3\s*$') 'cap records the iteration count'

# --- 6. total cap across separate runs ---------------------------------------------
# Different sessions reset the per-run counter, so only the persisted Iterations: total
# can stop this. That is the resumption path: each firing is a fresh session.
$q = New-Queue @('Status: in-progress', 'Done when: exit 1')
$codes = @()
for ($i = 1; $i -le 5; $i++) { $codes += (Invoke-Step $q "sess-run-$i" @('-PerRunCap', '3', '-TotalCap', '5')).Code }
Assert-Eq ($codes -join ',') '6,6,6,6,7' 'total cap of 5 stops on the fifth attempt across runs'
Assert ((Get-Content -Raw $q) -match '(?m)^Status: blocked\s*$') 'total cap sets Status: blocked'

# --- 7. the blocked entry is one the dashboard can actually render ------------------
# The parser ends a field at the next 'Name:' line and reads Options: as a run of
# single-line '- ' bullets. Prose between them silently swallows the whole body, and a
# numbered or wrapped list silently yields no buttons at all.
$lines = [System.IO.File]::ReadAllLines($q)
$start = [Array]::FindIndex($lines, [Predicate[string]] { param($l) $l -match '^## Sample item' })
$bIdx = -1; $oIdx = -1
for ($i = $start; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^Blocked reason:') { $bIdx = $i }
    if ($lines[$i] -match '^Options:\s*\s*$') { $oIdx = $i; break }
}
Assert ($bIdx -ge 0) 'cap writes a Blocked reason: field'
Assert ($oIdx -eq $bIdx + 1) 'Options: sits directly under Blocked reason: with no prose between'
$opts = @()
for ($i = $oIdx + 1; $i -lt $lines.Count -and $lines[$i] -match '^-\s+\S'; $i++) { $opts += $lines[$i] }
Assert ($opts.Count -ge 2) 'cap writes at least two options'
Assert (-not ($opts | Where-Object { $_ -match '^\s*\d+\.' })) 'options are bullets, not a numbered list'
Assert (-not ($opts | Where-Object { $_.Length -gt 120 })) 'each option fits on one line'
Assert ($lines[$bIdx] -notmatch '(?i)see above|as previously|the four|unchanged since|restating') 'Blocked reason: carries no back-reference the reader cannot resolve'
Assert ($lines[$bIdx] -match 'exit 1') 'Blocked reason: names the actual failing check'
$sIdx = -1
for ($i = $start; $i -lt $bIdx; $i++) { if ($lines[$i] -match '^Status:') { $sIdx = $i } }
Assert ($sIdx -ge 0) 'Status: is still inside the contiguous field block'
for ($i = $sIdx + 1; $i -lt $bIdx; $i++) {
    Assert ($lines[$i] -match '^[A-Z][a-z]+ ?[a-z]*:' -or $lines[$i].Trim() -eq '') "field block stays contiguous at line $i"
}

# --- 8. a peer writing the queue file mid-step is a conflict, not a lost update ------
# Constructed by making the predicate itself append to the queue while it runs, which is
# indistinguishable to this script from a concurrent session's CAS append.
$q = New-Queue @('Status: in-progress', 'Done when: Add-Content -LiteralPath ''QPATH'' -Value ''## Peer item''; exit 1')
$raw = [System.IO.File]::ReadAllText($q).Replace('QPATH', $q)
[System.IO.File]::WriteAllText($q, $raw)
$r = Invoke-Step $q 'sess-conflict'
Assert-Eq $r.Code 5 'a queue file changed under the step is reported as a conflict'
Assert ((Get-Content -Raw $q) -notmatch 'Iterations:') 'a conflicted step writes nothing'

# --- 9. status and reset -----------------------------------------------------------
$q = New-Queue @('Status: in-progress', 'Done when: exit 1', 'Iterations: 2')
$r = Invoke-Converge @('-NoProfile', '-File', $converge, 'status', '-Queue', $q, '-Item', '"Sample item"', '-Session', 'sess-status', '-StateDir', $stateDir)
Assert ($r.Output -match 'iterations: 2 / 5') 'status reports the persisted count'

Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
if ($script:Failures -eq 0) {
    Write-Host "$($script:Ran) assertions passed" -ForegroundColor Green
    exit 0
}
Write-Host "$($script:Failures) of $($script:Ran) assertions FAILED" -ForegroundColor Red
exit 1
