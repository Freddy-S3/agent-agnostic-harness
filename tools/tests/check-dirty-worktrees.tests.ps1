$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $PSScriptRoot
$checker = Join-Path $scriptRoot 'check-dirty-worktrees.ps1'
$root = Join-Path ([IO.Path]::GetTempPath()) ('dirty-worktree-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root -Force | Out-Null

function Invoke-Git([string]$Path, [string[]]$Arguments) {
    & git -c "safe.directory=$Path" -c core.excludesFile= -c commit.gpgSign=false -c core.hooksPath= -C $Path @Arguments 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "git failed in ${Path}: $($Arguments -join ' ')" }
}

function Run-Checker([string]$Path) {
    $output = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $checker -RepositoryPath $Path 2>&1)
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($output -join "`n") }
}

try {
    $clean = Join-Path $root 'clean'
    New-Item -ItemType Directory -Path $clean -Force | Out-Null
    Invoke-Git $clean @('init', '--initial-branch=main')
    Invoke-Git $clean @('config', 'user.email', 'tests@example.invalid')
    Invoke-Git $clean @('config', 'user.name', 'dirty-worktree-test')
    Set-Content -LiteralPath (Join-Path $clean 'README.md') -Value 'clean' -Encoding utf8
    Invoke-Git $clean @('add', 'README.md')
    Invoke-Git $clean @('commit', '-m', 'fixture')
    $result = Run-Checker $clean
    if ($result.ExitCode -ne 0 -or $result.Output) { throw 'clean checkout should pass silently' }
    Write-Output 'PASS clean checkout'

    Add-Content -LiteralPath (Join-Path $clean 'README.md') -Value 'dirty'
    $result = Run-Checker $clean
    if ($result.ExitCode -ne 1 -or $result.Output -notmatch 'README\.md') { throw 'tracked change should fail' }
    Write-Output 'PASS tracked change fails'

    Invoke-Git $clean @('checkout', '--', 'README.md')
    New-Item -ItemType Directory -Path (Join-Path $clean 'memories/repo/tasks'), (Join-Path $clean 'tmp'), (Join-Path $clean 'tools/__pycache__'), (Join-Path $clean 'skills/test') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $clean 'memories/repo/tasks/handoff.md') -Value 'managed' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $clean 'tmp/output.bin') -Value 'generated' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $clean 'tools/__pycache__/cache.pyc') -Value 'generated' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $clean 'skills/test/SKILL.md.bak-20260906') -Value 'backup' -Encoding utf8
    $result = Run-Checker $clean
    if ($result.ExitCode -ne 0 -or $result.Output) { throw 'managed and generated artifacts should be ignored' }
    Write-Output 'PASS managed artifacts ignored'

    Set-Content -LiteralPath (Join-Path $clean 'docs.md') -Value 'real work' -Encoding utf8
    $result = Run-Checker $clean
    if ($result.ExitCode -ne 1 -or $result.Output -notmatch 'docs\.md') { throw 'untracked project work should fail' }
    Write-Output 'PASS untracked project work fails'
} finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
