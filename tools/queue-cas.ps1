<#
.SYNOPSIS
  Compare-and-swap append for the shared queue files.

.DESCRIPTION
  The queue files are shared mutable state that several sessions write. A plain append
  is a lost-update waiting to happen: a session reads the file, spends minutes deciding
  what to write, and appends over a peer's entry that landed in between.

  This is the mechanism version of what one session improvised by hand: capture a
  fingerprint of the file immediately before writing, and abort if it changed. The
  fingerprint here is a content hash rather than a byte size, because two edits of equal
  length are not rare in a file of similarly-shaped entries.

  Read the file, compose the entry, then call this with the fingerprint taken at read
  time. A changed fingerprint means re-read and re-decide, not retry blindly - the peer's
  entry may be the same finding.

.EXAMPLE
  $fp = .\queue-cas.ps1 fingerprint -Path $q
  # ... read the file, decide what to append ...
  .\queue-cas.ps1 append -Path $q -Expect $fp -Content $entry

  # For an append larger than a command line can carry, stage it in a file first:
  .\queue-cas.ps1 append -Path $q -Expect $fp -ContentPath $stagedEntryFile

.NOTES
  Exit codes: 0 success, 5 fingerprint mismatch (re-read and re-decide), 4 usage error.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet('fingerprint', 'append')]
    [string]$Action,

    [Parameter(Mandatory)]
    [string]$Path,

    [string]$Expect,
    [string]$Content,
    [string]$ContentPath
)

$ErrorActionPreference = 'Stop'
$EXIT_USAGE = 4
$EXIT_MISMATCH = 5

function Get-Fingerprint($p) {
    if (-not (Test-Path $p)) { return 'absent' }
    $bytes = [System.IO.File]::ReadAllBytes($p)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    return ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join ''
}

if ($Action -eq 'fingerprint') {
    Write-Output (Get-Fingerprint $Path)
    exit 0
}

if (-not $Expect) {
    [Console]::Error.WriteLine('append requires -Expect <fingerprint taken when you read the file>.')
    exit $EXIT_USAGE
}
# Windows caps a command line at roughly 32 KB, so a large append has to arrive as a file
# rather than as an argument. A caller that passes -Content a 20 KB block gets a spawn
# failure with an empty error message, which reads as a broken tool rather than a limit.
if ($ContentPath) {
    if ($Content) {
        [Console]::Error.WriteLine('append takes -Content or -ContentPath, not both.')
        exit $EXIT_USAGE
    }
    if (-not (Test-Path $ContentPath)) {
        [Console]::Error.WriteLine("append -ContentPath not found: $ContentPath")
        exit $EXIT_USAGE
    }
    $Content = [System.IO.File]::ReadAllText($ContentPath)
}
if ($null -eq $Content -or $Content -eq '') {
    [Console]::Error.WriteLine('append requires -Content or -ContentPath.')
    exit $EXIT_USAGE
}

$actual = Get-Fingerprint $Path
if ($actual -ne $Expect) {
    Write-Output "MISMATCH: $Path changed since you read it (expected $($Expect.Substring(0,[Math]::Min(12,$Expect.Length))), found $($actual.Substring(0,[Math]::Min(12,$actual.Length))))."
    Write-Output 'Re-read the file and re-decide before appending. Another session may have logged the same finding.'
    exit $EXIT_MISMATCH
}

Add-Content -Path $Path -Value $Content -Encoding utf8
Write-Output "appended: $Path"
exit 0
