<#
.SYNOPSIS
  Replay a versioned software-factory manifest and write measured case results.

.DESCRIPTION
  A factory change is not accepted because a single task felt faster.
  This runner replays explicit local cases, records exit status and latency, and
  preserves optional token, turn, and cost metrics supplied by a case metrics file.
  The manifest is executable configuration, so review it before running it.

  Exit codes: 0 all selected cases passed, 4 invalid input, 7 one or more cases failed.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Manifest,
    [Parameter(Mandatory)][string]$Output,
    [string]$CaseId,
    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }

function Fail([string]$Message, [int]$Code = 7) {
    [Console]::Error.WriteLine("factory-eval: $Message")
    exit $Code
}

if (-not (Test-Path -LiteralPath $Manifest -PathType Leaf)) { Fail "manifest not found: $Manifest" 4 }
try {
    $definition = Get-Content -Raw -LiteralPath $Manifest -Encoding UTF8 | ConvertFrom-Json
} catch {
    Fail "manifest is not valid JSON: $($_.Exception.Message)" 4
}

if ([int]$definition.schemaVersion -ne 1) { Fail 'manifest schemaVersion must be 1' 4 }
if ([string]::IsNullOrWhiteSpace([string]$definition.name)) { Fail 'manifest name is required' 4 }
$cases = @($definition.cases | Where-Object { $null -ne $_ })
if ($cases.Count -eq 0 -and $null -ne $definition.evaluation) {
    $cases = @($definition.evaluation.cases | Where-Object { $null -ne $_ })
}
if ($cases.Count -eq 0) { Fail 'manifest cases must contain at least one case' 4 }

if ($CaseId) {
    $cases = @($cases | Where-Object { $_.id -eq $CaseId })
    if ($cases.Count -ne 1) { Fail "case '$CaseId' was not found exactly once" 4 }
}

function Get-Shell {
    $command = Get-Command powershell.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    $command = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    return 'powershell'
}

function Trim-Output([string]$Text) {
    if ($null -eq $Text) { return '' }
    if ($Text.Length -le 4000) { return $Text }
    return $Text.Substring(0, 4000) + "`n[truncated]"
}

function Read-Metrics($case) {
    if ([string]::IsNullOrWhiteSpace([string]$case.metricsPath)) { return $null }
    $metricsPath = Join-Path $RepoRoot ([string]$case.metricsPath)
    if (-not (Test-Path -LiteralPath $metricsPath -PathType Leaf)) { return $null }
    try { return (Get-Content -Raw -LiteralPath $metricsPath -Encoding UTF8 | ConvertFrom-Json) }
    catch { Fail "metricsPath for case '$($case.id)' is not valid JSON: $($_.Exception.Message)" 4 }
}

function Invoke-FactoryCommand([string]$Command, [int]$Limit, [string]$WorkingDirectory, [string]$Shell) {
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $Shell
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $arguments = @('-NoProfile', '-NonInteractive', '-Command', $Command)
    if ($startInfo.PSObject.Properties.Name -contains 'ArgumentList') {
        foreach ($argument in $arguments) { [void]$startInfo.ArgumentList.Add([string]$argument) }
    } else {
        $startInfo.Arguments = (($arguments | ForEach-Object { '"' + ([string]$_).Replace('"', '\"') + '"' }) -join ' ')
    }

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    if (-not $process.Start()) { throw "could not start shell '$Shell'" }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $finished = if ($Limit -gt 0) { $process.WaitForExit($Limit) } else { $process.WaitForExit(); $true }
    if (-not $finished) {
        try { $process.Kill() } catch { }
        $process.WaitForExit()
    }
    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result
    return [pscustomobject]@{
        TimedOut = (-not $finished)
        ExitCode = if ($finished) { $process.ExitCode } else { $null }
        Stdout = $stdout
        Stderr = $stderr
    }
}

$startedAt = (Get-Date).ToUniversalTime()
$results = New-Object System.Collections.Generic.List[object]
$shell = Get-Shell
$overallFailed = $false

foreach ($case in $cases) {
    if ([string]::IsNullOrWhiteSpace([string]$case.id)) { Fail 'every case needs an id' 4 }
    if ([string]::IsNullOrWhiteSpace([string]$case.origin)) { Fail "case '$($case.id)' needs an origin" 4 }
    if ([string]::IsNullOrWhiteSpace([string]$case.command)) { Fail "case '$($case.id)' needs a command" 4 }
    $expectedExit = 0
    if ($null -ne $case.expectExit) { $expectedExit = [int]$case.expectExit }
    $limit = 0
    if ($null -ne $case.maxDurationMs) { $limit = [int]$case.maxDurationMs }

    $timer = [Diagnostics.Stopwatch]::StartNew()
    $status = 'failed'
    $exitCode = $null
    $stdoutText = ''
    $stderrText = ''
    try {
        $execution = Invoke-FactoryCommand ([string]$case.command) $limit $RepoRoot $shell
        $stdoutText = $execution.Stdout
        $stderrText = $execution.Stderr
        if ($execution.TimedOut) {
            $status = 'timeout'
            $overallFailed = $true
        } else {
            $exitCode = $execution.ExitCode
            $status = if ($exitCode -eq $expectedExit) { 'passed' } else { 'failed' }
            if ($status -eq 'failed') { $overallFailed = $true }
        }
    } catch {
        $overallFailed = $true
        $status = 'failed'
        [Console]::Error.WriteLine("factory-eval: case '$($case.id)' could not start: $($_.Exception.Message)")
    } finally {
        $timer.Stop()
    }

    $results.Add([pscustomobject]@{
        id = [string]$case.id
        origin = [string]$case.origin
        status = $status
        expectedExit = $expectedExit
        exitCode = $exitCode
        durationMs = $timer.ElapsedMilliseconds
        stdout = Trim-Output $stdoutText
        stderr = Trim-Output $stderrText
        metrics = Read-Metrics $case
    })
}

$endedAt = (Get-Date).ToUniversalTime()
$report = [pscustomobject]@{
    schemaVersion = 1
    runId = "eval-$($startedAt.ToString('yyyyMMddTHHmmssZ'))-$([guid]::NewGuid().ToString('n').Substring(0, 8))"
    manifest = (Resolve-Path -LiteralPath $Manifest).Path
    name = [string]$definition.name
    startedAt = $startedAt.ToString('o')
    endedAt = $endedAt.ToString('o')
    totalDurationMs = [int]($endedAt - $startedAt).TotalMilliseconds
    passed = @($results | Where-Object status -eq 'passed').Count
    failed = @($results | Where-Object status -eq 'failed').Count
    timedOut = @($results | Where-Object status -eq 'timeout').Count
    cases = $results.ToArray()
}

$parent = Split-Path -Parent $Output
if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Output -Encoding UTF8

if ($overallFailed) {
    $bad = @($results | Where-Object { $_.status -ne 'passed' } | ForEach-Object { "$($_.id)=$($_.status)" }) -join ', '
    Fail "evaluation failed: $bad"
}
exit 0
