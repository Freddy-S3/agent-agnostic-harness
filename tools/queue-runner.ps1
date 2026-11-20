<#
.SYNOPSIS
  Select and checkpoint one queue item for a resumable software-factory run.

.DESCRIPTION
  This is the deterministic boundary around the model-driven /queue workflow. It reads
  both queues, resumes the highest-impact in-progress item before selecting pending work,
  requires exactly one existing Git repository route, and persists a checkpoint before
  the model is allowed to do risky work. A run owns one item only. Stop leaves the item
  in-progress so a later firing resumes from the checkpoint; finish requires a bounded
  verification result and a PR handoff and never merges or publishes anything.

.NOTES
  Exit codes: 0 success, 2 no actionable item, 3 invalid route, 4 usage, 5 queue CAS
  conflict. Queue mutations go through tools/queue-cas.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet('start', 'checkpoint', 'stop', 'finish', 'block', 'status')]
    [string]$Action,

    [ValidateSet('auto', 'phone', 'pc')]
    [string]$Gate = 'auto',

    [string]$QueueDir,
    [string]$Item,
    [string]$RunId,
    [string]$Phase,
    [string]$NextAction,
    [string]$Operation,
    [string]$Partial,
    [string]$Discriminator,
    [ValidateSet('done', 'failed', 'abandoned')]
    [string]$Outcome,
    [string]$Reason,
    [string]$Verification,
    [string]$PullRequest,
    [string[]]$Options,
    [string]$IntentId,
    [string]$Session = 'software-factory'
)

$ErrorActionPreference = 'Stop'
$EXIT_NO_ITEM = 2
$EXIT_ROUTE = 3
$EXIT_USAGE = 4
$EXIT_CONFLICT = 5

$runnerRoot = Split-Path -Parent $PSScriptRoot
$casTool = Join-Path $runnerRoot 'tools\queue-cas.ps1'

function Fail-Usage([string]$message) {
    [Console]::Error.WriteLine($message)
    exit $EXIT_USAGE
}

function Resolve-QueueDirectory {
    if ($QueueDir) { return (Resolve-Path -LiteralPath $QueueDir -ErrorAction Stop).Path }
    if ($env:CLAUDE_HARNESS_QUEUE_DIR) { return (Resolve-Path -LiteralPath $env:CLAUDE_HARNESS_QUEUE_DIR -ErrorAction Stop).Path }
    $default = Join-Path $env:USERPROFILE '.claude-harness\queue'
    if (Test-Path -LiteralPath $default) { return (Resolve-Path -LiteralPath $default).Path }
    $local = Join-Path $runnerRoot 'queue'
    if ((Test-Path (Join-Path $local 'QUEUE-PC.md')) -or (Test-Path (Join-Path $local 'QUEUE-PHONE.md'))) {
        return (Resolve-Path -LiteralPath $local).Path
    }
    return $default
}

function Get-FieldValue([string]$Body, [string]$Name) {
    $m = [regex]::Match($Body, "(?m)^$([regex]::Escape($Name)):\s*(.+?)\s*$")
    if ($m.Success) { return $m.Groups[1].Value.Trim() }
    return $null
}

