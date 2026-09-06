<#
.SYNOPSIS
  Run an LLM judge over an eval set of qualitative cases and report where the judge
  disagrees with the expected verdict.

.DESCRIPTION
  Every other check in this harness is binary and mechanical: does the control fire, is
  the PDF one page, does the guard trip. None of them can answer "is this resume bullet
  honest", "can this queue item be acted on from a phone", or "would this sentence read
  badly to a recruiter". Those questions have routed through Faruk, one at a time, which
  is why he has been the QA step.

  This script is the judge harness, not the judge. The judge is whatever command
  -JudgeCommand names; by default the Claude Code CLI in single-prompt mode. The script
  owns the parts a prose contract cannot enforce:

    - The eval set is data, not code. Cases carry an input, the aim they are judged
      against, and a rubric. Adding a case is editing JSON.
    - Every case carries an EXPECTED verdict, so the run scores the judge, not only the
      content. A judge that passes everything fails this harness loudly, which is the
      whole point - a judge only ever observed passing is worthless.
    - Cases carry an 'origin' naming the real incident they came from. A case nobody can
      trace to something that actually happened is a case nobody can argue with.
    - An unparseable judge reply is an ERROR, never a silent pass. The failure mode this
      exists to prevent is a green run that means the judge did not answer.
    - Judge reasoning is captured for every miss, so a failure is actionable rather than
      a bare verdict.

  WHERE THIS RUNS, AND WHAT IT COSTS. Deliberately not in install.ps1 and not in a
  pre-commit hook: it makes a network call per case and costs real money, and a gate that
  bills on every commit gets disabled. Run it (a) before publishing resume content, on
  the truthfulness set, (b) in /closing when queue items were written, on the
  self-containedness set, (c) before a PR body or commit message goes to a public repo,
  on the register set, and (d) whole, after editing any rubric, because editing a rubric
  is editing the test. One invocation per case: 15 cases across the three sets, roughly
  600-900 input tokens and under 200 output tokens each. On Sonnet that is a fraction of
  a cent per case and a few cents for a full sweep; on Opus a few times that. Cost scales
  with cases, so -EvalSet on one set is the normal invocation and -All is the
  rubric-change invocation.

  Ng's point applies directly: you have to evaluate the tests to ensure they correspond
  to your aims, and you will evolve them if not. The expected verdicts are how this
  harness notices that a rubric has stopped corresponding to its aim.

.PARAMETER EvalSet
  Path to a .eval.json file. Omit with -All to run every set in evals/.

.PARAMETER CaseId
  Run only the case with this id. Named CaseId, not Case, because PowerShell variable
  names are case-insensitive: a -Case parameter and a $case loop variable are one
  variable, and the filter silently skipped every case. Useful when iterating on one rubric line.

.PARAMETER JudgeCommand
  The judge to invoke. The rendered prompt is passed on stdin. Defaults to the Claude
  Code CLI in print mode.

.PARAMETER DryRun
  Render the prompts and print what would be sent without invoking the judge. Costs
  nothing and is how you inspect a prompt before paying for it.

.EXAMPLE
  .\judge.ps1 -EvalSet evals\resume-bullet-truthfulness.eval.json
  .\judge.ps1 -All
  .\judge.ps1 -EvalSet evals\public-language-register.eval.json -DryRun
#>
[CmdletBinding()]
param(
    [string] $EvalSet,
    [switch] $All,
    [string] $CaseId,
    [string] $JudgeCommand = 'claude -p',
    [switch] $DryRun,
    [string] $RepoRoot
)

$ErrorActionPreference = 'Stop'

# Resolved after the param block: $PSScriptRoot is not reliably populated inside a param
# default when the script is launched with -File.
if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }

