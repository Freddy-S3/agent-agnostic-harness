<#
.SYNOPSIS
  Tests for tools/judge.ps1, written by constructing the failures rather than by reading
  the code.

.DESCRIPTION
  The thing this harness exists to prevent is a green run that means nothing. So every
  case below drives judge.ps1 into a state where it MUST report a problem: a judge that
  passes everything, a judge that fails everything, a judge that answers in prose, a judge
  that returns nothing, a judge that crashes, and an eval set with no rubric to judge
  against. If any of these came back clean, the harness would be certifying agreement it
  never obtained.

  The judge is stubbed. These tests cost nothing and make no network call - they test the
  harness, not the model. Whether the model's judgement is any good is what the expected
  verdicts in evals/*.eval.json answer, and that is a separate, billed run.

.EXAMPLE
  powershell -NoProfile -File tools\tests\judge.tests.ps1
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
$judge    = Join-Path $toolsDir 'judge.ps1'
if (-not (Test-Path $judge)) { throw "judge.ps1 not found at $judge" }

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("judge-tests-" + [guid]::NewGuid().ToString('n').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $root | Out-Null

# A stub judge is a .cmd that ignores its stdin and prints a fixed reply. That is exactly
# the adversary worth testing: a judge whose answer has nothing to do with the artifact.
function New-StubJudge($name, $lines) {
    $p = Join-Path $root "$name.cmd"
    $body = @('@echo off')
    foreach ($l in $lines) {
        if ($l -eq '') { $body += 'echo.' } else { $body += ("echo " + $l) }
    }
    [System.IO.File]::WriteAllLines($p, [string[]]$body)
    return $p
}

function New-EvalSet($name, $obj) {
    $p = Join-Path $root "$name.eval.json"
    ($obj | ConvertTo-Json -Depth 12) | Set-Content -LiteralPath $p -Encoding UTF8
    return $p
}

function Invoke-JudgeRun($setPath, $stubPath) {
    $o = New-TemporaryFile
    $e = New-TemporaryFile
    try {
        $args = @('-NoProfile', '-File', "`"$judge`"", '-EvalSet', "`"$setPath`"")
        if ($stubPath) { $args += @('-JudgeCommand', "`"$stubPath`"") }
        $p = Start-Process -FilePath 'powershell' -ArgumentList $args `
                -RedirectStandardOutput $o.FullName -RedirectStandardError $e.FullName `
                -NoNewWindow -PassThru -Wait
        $out = (Get-Content -LiteralPath $o.FullName -Raw -ErrorAction SilentlyContinue)
        $err = (Get-Content -LiteralPath $e.FullName -Raw -ErrorAction SilentlyContinue)
        return @{ code = $p.ExitCode; text = "$out`n$err" }
    } finally {
        foreach ($f in $o, $e) { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue }
    }
}

# One eval set holding a matched pair: the same shape of artifact, one expected to pass and
# one expected to fail. Any judge with a fixed answer must be wrong about exactly one of
# them, which is what makes a rubber-stamp judge detectable at all.
$pairSet = @{
    name   = 'stub-pair'
    aim    = 'A test fixture with one case that should pass and one that should fail.'
    # The rubric deliberately avoids the literal tokens, so the honest stub below can
    # grep the rendered prompt for the artifact text without matching the rubric itself.
    rubric = @('FAIL if the artifact text is the rejected token.', 'PASS otherwise.')
    cases  = @(
        @{ id = 'good-one'; expect = 'pass'; origin = 'fixture'; input = @{ text = 'GOOD' } },
        @{ id = 'bad-one';  expect = 'fail'; origin = 'fixture'; input = @{ text = 'BAD'  } }
    )
}

# 1. A judge that says PASS to everything must be caught on the case expected to fail.
#    This is the "a judge only ever observed passing is worthless" case.
$setPath   = New-EvalSet 'pair' $pairSet
$alwaysYes = New-StubJudge 'always-pass' @('VERDICT: PASS', 'REASONING: looks fine to me')
$r = Invoke-JudgeRun $setPath $alwaysYes
Assert ($r.code -ne 0) 'a judge that passes everything must exit non-zero'
Assert ($r.text -match 'MISS\s+bad-one') 'a rubber-stamp judge is reported as a miss on the fail case'
Assert ($r.text -match 'expected fail, judge said pass') 'the miss names both the expected and the actual verdict'
Assert ($r.text -match 'looks fine to me') 'the judge reasoning is surfaced so the miss is actionable'
Assert ($r.text -match 'case origin: fixture') 'the miss names the case origin'

# 2. A judge that says FAIL to everything is equally broken and must be caught on the pass
#    case. A harness that only checked for false passes would certify this one clean.
$alwaysNo = New-StubJudge 'always-fail' @('VERDICT: FAIL', 'REASONING: no')
$r = Invoke-JudgeRun $setPath $alwaysNo
Assert ($r.code -ne 0) 'a judge that fails everything must exit non-zero'
Assert ($r.text -match 'MISS\s+good-one') 'a always-fail judge is reported as a miss on the pass case'

# 3. A judge that answers in prose has not answered. This must be an ERROR, never a pass.
$chatty = New-StubJudge 'chatty' @('I think this artifact is mostly fine, though it depends.')
$r = Invoke-JudgeRun $setPath $chatty
Assert ($r.code -ne 0) 'an unparseable judge reply must exit non-zero'
Assert ($r.text -match 'ERROR') 'an unparseable reply is reported as an error'
Assert ($r.text -match 'no parseable') 'the error says the verdict line could not be parsed'
Assert ($r.text -notmatch 'judge agreed with every expected verdict') 'prose is never scored as agreement'

# 4. A judge that returns nothing at all.
$silent = New-StubJudge 'silent' @()
$r = Invoke-JudgeRun $setPath $silent
Assert ($r.code -ne 0) 'a silent judge must exit non-zero'
Assert ($r.text -match 'ERROR') 'a silent judge is reported as an error'

# 5. A judge command that does not exist. The harness must say so rather than treat a
#    missing judge as a clean sweep.
$r = Invoke-JudgeRun $setPath (Join-Path $root 'no-such-judge.cmd')
Assert ($r.code -ne 0) 'a missing judge command must exit non-zero'
Assert ($r.text -notmatch 'judge agreed with every expected verdict') 'a missing judge is never a clean sweep'

# 6. An eval set with an empty rubric is rejected. A judge given no standard agrees with
#    whatever it is shown, so this is refused rather than run.
$noRubric = @{
    name   = 'no-rubric'
    aim    = 'An aim with nothing to judge against.'
    rubric = @()
    cases  = @(@{ id = 'x'; expect = 'pass'; origin = 'fixture'; input = @{ text = 'GOOD' } })
}
$r = Invoke-JudgeRun (New-EvalSet 'norubric' $noRubric) $alwaysYes
Assert ($r.code -ne 0) 'an eval set with an empty rubric must be rejected'
Assert ($r.text -match 'rubric is empty') 'the rejection says the rubric is empty'

# 7. A case with no expected verdict cannot score the judge, so the set is rejected.
$noExpect = @{
    name   = 'no-expect'
    aim    = 'A set whose case cannot score the judge.'
    rubric = @('FAIL if the artifact text is the rejected token.')
    cases  = @(@{ id = 'x'; origin = 'fixture'; input = @{ text = 'GOOD' } })
}
$r = Invoke-JudgeRun (New-EvalSet 'noexpect' $noExpect) $alwaysYes
Assert ($r.code -ne 0) 'a case with no expected verdict must be rejected'
Assert ($r.text -match "missing 'expect'") 'the rejection names the missing field'

# 8. A case with no origin is rejected. A case nobody can trace to a real incident is a
#    case nobody can argue with when it later disagrees with them.
$noOrigin = @{
    name   = 'no-origin'
    aim    = 'A set whose case cites no incident.'
    rubric = @('FAIL if the artifact text is the rejected token.')
    cases  = @(@{ id = 'x'; expect = 'pass'; input = @{ text = 'GOOD' } })
}
$r = Invoke-JudgeRun (New-EvalSet 'noorigin' $noOrigin) $alwaysYes
Assert ($r.code -ne 0) 'a case with no origin must be rejected'
Assert ($r.text -match "missing 'origin'") 'the rejection names the missing field'

# 9. The honest control: a judge that answers correctly on both cases is the only input
#    that produces a clean sweep. Without this the tests above could all be satisfied by a
#    harness that never passes anything.
$correct = Join-Path $root 'correct.cmd'
[System.IO.File]::WriteAllLines($correct, [string[]]@(
    '@echo off',
    'findstr /C:"BAD" > nul',
    'if %errorlevel%==0 (echo VERDICT: FAIL) else (echo VERDICT: PASS)',
    'echo REASONING: decided on the artifact text'
))
$r = Invoke-JudgeRun $setPath $correct
Assert ($r.code -eq 0) 'a judge that answers both cases correctly exits zero'
Assert ($r.text -match 'judge agreed with every expected verdict') 'the clean sweep is reported'

# 10. The repository's own eval sets are well formed and every set carries at least one
#     case expected to fail. A set of only passing cases proves nothing.
$evalsDir = Join-Path (Split-Path -Parent $toolsDir) 'evals'
$sets = @(Get-ChildItem -LiteralPath $evalsDir -Filter '*.eval.json')
Assert ($sets.Count -ge 3) 'the repository ships at least three eval sets'
foreach ($s in $sets) {
    $parsed = Get-Content -LiteralPath $s.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $failCases = @($parsed.cases | Where-Object { $_.expect -eq 'fail' })
    $passCases = @($parsed.cases | Where-Object { $_.expect -eq 'pass' })
    Assert ($failCases.Count -ge 1) "$($s.Name) carries at least one case expected to fail"
    Assert ($passCases.Count -ge 1) "$($s.Name) carries at least one case expected to pass"
    foreach ($c in $parsed.cases) {
        Assert (-not [string]::IsNullOrWhiteSpace($c.origin)) "$($s.Name)/$($c.id) cites an origin"
    }
}

Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ''
if ($script:Failures -gt 0) {
    Write-Host ("judge.tests: {0} assertion(s) failed out of {1}" -f $script:Failures, $script:Ran) -ForegroundColor Red
    exit 1
}
Write-Host ("judge.tests: {0} assertions passed" -f $script:Ran) -ForegroundColor Green
exit 0