function Get-QueueItems([string]$Directory) {
    $paths = @(
        [pscustomobject]@{ Gate = 'phone'; Path = Join-Path $Directory 'QUEUE-PHONE.md' },
        [pscustomobject]@{ Gate = 'pc'; Path = Join-Path $Directory 'QUEUE-PC.md' }
    )
    $items = New-Object System.Collections.Generic.List[object]
    $order = 0
    foreach ($source in $paths) {
        if (-not (Test-Path -LiteralPath $source.Path)) { continue }
        $lines = [System.IO.File]::ReadAllLines($source.Path)
        $heads = @()
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^## (.+)$') { $heads += $i }
        }
        for ($h = 0; $h -lt $heads.Count; $h++) {
            $start = $heads[$h]
            $end = if ($h + 1 -lt $heads.Count) { $heads[$h + 1] } else { $lines.Count }
            $title = $lines[$start].Substring(3).Trim()
            $body = if ($end -gt ($start + 1)) { ($lines[($start + 1)..($end - 1)] -join "`n") } else { '' }
            $repoMatches = [regex]::Matches($body, '(?m)^Repo:\s*(.+?)\s*$')
            $depends = @([regex]::Matches($body, '(?m)^Depends on:\s*(.+?)\s*$') | ForEach-Object { $_.Groups[1].Value.Trim() })
            $items.Add([pscustomobject]@{
                Title = $title
                Gate = $source.Gate
                Path = $source.Path
                Start = $start
                End = $end
                Order = $order
                Status = (Get-FieldValue $body 'Status')
                RepoValues = @($repoMatches | ForEach-Object { $_.Groups[1].Value.Trim() })
                DependsOn = $depends
                RunId = Get-FieldValue $body 'Run'
                Phase = Get-FieldValue $body 'Phase'
                Checkpoint = Get-FieldValue $body 'Checkpoint'
                Body = $body
            })
            $order++
        }
    }
    return $items.ToArray()
}

function Resolve-Repo([object]$QueueItem) {
    if ($QueueItem.RepoValues.Count -ne 1) {
        return [pscustomobject]@{ Valid = $false; Reason = "queue item '$($QueueItem.Title)' must contain exactly one Repo: line" }
    }
    $value = $QueueItem.RepoValues[0]
    if ([string]::IsNullOrWhiteSpace($value) -or $value -match '^(?i:none|n/a|machine-wide|external)\b') {
        return [pscustomobject]@{ Valid = $false; Reason = "queue item '$($QueueItem.Title)' does not name one owning Git repository" }
    }
    $candidate = $value
    if (-not [System.IO.Path]::IsPathRooted($candidate)) {
        $candidate = Join-Path (Join-Path $env:USERPROFILE 'Repo') $candidate
    }
    if (-not (Test-Path -LiteralPath $candidate -PathType Container)) {
        return [pscustomobject]@{ Valid = $false; Reason = "owning repository '$value' does not exist at '$candidate'" }
    }
    $full = (Resolve-Path -LiteralPath $candidate).Path
    & git -C $full rev-parse --git-dir *> $null
    if ($LASTEXITCODE -ne 0) {
        return [pscustomobject]@{ Valid = $false; Reason = "owning route '$full' is not a Git repository" }
    }
    return [pscustomobject]@{ Valid = $true; Path = $full }
}

function Get-Impact([object]$QueueItem, [object[]]$AllItems) {
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    $frontier = New-Object System.Collections.Generic.Queue[object]
    foreach ($candidate in $AllItems) {
        if ($candidate.DependsOn -contains $QueueItem.Title) { $frontier.Enqueue($candidate) }
    }
    while ($frontier.Count -gt 0) {
        $next = $frontier.Dequeue()
        if (-not $seen.Add($next.Title)) { continue }
        foreach ($candidate in $AllItems) {
            if ($candidate.DependsOn -contains $next.Title) { $frontier.Enqueue($candidate) }
        }
    }
    return $seen.Count
}

function Select-QueueItem([object[]]$AllItems) {
    $gates = if ($Gate -eq 'auto') { @('phone', 'pc') } else { @($Gate) }
    foreach ($g in $gates) {
        if ($Item) {
            $selected = @($AllItems | Where-Object { $_.Gate -eq $g -and $_.Title -eq $Item -and @('pending', 'in-progress') -contains $_.Status })[0]
            if ($selected) { return $selected }
            continue
        }
        $inProgress = @($AllItems | Where-Object { $_.Gate -eq $g -and $_.Status -eq 'in-progress' })
        $pending = @($AllItems | Where-Object { $_.Gate -eq $g -and $_.Status -eq 'pending' })
        $pool = if ($inProgress.Count -gt 0) { $inProgress } else { $pending }
        if ($pool.Count -eq 0) { continue }
        $ranked = @($pool | ForEach-Object {
            [pscustomobject]@{ Item = $_; Impact = Get-Impact $_ $AllItems }
        } | Sort-Object @{ Expression = { $_.Impact }; Descending = $true }, @{ Expression = { $_.Item.Order }; Descending = $false })
        return $ranked[0].Item
    }
    return $null
}