function Get-EvalSetPaths {
    if ($All) {
        $dir = Join-Path $RepoRoot 'evals'
        if (-not (Test-Path -LiteralPath $dir)) { throw "no evals directory at $dir" }
        return @(Get-ChildItem -LiteralPath $dir -Filter '*.eval.json' | Sort-Object Name | ForEach-Object { $_.FullName })
    }
    if (-not $EvalSet) { throw 'specify -EvalSet <path> or -All' }
    if (-not (Test-Path -LiteralPath $EvalSet)) { throw "eval set not found: $EvalSet" }
    return @((Resolve-Path -LiteralPath $EvalSet).Path)
}

# A set missing an aim or a rubric is rejected rather than judged against nothing. Same
# reasoning as converge.ps1 rejecting a 'Done when:' that reads as prose: a check with no
# stated standard will agree with whatever it is shown.
function Assert-EvalSetShape($set, $path) {
    foreach ($field in 'name', 'aim', 'rubric', 'cases') {
        if (-not ($set.PSObject.Properties.Name -contains $field)) {
            throw "malformed eval set ${path}: missing '$field'"
        }
    }
    if (@($set.rubric).Count -eq 0) { throw "malformed eval set ${path}: rubric is empty" }
    if (@($set.cases).Count -eq 0) { throw "malformed eval set ${path}: no cases" }
    foreach ($c in $set.cases) {
        foreach ($field in 'id', 'expect', 'input', 'origin') {
            if (-not ($c.PSObject.Properties.Name -contains $field)) {
                throw "malformed case in ${path}: a case is missing '$field'"
            }
        }
        if (@('pass', 'fail') -notcontains $c.expect) {
            throw "malformed case '$($c.id)' in ${path}: expect must be 'pass' or 'fail', got '$($c.expect)'"
        }
    }
}

function New-JudgePrompt($set, $c) {
    $rubric    = ($set.rubric | ForEach-Object { "- $_" }) -join [Environment]::NewLine
    $artifact  = $c.input | ConvertTo-Json -Depth 10
    $nl        = [Environment]::NewLine
    $lines = @(
        'You are judging one artifact against a stated aim and rubric. Judge only what is in',
        'front of you. Do not speculate about intent, and do not soften a verdict because the',
        'artifact is well written.',
        '',
        'AIM',
        $set.aim,
        '',
        'RUBRIC',
        $rubric,
        '',
        'ARTIFACT UNDER JUDGEMENT (JSON)',
        $artifact,
        '',
        'Answer in exactly this form, with no preamble and no markdown:',
        'VERDICT: PASS',
        'REASONING: <one or two sentences naming the specific rubric line that decided it, and',
        'quoting the words in the artifact that triggered it>',
        '',
        'VERDICT must be the single word PASS or FAIL, alone on the first line.'
    )
    return ($lines -join $nl)
}

# The judge's reply is parsed strictly. Anything that is not an unambiguous PASS or FAIL on
# the VERDICT line is an error, so a judge returning prose, an apology, or an empty string
# can never be scored as agreement.
function Read-Verdict($raw) {
    if ([string]::IsNullOrWhiteSpace($raw)) { return @{ ok = $false; why = 'judge returned nothing' } }
    $m = [regex]::Match($raw, '(?im)^\s*VERDICT:\s*(PASS|FAIL)\s*$')
    if (-not $m.Success) {
        $head = (($raw -split "`n" | Select-Object -First 3) -join ' | ').Trim()
        return @{ ok = $false; why = "no parseable 'VERDICT: PASS|FAIL' line; reply began: $head" }
    }
    $r = [regex]::Match($raw, '(?im)^\s*REASONING:\s*(.+)$')
    $reason = if ($r.Success) { ($r.Groups[1].Value -replace '\s+', ' ').Trim() } else { '(no reasoning given)' }
    return @{ ok = $true; verdict = $m.Groups[1].Value.ToLower(); reasoning = $reason }
}

