<#
.SYNOPSIS
  Validate one evidence-carrying software-factory phase or worker result.

.DESCRIPTION
  The factory treats agent handoffs as a protocol, not as free-form success prose.
  This validator owns the checks that must remain true across hosts and model versions:
  explicit outcome states, source freshness, bounded fan-out, progress evidence, and
  safe retry semantics for side effects.

  Exit codes: 0 valid, 4 usage or unreadable input, 7 invalid result.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Path,
    [int]$MaxFanOut = 3
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message, [int]$Code = 7) {
    [Console]::Error.WriteLine("factory-result: $Message")
    exit $Code
}

if ($MaxFanOut -lt 1) { Fail 'MaxFanOut must be positive' 4 }
if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { Fail "result file not found: $Path" 4 }

try {
    $result = Get-Content -Raw -LiteralPath $Path -Encoding UTF8 | ConvertFrom-Json
} catch {
    Fail "result is not valid JSON: $($_.Exception.Message)" 4
}

function Get-Value($Object, [string]$Name) {
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Require-Text($Object, [string]$Name) {
    $value = Get-Value $Object $Name
    if ([string]::IsNullOrWhiteSpace([string]$value)) { Fail "missing required field '$Name'" }
    return [string]$value
}

function Require-Date($Object, [string]$Name) {
    $value = Require-Text $Object $Name
    $parsed = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParse($value, [ref]$parsed)) { Fail "field '$Name' is not an ISO-8601 timestamp" }
}

$schemaVersion = Get-Value $result 'schemaVersion'
if ($null -eq $schemaVersion -or [int]$schemaVersion -ne 1) { Fail 'schemaVersion must be 1' }

Require-Text $result 'runId' | Out-Null
Require-Text $result 'phase' | Out-Null
$status = Require-Text $result 'status'
Require-Text $result 'summary' | Out-Null
Require-Date $result 'startedAt'
Require-Date $result 'endedAt'

$statuses = @('completed', 'partial', 'failed', 'blocked', 'cancelled', 'rejected', 'stale', 'unknown')
if ($statuses -notcontains $status) { Fail "status '$status' is not one of: $($statuses -join ', ')" }

$evidence = @()
$rawEvidence = Get-Value $result 'evidence'
if ($null -ne $rawEvidence) { $evidence = @($rawEvidence) }
if ($status -eq 'completed' -and $evidence.Count -eq 0) { Fail 'completed results require at least one evidence item' }

foreach ($item in $evidence) {
    foreach ($field in @('kind', 'ref', 'source', 'revision', 'asOf')) { Require-Text $item $field | Out-Null }
    $asOf = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParse((Get-Value $item 'asOf'), [ref]$asOf)) { Fail 'evidence.asOf must be an ISO-8601 timestamp' }
}

$sideEffects = @()
$rawSideEffects = Get-Value $result 'sideEffects'
if ($null -ne $rawSideEffects) { $sideEffects = @($rawSideEffects) }
$effectStatuses = @('none', 'planned', 'submitted', 'confirmed', 'failed', 'unknown')
foreach ($effect in $sideEffects) {
    $effectStatus = Require-Text $effect 'status'
    if ($effectStatuses -notcontains $effectStatus) { Fail "sideEffects.status '$effectStatus' is invalid" }
    if ($effectStatus -eq 'none') { continue }
    Require-Text $effect 'id' | Out-Null
    Require-Text $effect 'operation' | Out-Null
    Require-Text $effect 'idempotencyKey' | Out-Null
    if ($effectStatus -eq 'confirmed') { Require-Text $effect 'readBack' | Out-Null }
}

$incompleteStatuses = @('partial', 'failed', 'blocked', 'cancelled', 'rejected', 'stale', 'unknown')
if ($incompleteStatuses -contains $status) { Require-Text $result 'nextAction' | Out-Null }
if ($status -in @('failed', 'blocked', 'stale', 'unknown')) { Require-Text $result 'failureReason' | Out-Null }
if ($status -eq 'unknown') { Require-Text $result 'unknownReason' | Out-Null }

$progress = Get-Value $result 'progress'
if ($null -ne $progress) {
    $events = Get-Value $progress 'events'
    if ($null -ne $events -and ([int]$events -lt 0)) { Fail 'progress.events cannot be negative' }
    $stalled = [bool](Get-Value $progress 'stalled')
    $repeated = [string](Get-Value $progress 'repeatedSignature')
    if ($status -eq 'completed' -and ($stalled -or -not [string]::IsNullOrWhiteSpace($repeated))) {
        Fail 'completed results cannot report stalled or repeated progress'
    }
}

$resources = Get-Value $result 'resources'
if ($null -ne $resources) {
    $fanOut = Get-Value $resources 'fanOut'
    $fanOutBudget = Get-Value $resources 'fanOutBudget'
    if ($null -ne $fanOut -and [int]$fanOut -lt 0) { Fail 'resources.fanOut cannot be negative' }
    if ($null -ne $fanOutBudget -and [int]$fanOutBudget -lt 1) { Fail 'resources.fanOutBudget must be positive' }
    if ($null -ne $fanOut -and [int]$fanOut -gt $MaxFanOut) { Fail "resources.fanOut exceeds validator budget $MaxFanOut" }
    if ($null -ne $fanOut -and $null -ne $fanOutBudget -and [int]$fanOut -gt [int]$fanOutBudget) {
        Fail 'resources.fanOut exceeds resources.fanOutBudget'
    }
    foreach ($field in @('tokens', 'latencyMs', 'cost')) {
        $value = Get-Value $resources $field
        if ($null -ne $value -and [double]$value -lt 0) { Fail "resources.$field cannot be negative" }
    }
}

if ($status -eq 'completed') {
    foreach ($effect in $sideEffects) {
        $effectStatus = [string](Get-Value $effect 'status')
        if ($effectStatus -in @('submitted', 'unknown', 'planned', 'failed')) {
            Fail "completed result has unconfirmed side effect '$($effect.id)'"
        }
    }
}

Write-Output '' | Out-Null
exit 0