function Invoke-Cas([string]$ActionName, [string]$Path, [string]$Expected, [string]$ContentPath) {
    $args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $casTool, $ActionName, '-Path', $Path, '-Expect', $Expected, '-ContentPath', $ContentPath)
    $output = & powershell.exe @args 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        if ($code -eq $EXIT_CONFLICT) { return [pscustomobject]@{ Code = $EXIT_CONFLICT; Output = ($output -join ' ') } }
        throw (($output -join ' ').Trim())
    }
    return [pscustomobject]@{ Code = 0; Output = ($output -join ' ') }
}

function Get-CasFingerprint([string]$Path) {
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $casTool fingerprint -Path $Path 2>&1
    if ($LASTEXITCODE -ne 0) { throw (($output -join ' ').Trim()) }
    return ($output -join '').Trim()
}

function Write-Checkpoint([string]$Path, [object]$State) {
    $directory = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $tmp = "$Path.tmp-$PID"
    $backup = "$Path.bak-$PID"
    try {
        $json = $State | ConvertTo-Json -Depth 8
        [System.IO.File]::WriteAllText($tmp, $json, [System.Text.UTF8Encoding]::new($false))
        if (Test-Path -LiteralPath $Path) { [System.IO.File]::Replace($tmp, $Path, $backup) }
        else { Move-Item -LiteralPath $tmp -Destination $Path -Force }
    }
    finally {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue }
    }
}

function Read-Checkpoint([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "checkpoint not found: $Path" }
    return (Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json)
}

function Set-StateValue($State, [string]$Name, $Value) {
    if ($State -is [System.Collections.IDictionary]) { $State[$Name] = $Value; return }
    $property = $State.PSObject.Properties[$Name]
    if ($property) { $property.Value = $Value }
    else { $State | Add-Member -NotePropertyName $Name -NotePropertyValue $Value }
}

function Get-CheckpointPath([string]$Directory, [string]$Id) {
    return (Join-Path $Directory (Join-Path '.software-factory\checkpoints' ($Id + '.json')))
}

function Find-Item([string]$Directory, [string]$Title, [string]$Id) {
    $all = Get-QueueItems $Directory
    if ($Title) {
        $matches = @($all | Where-Object { $_.Title -eq $Title })
        if ($matches.Count -ne 1) { throw "expected exactly one queue item titled '$Title', found $($matches.Count)" }
        return $matches[0]
    }
    if ($Id) {
        $matches = @($all | Where-Object { $_.RunId -eq $Id })
        if ($matches.Count -ne 1) { throw "expected exactly one queue item with Run: $Id, found $($matches.Count)" }
        return $matches[0]
    }
    throw 'provide -Item or -RunId'
}

function Add-Log([System.Collections.Generic.List[string]]$Block, [string]$Message) {
    $log = -1
    for ($i = 0; $i -lt $Block.Count; $i++) { if ($Block[$i] -match '^Log:\s*$') { $log = $i; break } }
    if ($log -lt 0) {
        if ($Block.Count -gt 0 -and $Block[$Block.Count - 1].Trim() -ne '') { $Block.Add('') }
        $Block.Add('Log:')
        $Block.Add("- $((Get-Date).ToString('yyyy-MM-dd')): $Message")
        return
    }
    $at = $log + 1
    while ($at -lt $Block.Count -and $Block[$at] -match '^\s*-\s') { $at++ }
    $Block.Insert($at, "- $((Get-Date).ToString('yyyy-MM-dd')): $Message")
}

function Set-Field([System.Collections.Generic.List[string]]$Block, [string]$Name, [string]$Value) {
    $prefix = "${Name}:"
    for ($i = 0; $i -lt $Block.Count; $i++) {
        if ($Block[$i] -match "^$([regex]::Escape($Name)):\s*") {
            $Block[$i] = "$prefix $Value"
            return
        }
    }
    $at = $Block.Count
    for ($i = 1; $i -lt $Block.Count; $i++) {
        if ($Block[$i].Trim() -eq '' -or $Block[$i] -match '^Log:\s*$') { $at = $i; break }
    }
    $Block.Insert($at, "$prefix $Value")
}

