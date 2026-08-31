<#
.SYNOPSIS
  Tests for tools/queue-cas.ps1, written by constructing the failures rather than by
  reading the code.

.DESCRIPTION
  Every case drives the guard into the state it exists to catch: a stale fingerprint, an
  absent file, and an append too large to travel as a command-line argument. That last
  case is why -ContentPath exists. Windows caps a command line at roughly 32 KB, and a
  caller passing a 20 KB block to -Content gets a spawn failure with an empty error
  message, which reads as a broken tool rather than as a limit.

.EXAMPLE
  powershell -NoProfile -File tools\tests\queue-cas.tests.ps1
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

$tool = Join-Path (Split-Path -Parent $PSScriptRoot) 'queue-cas.ps1'
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("queue-cas-tests-" + [Guid]::NewGuid().ToString('n'))
New-Item -ItemType Directory -Path $root | Out-Null

function New-QueueFile($content = "# Queue`n`n## Existing item`nStatus: blocked`n") {
    $path = Join-Path $root ((New-Guid).ToString('n') + '.md')
    [System.IO.File]::WriteAllText($path, $content)
    return $path
}

function Invoke-Cas([string[]]$arguments) {
    $out = Join-Path $root ((New-Guid).ToString('n') + '.out')
    $err = Join-Path $root ((New-Guid).ToString('n') + '.err')
    $process = Start-Process -FilePath 'powershell.exe' `
        -ArgumentList (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$tool`"") + ($arguments | ForEach-Object { if ($_ -match '\s') { "`"$_`"" } else { $_ } })) `
        -NoNewWindow -Wait -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
    return [pscustomobject]@{
        Code   = $process.ExitCode
        Output = (Get-Content -Raw -ErrorAction SilentlyContinue $out)
        Error  = (Get-Content -Raw -ErrorAction SilentlyContinue $err)
    }
}

function Get-Fp($path) {
    return (Invoke-Cas @('fingerprint', '-Path', $path)).Output.Trim()
}

# --- 1. a matching fingerprint appends -------------------------------------------------
$q = New-QueueFile
$fp = Get-Fp $q
$r = Invoke-Cas @('append', '-Path', $q, '-Expect', $fp, '-Content', 'appended line')
Assert-Eq $r.Code 0 'a matching fingerprint appends'
Assert ((Get-Content -Raw $q) -match 'appended line') 'the appended content lands in the file'
Assert ((Get-Content -Raw $q) -match '## Existing item') 'the existing content survives the append'

# --- 2. a stale fingerprint is refused -------------------------------------------------
$q = New-QueueFile
$stale = Get-Fp $q
Add-Content -Path $q -Value 'a peer wrote this' -Encoding utf8
$r = Invoke-Cas @('append', '-Path', $q, '-Expect', $stale, '-Content', 'should not land')
Assert-Eq $r.Code 5 'a stale fingerprint is reported as a conflict'
Assert ((Get-Content -Raw $q) -notmatch 'should not land') 'a conflicted append writes nothing'
Assert ((Get-Content -Raw $q) -match 'a peer wrote this') "the peer's write survives the refusal"

# --- 3. an absent file fingerprints as 'absent' ----------------------------------------
$missing = Join-Path $root 'never-created.md'
Assert-Eq (Get-Fp $missing) 'absent' 'an absent file fingerprints as absent'

# --- 4. usage errors ------------------------------------------------------------------
$q = New-QueueFile
Assert-Eq (Invoke-Cas @('append', '-Path', $q, '-Content', 'x')).Code 4 'append without -Expect is a usage error'
Assert-Eq (Invoke-Cas @('append', '-Path', $q, '-Expect', (Get-Fp $q))).Code 4 'append with no content is a usage error'

# --- 5. a large append travels by file, not by command line ----------------------------
# 40 KB is past the Windows command-line cap, so this case fails outright without
# -ContentPath. It is the shape a discovery run produces when it merges a batch of new
# postings into JOBS.md in one write.
$q = New-QueueFile
$big = (1..1600 | ForEach-Object { "### Posting $_`nStatus: new`n" }) -join "`n"
Assert ($big.Length -gt 32768) 'the fixture is genuinely larger than a command line can carry'
$bigFile = Join-Path $root 'big-append.md'
[System.IO.File]::WriteAllText($bigFile, $big)

$fp = Get-Fp $q
$r = Invoke-Cas @('append', '-Path', $q, '-Expect', $fp, '-ContentPath', $bigFile)
Assert-Eq $r.Code 0 'a large append succeeds via -ContentPath'
$after = Get-Content -Raw $q
Assert ($after -match '### Posting 1\b') 'the first entry of a large append lands'
Assert ($after -match '### Posting 1600\b') 'the last entry of a large append lands'
Assert ($after -match '## Existing item') 'a large append preserves the existing content'

# --- 6. -ContentPath obeys the same fingerprint guard ----------------------------------
$q = New-QueueFile
$stale = Get-Fp $q
Add-Content -Path $q -Value 'a peer wrote this' -Encoding utf8
$r = Invoke-Cas @('append', '-Path', $q, '-Expect', $stale, '-ContentPath', $bigFile)
Assert-Eq $r.Code 5 'a stale fingerprint is refused for -ContentPath too'
Assert ((Get-Content -Raw $q) -notmatch '### Posting 1\b') 'a conflicted -ContentPath append writes nothing'

# --- 7. -Content and -ContentPath together are a usage error ---------------------------
$q = New-QueueFile
$r = Invoke-Cas @('append', '-Path', $q, '-Expect', (Get-Fp $q), '-Content', 'x', '-ContentPath', $bigFile)
Assert-Eq $r.Code 4 'passing both -Content and -ContentPath is a usage error'

# --- 8. a missing -ContentPath is a usage error, not a silent no-op --------------------
$q = New-QueueFile
$r = Invoke-Cas @('append', '-Path', $q, '-Expect', (Get-Fp $q), '-ContentPath', (Join-Path $root 'no-such-file.md'))
Assert-Eq $r.Code 4 'a missing -ContentPath is a usage error'

Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
if ($script:Failures -eq 0) {
    Write-Host "$($script:Ran) assertions passed" -ForegroundColor Green
    exit 0
}
Write-Host "$($script:Failures) of $($script:Ran) assertions FAILED" -ForegroundColor Red
exit 1
