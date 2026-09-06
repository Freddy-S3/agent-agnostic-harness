<# Tests the folder-family guard by constructing the over-limit state. #>
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

$toolsDir = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$check = Join-Path $toolsDir 'check-folder-hygiene.ps1'
$root = Join-Path ([IO.Path]::GetTempPath()) ("folder-hygiene-tests-" + [guid]::NewGuid().ToString('n').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $root | Out-Null

function New-Folder($name) { New-Item -ItemType Directory -Force -Path (Join-Path $root $name) | Out-Null }
function Invoke-Check([string]$action, [string]$candidate, [string]$family) {
    $o = New-TemporaryFile
    $e = New-TemporaryFile
    try {
        $args = @('-NoProfile', '-NonInteractive', '-File', $check, '-Action', $action, '-WorkspaceRoot', $root)
        if ($candidate) { $args += @('-CandidatePath', $candidate) }
        if ($family) { $args += @('-Family', $family) }
        $p = Start-Process -FilePath 'powershell' -ArgumentList $args -RedirectStandardOutput $o.FullName -RedirectStandardError $e.FullName -NoNewWindow -PassThru -Wait
        $out = Get-Content -LiteralPath $o.FullName -Raw -ErrorAction SilentlyContinue
        $err = Get-Content -LiteralPath $e.FullName -Raw -ErrorAction SilentlyContinue
        return @{ code = $p.ExitCode; text = "$out`n$err" }
    } finally {
        foreach ($f in $o, $e) { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue }
    }
}

New-Folder 'agent-agnostic-harness'
New-Folder 'aah-one'
New-Folder 'agent-agnostic-harness-dashboard'
New-Item -ItemType Directory -Force -Path (Join-Path $root '_archive\aah-old') | Out-Null
New-Folder 'agent-operations-console'
New-Folder 'agent-operations-console-one'
New-Folder 'agent-operations-console-two'
New-Folder 'agent-operations-console-three'

$r = Invoke-Check 'check' $null $null
Assert ($r.code -eq 1) 'the workspace check catches an unrelated over-limit family'

$harness = Join-Path $root 'agent-agnostic-harness'
$r = Invoke-Check 'check' $harness $null
Assert ($r.code -eq 0) 'a current family check ignores unrelated over-limit folders'
Assert ([string]::IsNullOrWhiteSpace($r.text)) 'a passing family check is silent'

$fourth = Join-Path $root 'aah-four'
$r = Invoke-Check 'assert-add' $fourth 'agent-agnostic-harness'
Assert ($r.code -eq 1) 'a fourth harness folder is refused'
Assert ($r.text -match 'FOLDER_LIMIT') 'the refusal explains the limit'
Assert ($r.text -match 'agent-agnostic-harness') 'the refusal names the affected family'

$r = Invoke-Check 'assert-add' $fourth $null
Assert ($r.code -eq 1) 'a known alias infers the existing family when -Family is omitted'

New-Folder 'aah-four'
$r = Invoke-Check 'check' $null $null
Assert ($r.code -eq 1) 'an existing fourth folder fails the check'
Assert ($r.text -match '4 active folders') 'the failure reports the observed count'

$r = Invoke-Check 'list' $null $null
Assert ($r.code -eq 0) 'the inventory action succeeds'
Assert ($r.text -match 'agent-agnostic-harness\s+4') 'the inventory groups legacy aliases together'

# Git exports GIT_DIR while a hook runs. Probing sibling repositories must ignore that
# ambient repository or every origin would be misidentified as the committing family.
$gitOne = Join-Path $root 'shared-one'
$gitTwo = Join-Path $root 'shared-two'
New-Item -ItemType Directory -Force -Path $gitOne, $gitTwo | Out-Null
& git -C $gitOne init --quiet
& git -C $gitTwo init --quiet
& git -C $gitOne config remote.origin.url 'https://github.com/test/shared.git'
& git -C $gitTwo config remote.origin.url 'https://github.com/test/shared.git'
$oldGitDir = $env:GIT_DIR
$env:GIT_DIR = (Join-Path $gitOne '.git')
try {
    $r = Invoke-Check 'list' $null $null
} finally {
    if ($null -eq $oldGitDir) { Remove-Item Env:GIT_DIR -ErrorAction SilentlyContinue } else { $env:GIT_DIR = $oldGitDir }
}
Assert ($r.text -match 'repo:test/shared\s+2') 'Git hook ambient state does not collapse sibling origins'

Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
if ($script:Failures -gt 0) {
    Write-Host ("check-folder-hygiene.tests: {0} assertion(s) failed out of {1}" -f $script:Failures, $script:Ran) -ForegroundColor Red
    exit 1
}
Write-Host ("check-folder-hygiene.tests: {0} assertions passed" -f $script:Ran) -ForegroundColor Green
exit 0