function Remove-Field([System.Collections.Generic.List[string]]$Block, [string]$Name) {
    for ($i = 0; $i -lt $Block.Count; $i++) {
        if ($Block[$i] -match "^$([regex]::Escape($Name)):\s*") {
            $stop = $i + 1
            while ($stop -lt $Block.Count -and $Block[$stop] -notmatch '^[A-Z][a-z]+ ?[a-z]*:') { $stop++ }
            $Block.RemoveRange($i, $stop - $i)
            return
        }
    }
}

function Set-Blocker([System.Collections.Generic.List[string]]$Block, [string]$BlockReason, [string[]]$BlockOptions) {
    Remove-Field $Block 'Blocked reason'
    Remove-Field $Block 'Options'
    $status = 0
    for ($i = 0; $i -lt $Block.Count; $i++) { if ($Block[$i] -match '^Status:') { $status = $i; break } }
    $at = $status + 1
    $Block.Insert($at, "Blocked reason: $BlockReason")
    $Block.Insert($at + 1, 'Options:')
    for ($i = 0; $i -lt $BlockOptions.Count; $i++) { $Block.Insert($at + 2 + $i, "- $($BlockOptions[$i])") }
}

function Update-QueueItem([object]$QueueItem, [scriptblock]$Change) {
    $expected = Get-CasFingerprint $QueueItem.Path
    $text = [System.IO.File]::ReadAllText($QueueItem.Path)
    $nl = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($line in [System.IO.File]::ReadAllLines($QueueItem.Path)) { $lines.Add($line) }
    $start = -1
    $end = $lines.Count
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -eq "## $($QueueItem.Title)") { $start = $i; break }
    }
    if ($start -lt 0) { return [pscustomobject]@{ Code = $EXIT_CONFLICT; Output = 'queue item disappeared while updating' } }
    for ($i = $start + 1; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^## ') { $end = $i; break } }
    $block = New-Object System.Collections.Generic.List[string]
    for ($i = $start; $i -lt $end; $i++) { $block.Add($lines[$i]) }
    & $Change $block
    $lines.RemoveRange($start, $end - $start)
    $lines.InsertRange($start, $block)
    $next = ($lines -join $nl) + $nl
    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllText($tmp, $next, [System.Text.UTF8Encoding]::new($false))
        return (Invoke-Cas 'replace' $QueueItem.Path $expected $tmp)
    }
    finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
}

function Get-OpenIntent($State) {
    @($State.history | Where-Object { $_.status -eq 'open' } | Select-Object -Last 1)[0]
}

function Save-State($Path, $State) {
    Set-StateValue $State 'updatedAt' ((Get-Date).ToUniversalTime().ToString('o'))
    Write-Checkpoint $Path $State
}

