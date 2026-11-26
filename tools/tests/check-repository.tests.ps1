$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $PSCommandPath
$checker = Join-Path (Split-Path -Parent $scriptRoot) 'check-repository.ps1'
$root = Join-Path ([IO.Path]::GetTempPath()) ('check-repository-tests-' + [guid]::NewGuid().ToString('N'))
$plain = Join-Path $root 'plain'
$nested = Join-Path $root 'nested-parent'
$repo = Join-Path $root 'repo'
$assertions = 0

function Assert-Equal([object] $Actual, [object] $Expected, [string] $Message) {
    if ($Actual -ne $Expected) { throw "$Message. Expected '$Expected', got '$Actual'." }
    $script:assertions++
}

function Invoke-Check([string[]] $Arguments) {
    $output = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $checker @Arguments 2>&1)
    [pscustomobject]@{ Code = $LASTEXITCODE; Json = (($output | Where-Object { $_ -is [string] }) -join [Environment]::NewLine | ConvertFrom-Json) }
}

try {
    New-Item -ItemType Directory -Path $plain, $nested, $repo -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $plain 'notes.txt') -Value 'plain folder'

    $missing = Invoke-Check @('-Path', $plain)
    Assert-Equal $missing.Code 2 'Plain folders should be reported as missing repositories'
    Assert-Equal $missing.Json.status 'missing' 'Missing repository status'
    Assert-Equal $missing.Json.action 'initialize-after-approval' 'Missing repository action'

    $initialized = Invoke-Check @('-Path', $plain, '-Initialize')
    Assert-Equal $initialized.Code 0 'Initialization should succeed after explicit opt-in'
    Assert-Equal $initialized.Json.status 'initialized' 'Initialized repository status'
    Assert-Equal $initialized.Json.hasCommit $false 'Initialization should not invent a baseline commit'

    & git -C $repo init -b main | Out-Null
    & git -C $repo config user.name 'repository-test'
    & git -C $repo config user.email 'repository-test@example.invalid'
    & git -C $repo config commit.gpgsign false
    Set-Content -LiteralPath (Join-Path $repo 'README.md') -Value '# test'
    & git -C $repo add README.md
    & git -c core.hooksPath= -c commit.gpgsign=false -C $repo commit --no-verify -m 'Initial test commit' | Out-Null
    $found = Invoke-Check @('-Path', $repo)
    Assert-Equal $found.Code 0 'Existing repositories should pass'
    Assert-Equal $found.Json.status 'found' 'Found repository status'
    Assert-Equal $found.Json.hasCommit $true 'Existing repository commit detection'

    $nestedRepo = Join-Path $nested 'app'
    New-Item -ItemType Directory -Path $nestedRepo -Force | Out-Null
    & git -C $nestedRepo init -b main | Out-Null
    $nestedResult = Invoke-Check @('-Path', $nested)
    Assert-Equal $nestedResult.Code 2 'Nested repositories should require root selection'
    Assert-Equal $nestedResult.Json.status 'nested-candidate' 'Nested candidate status'
    Assert-Equal @($nestedResult.Json.nestedCandidates).Count 1 'Nested candidate count'

    $unsafeInit = Invoke-Check @('-Path', $nested, '-Initialize')
    Assert-Equal $unsafeInit.Code 3 'Parent initialization should be blocked when a nested repository exists'
} finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}

Write-Output "check-repository.tests: $assertions assertions passed"
