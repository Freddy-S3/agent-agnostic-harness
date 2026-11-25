<#
.SYNOPSIS
  Failure-first tests for check-factory-progress.ps1.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$script:Failures = 0
$script:Ran = 0

function Assert($condition, [string]$label) {
    $script:Ran++
    if ($condition) { return }
    $script:Failures++
    Write-Host "FAIL  $label" -ForegroundColor Red
}

function Invoke-Progress([string]$path, [string[]]$extra = @()) {
    $out = New-TemporaryFile
    $err = New-TemporaryFile
    try {
        $args = @('-NoProfile', '-File', $script:checker, '-Path', $path)
        $args += $extra
        $proc = Start-Process -FilePath 'powershell' -ArgumentList $args -RedirectStandardOutput $out.FullName -RedirectStandardError $err.FullName -NoNewWindow -PassThru -Wait
        return [pscustomobject]@{
            Code = $proc.ExitCode
            Out = (Get-Content -Raw -LiteralPath $out.FullName -ErrorAction SilentlyContinue)
            Err = (Get-Content -Raw -LiteralPath $err.FullName -ErrorAction SilentlyContinue)
        }
    } finally {
        Remove-Item -LiteralPath $out.FullName, $err.FullName -Force -ErrorAction SilentlyContinue
    }
}

$script:checker = Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) 'check-factory-progress.ps1'
if (-not (Test-Path -LiteralPath $script:checker)) { throw "checker not found: $script:checker" }
$script:root = Join-Path ([System.IO.Path]::GetTempPath()) ('factory-progress-tests-' + [guid]::NewGuid().ToString('n').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $script:root | Out-Null

function Write-Events([object[]]$events) {
    $path = Join-Path $script:root ([guid]::NewGuid().ToString('n') + '.jsonl')
    [System.IO.File]::WriteAllLines($path, [string[]]@($events | ForEach-Object { $_ | ConvertTo-Json -Compress }))
    return $path
}

Write-Host 'check-factory-progress.tests' -ForegroundColor Cyan

$healthy = Invoke-Progress (Write-Events @(
    @{ signature = 'read:a'; progress = $false },
    @{ signature = 'write:a'; progress = $true },
    @{ signature = 'read:b'; progress = $false },
    @{ signature = 'verify:b'; progress = $true }
))
Assert ($healthy.Code -eq 0) 'progress events reset the idle counter'
Assert ([string]::IsNullOrWhiteSpace($healthy.Err)) 'healthy progress is silent on stderr'

$idle = Invoke-Progress (Write-Events @(
    @{ signature = 'read:a'; progress = $false },
    @{ signature = 'read:b'; progress = $false },
    @{ signature = 'read:c'; progress = $false },
    @{ signature = 'read:d'; progress = $false }
))
Assert ($idle.Code -ne 0 -and $idle.Err -match 'no progress') 'too many idle events fail'

$repeat = Invoke-Progress (Write-Events @(
    @{ signature = 'same-command'; progress = $false },
    @{ signature = 'same-command'; progress = $false },
    @{ signature = 'same-command'; progress = $false },
    @{ signature = 'same-command'; progress = $false }
)) -extra @('-MaxIdleEvents', '10')
Assert ($repeat.Code -ne 0 -and $repeat.Err -match 'repeated') 'repeated signatures fail even below the idle threshold'

$missingSignature = Join-Path $script:root 'missing-signature.jsonl'
[System.IO.File]::WriteAllText($missingSignature, '{"progress":true}')
$r = Invoke-Progress $missingSignature
Assert ($r.Code -ne 0 -and $r.Err -match 'missing signature') 'missing event signatures are rejected'

$badJson = Join-Path $script:root 'bad.jsonl'
[System.IO.File]::WriteAllText($badJson, '{not-json}')
$r = Invoke-Progress $badJson
Assert ($r.Code -ne 0 -and $r.Err -match 'not valid JSON') 'malformed event logs are rejected'

Remove-Item -LiteralPath $script:root -Recurse -Force -ErrorAction SilentlyContinue

if ($script:Failures -gt 0) {
    Write-Host ("check-factory-progress.tests: {0} assertion(s) failed out of {1}" -f $script:Failures, $script:Ran) -ForegroundColor Red
    exit 1
}
Write-Host ("check-factory-progress.tests: {0} assertions passed" -f $script:Ran) -ForegroundColor Green
exit 0