$queueDirectory = Resolve-QueueDirectory
if ($Action -eq 'start') {
    $all = Get-QueueItems $queueDirectory
    $selected = Select-QueueItem $all
    if (-not $selected) {
        Write-Output '{"status":"idle","reason":"no actionable queue item"}'
        exit $EXIT_NO_ITEM
    }
    $route = Resolve-Repo $selected
    if (-not $route.Valid) {
        Write-Output (([pscustomobject]@{ status = 'blocked-route'; item = $selected.Title; reason = $route.Reason } | ConvertTo-Json -Compress))
        exit $EXIT_ROUTE
    }
    $run = if ($selected.Status -eq 'in-progress' -and $selected.RunId) { $selected.RunId } else { "sf-$((Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))-$([guid]::NewGuid().ToString('n').Substring(0, 8))" }
    $checkpointPath = Get-CheckpointPath $queueDirectory $run
    if (Test-Path -LiteralPath $checkpointPath) {
        $state = Read-Checkpoint $checkpointPath
        Set-StateValue $state 'status' 'active'
        $phaseValue = if ($state.phase) { $state.phase } else { 'route' }
        $nextValue = if ($state.nextAction) { $state.nextAction } else { 'Read the item brief and prepare the smallest reversible change.' }
    }
    else {
        $phaseValue = 'route'
        $nextValue = 'Read the item brief and prepare the smallest reversible change.'
        $state = [ordered]@{
            version = 1
            runId = $run
            item = $selected.Title
            gate = $selected.Gate
            session = $Session
            queueFile = $selected.Path
            repo = $route.Path
            status = 'active'
            phase = $phaseValue
            nextAction = $nextValue
            history = @()
            verification = $null
            pullRequest = $null
            stopReason = $null
            createdAt = (Get-Date).ToUniversalTime().ToString('o')
        }
    }
    Set-StateValue $state 'runId' $run
    Set-StateValue $state 'item' $selected.Title
    Set-StateValue $state 'session' $Session
    Set-StateValue $state 'queueFile' $selected.Path
    Set-StateValue $state 'repo' $route.Path
    Set-StateValue $state 'phase' $phaseValue
    Set-StateValue $state 'nextAction' $nextValue
    Save-State $checkpointPath $state
    $change = {
        param($block)
        Set-Field $block 'Status' 'in-progress'
        Set-Field $block 'Run' $run
        Set-Field $block 'Route' $route.Path
        Set-Field $block 'Checkpoint' $checkpointPath
        Set-Field $block 'Phase' $phaseValue
        $verb = if ($selected.Status -eq 'in-progress') { 'resumed' } else { 'claimed' }
        Add-Log $block "software-factory runner $verb this item for $($route.Path); checkpoint $checkpointPath"
    }
    $result = Update-QueueItem $selected $change
    if ($result.Code -eq $EXIT_CONFLICT) {
        Set-StateValue $state 'status' 'paused'; Set-StateValue $state 'stopReason' 'queue file changed before the claim could be saved'; Save-State $checkpointPath $state
        Write-Output $result.Output
        exit $EXIT_CONFLICT
    }
    [pscustomobject]@{ status = 'active'; item = $selected.Title; gate = $selected.Gate; repo = $route.Path; runId = $run; checkpoint = $checkpointPath; phase = $phaseValue; nextAction = $nextValue } | ConvertTo-Json -Compress
    exit 0
}

if (-not $RunId) { Fail-Usage "$Action requires -RunId" }
$checkpointPath = Get-CheckpointPath $queueDirectory $RunId
$state = Read-Checkpoint $checkpointPath
$queueItem = Find-Item $queueDirectory $state.item $RunId

if ($Action -eq 'status') {
    $state | ConvertTo-Json -Depth 8 -Compress
    exit 0
}

if ($Action -eq 'checkpoint') {
    if (-not $Operation -and -not $Outcome) { Fail-Usage 'checkpoint requires -Operation or -Outcome' }
    $history = New-Object System.Collections.Generic.List[object]
    foreach ($entry in @($state.history)) { $history.Add($entry) }
    if ($Operation) {
        if (-not $Partial -or -not $Discriminator) { Fail-Usage 'an open checkpoint requires -Partial and -Discriminator' }
        $id = "intent-$([guid]::NewGuid().ToString('n').Substring(0, 8))"
        $history.Add([pscustomobject]@{ id = $id; operation = $Operation; partial = $Partial; discriminator = $Discriminator; status = 'open'; openedAt = (Get-Date).ToUniversalTime().ToString('o') })
        Set-StateValue $state 'currentIntentId' $id
    }
    else {
        $open = Get-OpenIntent $state
        if ($IntentId) { $open = @($history | Where-Object { $_.id -eq $IntentId })[0] }
        if (-not $open) { Fail-Usage 'no open checkpoint intent matches the outcome' }
        Set-StateValue $open 'status' $Outcome
        Set-StateValue $open 'outcomeAt' ((Get-Date).ToUniversalTime().ToString('o'))
        $resultValue = if ($Reason) { $Reason } else { $Outcome }
        Set-StateValue $open 'result' $resultValue
        Set-StateValue $state 'currentIntentId' $null
    }
    if ($Phase) { $state.phase = $Phase }
    if ($NextAction) { $state.nextAction = $NextAction }
    Set-StateValue $state 'history' $history.ToArray()
    Save-State $checkpointPath $state
    $state | ConvertTo-Json -Depth 8 -Compress
    exit 0
}