function Invoke-Judge($prompt) {
    $in  = New-TemporaryFile
    $out = New-TemporaryFile
    $err = New-TemporaryFile
    try {
        [System.IO.File]::WriteAllText($in.FullName, $prompt)
        # cmd /c so the judge command may be a full command line carrying its own
        # arguments, and so stdin redirection behaves the same whatever the judge is.
        $line = "$JudgeCommand < `"$($in.FullName)`""
        $p = Start-Process -FilePath $env:ComSpec -ArgumentList '/c', $line `
                -RedirectStandardOutput $out.FullName -RedirectStandardError $err.FullName `
                -NoNewWindow -PassThru -Wait
        $stdout = Get-Content -LiteralPath $out.FullName -Raw -ErrorAction SilentlyContinue
        $stderr = Get-Content -LiteralPath $err.FullName -Raw -ErrorAction SilentlyContinue
        return @{ code = $p.ExitCode; out = $stdout; err = $stderr }
    } finally {
        foreach ($f in $in, $out, $err) {
            Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
        }
    }
}

$paths  = Get-EvalSetPaths
$misses = New-Object System.Collections.Generic.List[string]
$errors = New-Object System.Collections.Generic.List[string]
$ran    = 0
$agreed = 0

foreach ($path in $paths) {
    $set = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-EvalSetShape $set $path

    Write-Host $set.name -ForegroundColor Cyan
    foreach ($c in $set.cases) {
        if ($CaseId -and $c.id -ne $CaseId) { continue }
        $prompt = New-JudgePrompt $set $c

        if ($DryRun) {
            Write-Host ("  [dry-run] {0} expect={1}  prompt {2} chars" -f $c.id, $c.expect, $prompt.Length)
            $ran++
            continue
        }

        $res = Invoke-Judge $prompt
        $ran++

        if ($res.code -ne 0 -and [string]::IsNullOrWhiteSpace($res.out)) {
            $errors.Add("$($set.name)/$($c.id): judge command exited $($res.code): $(($res.err -replace '\s+',' ').Trim())")
            Write-Host "  ERROR $($c.id)" -ForegroundColor Red
            continue
        }

        $parsed = Read-Verdict $res.out
        if (-not $parsed.ok) {
            $errors.Add("$($set.name)/$($c.id): $($parsed.why)")
            Write-Host "  ERROR $($c.id)" -ForegroundColor Red
            continue
        }

        if ($parsed.verdict -eq $c.expect) {
            $agreed++
            Write-Host ("  ok    {0} ({1})" -f $c.id, $parsed.verdict) -ForegroundColor DarkGray
        } else {
            $misses.Add("$($set.name)/$($c.id): expected $($c.expect), judge said $($parsed.verdict)`n      judge reasoning: $($parsed.reasoning)`n      case origin: $($c.origin)")
            Write-Host ("  MISS  {0}: expected {1}, judge said {2}" -f $c.id, $c.expect, $parsed.verdict) -ForegroundColor Red
        }
    }
}

Write-Host ''
Write-Host ("cases run: {0}; judge agreed: {1}; missed: {2}; errored: {3}" -f $ran, $agreed, $misses.Count, $errors.Count)

if ($DryRun) {
    Write-Host 'dry run - no judge was invoked and nothing was billed'
    exit 0
}

if ($errors.Count -gt 0) {
    Write-Host ''
    Write-Host 'judge did not return a usable verdict:' -ForegroundColor Red
    foreach ($e in $errors) { Write-Host "  $e" -ForegroundColor Red }
}
if ($misses.Count -gt 0) {
    Write-Host ''
    Write-Host 'judge disagreed with the expected verdict:' -ForegroundColor Red
    foreach ($m in $misses) { Write-Host "  $m" -ForegroundColor Red }
    Write-Host ''
    Write-Host 'A miss is not automatically the judge being wrong. Read the reasoning: either the'
    Write-Host 'rubric no longer says what you meant, or the case is mislabelled, or the judge is'
    Write-Host 'genuinely wrong. Evolve whichever one is at fault.'
}

if ($errors.Count -gt 0 -or $misses.Count -gt 0) { exit 1 }

Write-Host 'judge agreed with every expected verdict' -ForegroundColor Green
exit 0
