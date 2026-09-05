<#
.SYNOPSIS
  Tests for tools/check-premise-step.ps1, written by constructing each break rather than
  by reading the code.

.DESCRIPTION
  The check exists because the premise rule is prose and prose rots silently. So the tests
  break it in every way an ordinary edit could: delete the rule, drop the AGENTS.md
  trigger row, remove the Gate 1 Premise line, unhook /freddy, and - the one that started
  all this - set disable-model-invocation on a grill skill so the escalation route dies
  with no error anywhere.

  Each case copies the real repository into a scratch tree, breaks exactly one thing, and
  asserts the check fails and names it. The final case asserts the unmodified repository
  passes, without which every assertion above would be satisfied by a check that always
  fails.

.EXAMPLE
  powershell -NoProfile -File tools\tests\check-premise-step.tests.ps1
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

$toolsDir = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$repoRoot = Split-Path -Parent $toolsDir
$check    = Join-Path $toolsDir 'check-premise-step.ps1'
if (-not (Test-Path $check)) { throw "check-premise-step.ps1 not found at $check" }

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("premise-tests-" + [guid]::NewGuid().ToString('n').Substring(0, 8))

# Copy only what the check reads. Copying the whole repository would drag in .git and every
# worktree artifact for no benefit.
function New-Fixture {
    $dir = Join-Path $root ([guid]::NewGuid().ToString('n').Substring(0, 8))
    foreach ($rel in 'instructions/rules', 'skills/ship', 'skills/freddy', 'skills/grilling', 'skills/grill-me', 'skills/grill-with-docs') {
        New-Item -ItemType Directory -Force -Path (Join-Path $dir $rel) | Out-Null
    }
    Copy-Item (Join-Path $repoRoot 'instructions/AGENTS.md')                        (Join-Path $dir 'instructions/AGENTS.md')
    Copy-Item (Join-Path $repoRoot 'instructions/rules/premise-interrogation.md')   (Join-Path $dir 'instructions/rules/premise-interrogation.md')
    foreach ($s in 'ship', 'freddy', 'grilling', 'grill-me', 'grill-with-docs') {
        Copy-Item (Join-Path $repoRoot "skills/$s/SKILL.md") (Join-Path $dir "skills/$s/SKILL.md")
    }
    return $dir
}

function Invoke-Check($dir) {
    $o = New-TemporaryFile
    $e = New-TemporaryFile
    try {
        $p = Start-Process -FilePath 'powershell' `
                -ArgumentList @('-NoProfile', '-File', "`"$check`"", '-RepoRoot', "`"$dir`"") `
                -RedirectStandardOutput $o.FullName -RedirectStandardError $e.FullName `
                -NoNewWindow -PassThru -Wait
        $out = Get-Content -LiteralPath $o.FullName -Raw -ErrorAction SilentlyContinue
        $err = Get-Content -LiteralPath $e.FullName -Raw -ErrorAction SilentlyContinue
        return @{ code = $p.ExitCode; text = "$out`n$err" }
    } finally {
        foreach ($f in $o, $e) { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue }
    }
}

function Edit-File($dir, $rel, $find, $replace) {
    $p = Join-Path $dir $rel
    $t = Get-Content -LiteralPath $p -Raw -Encoding UTF8
    $t = $t -replace $find, $replace
    Set-Content -LiteralPath $p -Value $t -Encoding UTF8 -NoNewline
}

# 0. The unmodified repository passes. Without this control the whole file is satisfied by
#    a check that fails unconditionally.
$d = New-Fixture
$r = Invoke-Check $d
Assert ($r.code -eq 0) 'the unmodified repository passes the premise check'
Assert ($r.text -match 'model-invocable') 'the passing run states what it verified'

# 1. The rule file is deleted.
$d = New-Fixture
Remove-Item (Join-Path $d 'instructions/rules/premise-interrogation.md') -Force
$r = Invoke-Check $d
Assert ($r.code -ne 0) 'a deleted rule file fails the check'
Assert ($r.text -match 'premise-interrogation rule is gone') 'the failure names the missing rule'

# 2. The AGENTS.md trigger row is removed, so no session ever reads the rule. The rule file
#    still exists, so check-rule-triggers.ps1 would see nothing wrong here.
$d = New-Fixture
Edit-File $d 'instructions/AGENTS.md' '(?m)^.*premise-interrogation\.md.*$' ''
$r = Invoke-Check $d
Assert ($r.code -ne 0) 'a removed AGENTS.md trigger row fails the check'
Assert ($r.text -match 'no session will read it') 'the failure says the rule became unreachable'

# 3. The Gate 1 Premise line is dropped, so Faruk approves without seeing the premise.
$d = New-Fixture
Edit-File $d 'skills/ship/SKILL.md' '(?m)^Premise:.*$' ''
$r = Invoke-Check $d
Assert ($r.code -ne 0) 'a missing Gate 1 Premise line fails the check'
Assert ($r.text -match 'approves without seeing') 'the failure says why the Gate 1 line matters'

# 4. /freddy stops interrogating the premise before owner selection.
$d = New-Fixture
Edit-File $d 'skills/freddy/SKILL.md' 'premise-interrogation\.md' 'some-other-rule.md'
$r = Invoke-Check $d
Assert ($r.code -ne 0) 'unhooking /freddy fails the check'
Assert ($r.text -match 'before owner selection') 'the failure names the /freddy overlay'

# 5. The escalation route dies. This is the reported blocker: a grill skill made
#    user-invocable-only, which breaks routing with no error message anywhere.
foreach ($skill in 'grilling', 'grill-me', 'grill-with-docs') {
    $d = New-Fixture
    # The optional CR matters: the checked-in skills use CRLF, so '$' without it never
    # matches, the fixture would be left unmodified, and the case would pass vacuously.
    Edit-File $d "skills/$skill/SKILL.md" '(?m)^user-invocable: true\r?$' "user-invocable: true`r`ndisable-model-invocation: true"
    $r = Invoke-Check $d
    Assert ($r.code -ne 0) "disable-model-invocation on /$skill fails the check"
    Assert ($r.text -match 'silently stops working') "the /$skill failure says the breakage is silent"
    Assert ($r.text -match [regex]::Escape("skills/$skill/SKILL.md")) "the failure names skills/$skill/SKILL.md"
}

# 6. The rule is gutted down to a heading. It still exists and is still triggered, so every
#    path check above passes; only the content assertions catch it.
$d = New-Fixture
Set-Content -LiteralPath (Join-Path $d 'instructions/rules/premise-interrogation.md') `
    -Value "# Premise interrogation`r`n`r`nAsk some questions first." -Encoding UTF8
$r = Invoke-Check $d
Assert ($r.code -ne 0) 'a gutted rule file fails the check'
Assert ($r.text -match 'the four questions are the rule') 'the failure says the four questions are missing'

Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ''
if ($script:Failures -gt 0) {
    Write-Host ("check-premise-step.tests: {0} assertion(s) failed out of {1}" -f $script:Failures, $script:Ran) -ForegroundColor Red
    exit 1
}
Write-Host ("check-premise-step.tests: {0} assertions passed" -f $script:Ran) -ForegroundColor Green
exit 0