if ($Action -eq 'stop') {
    if (-not $Reason) { Fail-Usage 'stop requires -Reason' }
    $open = Get-OpenIntent $state
    if ($open) { Set-StateValue $open 'status' 'failed'; Set-StateValue $open 'outcomeAt' ((Get-Date).ToUniversalTime().ToString('o')); Set-StateValue $open 'result' $Reason }
    Set-StateValue $state 'status' 'paused'
    Set-StateValue $state 'stopReason' $Reason
    if ($NextAction) { Set-StateValue $state 'nextAction' $NextAction }
    Save-State $checkpointPath $state
    $change = { param($block) Add-Log $block "software-factory runner paused after $Reason; resume from checkpoint phase $($state.phase)" }
    $result = Update-QueueItem $queueItem $change
    if ($result.Code -eq $EXIT_CONFLICT) { Write-Output $result.Output; exit $EXIT_CONFLICT }
    [pscustomobject]@{ status = 'paused'; item = $state.item; runId = $RunId; checkpoint = $checkpointPath; nextAction = $state.nextAction } | ConvertTo-Json -Compress
    exit 0
}

if ($Action -eq 'block') {
    if (-not $Reason) { Fail-Usage 'block requires -Reason' }
    if (-not $Options -or $Options.Count -lt 2 -or $Options.Count -gt 4) { Fail-Usage 'block requires two to four self-contained -Options' }
    Set-StateValue $state 'status' 'blocked'; Set-StateValue $state 'stopReason' $Reason; Set-StateValue $state 'nextAction' 'Wait for the human decision, then resume this same run.'
    Save-State $checkpointPath $state
    $change = { param($block) Set-Field $block 'Status' 'blocked'; Set-Blocker $block $Reason $Options; Add-Log $block "software-factory runner blocked this item; checkpoint $checkpointPath" }
    $result = Update-QueueItem $queueItem $change
    if ($result.Code -eq $EXIT_CONFLICT) { Write-Output $result.Output; exit $EXIT_CONFLICT }
    [pscustomobject]@{ status = 'blocked'; item = $state.item; runId = $RunId; checkpoint = $checkpointPath } | ConvertTo-Json -Compress
    exit 0
}

if ($Action -eq 'finish') {
    if (-not $Verification -or -not $PullRequest) { Fail-Usage 'finish requires -Verification and -PullRequest; pass none (non-code) only when no PR is applicable' }
    if ($PullRequest -ne 'none (non-code)' -and $PullRequest -notmatch '^https://[^/\s]+/[^/\s]+/[^/\s]+/pull/\d+$') { Fail-Usage 'PullRequest must be a pull-request URL or exactly none (non-code)' }
    if (Get-OpenIntent $state) { Fail-Usage 'finish requires every write-ahead checkpoint intent to have an outcome' }
    Set-StateValue $state 'phase' 'finish'
    Set-StateValue $state 'nextAction' 'Persist the done state after the bounded verification and PR handoff.'
    Save-State $checkpointPath $state
    $change = {
        param($block)
        Set-Field $block 'Status' 'done'
        Add-Log $block "software-factory runner finished after bounded verification: $Verification; PR handoff: $PullRequest; merge and public release remain human-gated"
    }
    $result = Update-QueueItem $queueItem $change
    if ($result.Code -eq $EXIT_CONFLICT) { Write-Output $result.Output; exit $EXIT_CONFLICT }
    Set-StateValue $state 'status' 'done'; Set-StateValue $state 'verification' $Verification; Set-StateValue $state 'pullRequest' $PullRequest; Set-StateValue $state 'nextAction' 'No further runner action.'
    Save-State $checkpointPath $state
    [pscustomobject]@{ status = 'done'; item = $state.item; runId = $RunId; verification = $Verification; pullRequest = $PullRequest } | ConvertTo-Json -Compress
    exit 0
}

Fail-Usage "unsupported action '$Action'"
