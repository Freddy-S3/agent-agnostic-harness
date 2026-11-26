<#
.SYNOPSIS
  Detect idle or repeating progress events in a software-factory run log.

.DESCRIPTION
  Each non-empty JSONL line is one observed event. Every event carries a stable
  signature and a boolean progress flag. A progress event resets both counters.
  Too many consecutive non-progress events or the same signature repeating too
  often means the worker is stalled and must be reconciled before retrying.

  Exit codes: 0 progress is healthy, 4 invalid input, 7 stalled or repeating.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Path,
    [int]$MaxIdleEvents = 3,
    [int]$MaxRepeatedEvents = 3
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message, [int]$Code = 7) {
    [Console]::Error.WriteLine("factory-progress: $Message")
    exit $Code
}

if ($MaxIdleEvents -lt 1 -or $MaxRepeatedEvents -lt 1) { Fail 'progress thresholds must be positive' 4 }
if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { Fail "event log not found: $Path" 4 }

$lines = @(Get-Content -LiteralPath $Path -Encoding UTF8)
$seen = 0
$idle = 0
$lastSignature = $null
$repeated = 0

for ($index = 0; $index -lt $lines.Count; $index++) {
    if ([string]::IsNullOrWhiteSpace($lines[$index])) { continue }
    $seen++
    try { $event = $lines[$index] | ConvertFrom-Json }
    catch { Fail "line $($index + 1) is not valid JSON: $($_.Exception.Message)" 4 }

    $signature = [string]$event.signature
    if ([string]::IsNullOrWhiteSpace($signature)) { Fail "line $($index + 1) is missing signature" 4 }
    if ($event.progress -isnot [bool]) { Fail "line $($index + 1) needs boolean progress" 4 }

    if ($signature -eq $lastSignature) { $repeated++ } else { $lastSignature = $signature; $repeated = 1 }
    if ($event.progress) { $idle = 0; $repeated = 1; continue }
    $idle++

    if ($idle -gt $MaxIdleEvents) { Fail "no progress for $idle consecutive events ending at line $($index + 1)" }
    if ($repeated -gt $MaxRepeatedEvents) { Fail "signature '$signature' repeated $repeated consecutive times ending at line $($index + 1)" }
}

if ($seen -eq 0) { Fail 'event log contains no events' 4 }
exit 0
