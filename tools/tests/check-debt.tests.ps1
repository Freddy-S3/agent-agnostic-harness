<#
.SYNOPSIS
  Tests for tools/check-debt.ps1, written by constructing the debt rather than by reading
  the code.

.DESCRIPTION
  Two things have to be true of a pruning pass, and they pull against each other. It has to
  actually find debt, and it must never remove anything. So the cases below plant each
  class of debt in a scratch tree and assert it is reported, then assert that everything
  planted is still on disk afterwards.

  The last group is the one that matters most. This harness has already lost a skill file
  to an over-eager cleanup, and every earlier draft of this very script produced false
  positives: it proposed removing the main clone because 'main' is contained in
  origin/main, and it reported a skill as unreferenced while another skill plainly
  referenced it. Both are asserted against here, because a reporter that cries wolf gets
  ignored, and an ignored reporter is worse than no reporter.

.EXAMPLE
  powershell -NoProfile -File tools\tests\check-debt.tests.ps1
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
$check    = Join-Path $toolsDir 'check-debt.ps1'
if (-not (Test-Path $check)) { throw "check-debt.ps1 not found at $check" }

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("debt-tests-" + [guid]::NewGuid().ToString('n').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $root | Out-Null

function New-Scratch {
    $d = Join-Path $root ([guid]::NewGuid().ToString('n').Substring(0, 8))
    foreach ($rel in 'instructions/rules', 'skills', 'templates/scheduled-tasks', 'home/.claude/scheduled-tasks') {
        New-Item -ItemType Directory -Force -Path (Join-Path $d $rel) | Out-Null
    }
    Set-Content -LiteralPath (Join-Path $d 'instructions/AGENTS.md') -Value "# core`r`n" -Encoding UTF8
    return $d
}

function Invoke-Check($dir, $extra) {
    $o = New-TemporaryFile
    $e = New-TemporaryFile
    try {
        $a = @('-NoProfile', '-File', "`"$check`"", '-RepoRoot', "`"$dir`"", '-HostHome', "`"$(Join-Path $dir 'home')`"")
        if ($extra) { $a += $extra }
        $p = Start-Process -FilePath 'powershell' -ArgumentList $a `
                -RedirectStandardOutput $o.FullName -RedirectStandardError $e.FullName `
                -NoNewWindow -PassThru -Wait
        $out = Get-Content -LiteralPath $o.FullName -Raw -ErrorAction SilentlyContinue
        $err = Get-Content -LiteralPath $e.FullName -Raw -ErrorAction SilentlyContinue
        return @{ code = $p.ExitCode; text = "$out`n$err" }
    } finally {
        foreach ($f in $o, $e) { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue }
    }
}

# --- E: a rule file nothing triggers -------------------------------------------------
$d = New-Scratch
$orphanRule = Join-Path $d 'instructions/rules/nobody-triggers-me.md'
Set-Content -LiteralPath $orphanRule -Value "# orphan`r`n" -Encoding UTF8
$r = Invoke-Check $d @('-Class', 'E')
Assert ($r.text -match 'nobody-triggers-me\.md') 'a rule file with no trigger row is reported'
Assert ($r.text -match 'no session will read it') 'the finding says why an untriggered rule is debt'
Assert (Test-Path -LiteralPath $orphanRule) 'the untriggered rule file is NOT deleted'

# A rule that IS triggered must not be reported. Without this the class is satisfied by
# reporting every rule file that exists.
$d2 = New-Scratch
Set-Content -LiteralPath (Join-Path $d2 'instructions/rules/wired.md') -Value "# wired`r`n" -Encoding UTF8
Set-Content -LiteralPath (Join-Path $d2 'instructions/AGENTS.md') `
    -Value "# core`r`n| ``rules/wired.md`` | when something happens |`r`n" -Encoding UTF8
$r = Invoke-Check $d2 @('-Class', 'E')
Assert ($r.text -notmatch 'wired\.md') 'a triggered rule file is not reported as debt'

# README.md in rules/ is documentation, not a rule, and is exempt.
$d3 = New-Scratch
Set-Content -LiteralPath (Join-Path $d3 'instructions/rules/README.md') -Value "# readme`r`n" -Encoding UTF8
$r = Invoke-Check $d3 @('-Class', 'E')
Assert ($r.text -notmatch 'rules/README\.md') 'the rules README is not reported as an untriggered rule'

# --- D: a skill nothing references, and one that is referenced ------------------------
$d = New-Scratch
New-Item -ItemType Directory -Force -Path (Join-Path $d 'skills/lonely') | Out-Null
Set-Content -LiteralPath (Join-Path $d 'skills/lonely/SKILL.md') -Value "# lonely`r`n" -Encoding UTF8
New-Item -ItemType Directory -Force -Path (Join-Path $d 'skills/popular') | Out-Null
Set-Content -LiteralPath (Join-Path $d 'skills/popular/SKILL.md') -Value "# popular`r`n" -Encoding UTF8
New-Item -ItemType Directory -Force -Path (Join-Path $d 'skills/router') | Out-Null
Set-Content -LiteralPath (Join-Path $d 'skills/router/SKILL.md') -Value "# router`r`nRoutes to /popular when asked.`r`n" -Encoding UTF8
$r = Invoke-Check $d @('-Class', 'D')
Assert ($r.text -match 'skills/lonely') 'a skill nothing references is reported'
# This is the regression: an earlier matcher reported /voice while skills/wiki referenced it.
Assert ($r.text -notmatch 'skills/popular') 'a skill referenced by ANOTHER skill is not reported'
Assert (Test-Path -LiteralPath (Join-Path $d 'skills/lonely/SKILL.md')) 'the unreferenced skill is NOT deleted'
Assert ($r.text -match 'deliberately user-invoked-only') 'the skill finding states the judgement the reader has to apply'

# --- F: a template with no installed task --------------------------------------------
$d = New-Scratch
New-Item -ItemType Directory -Force -Path (Join-Path $d 'templates/scheduled-tasks/never-installed') | Out-Null
Set-Content -LiteralPath (Join-Path $d 'templates/scheduled-tasks/never-installed/SKILL.md') -Value "x`r`n" -Encoding UTF8
$r = Invoke-Check $d @('-Class', 'F')
Assert ($r.text -match 'never-installed') 'a template with no installed task is reported'
Assert ($r.text -match 'weakest signal') 'the template finding admits how weak the signal is'

# --- A: an unverifiable enumeration must not be reported as an orphan -----------------
#     The real bug this catches: under Git Bash, schtasks returned nothing at all, and the
#     first version read that empty result as proof that no task backed any prompt. It
#     flagged every prompt on the strength of a tool that had not worked.
$aSource = Get-Content -LiteralPath $check -Raw -Encoding UTF8
Assert ($aSource -match 'if \(\$text\.Trim\(\)\.Length -gt 0\)') `
    'class A treats an empty successful enumeration as a failed enumeration'
Assert ($aSource -match 'UNVERIFIED') `
    'class A reports an unverifiable prompt as UNVERIFIED rather than as an orphan'
Assert ($aSource -match 'Not evidence of an orphan') `
    'the unverified finding says explicitly that it is not evidence'

# --- B: the default branch is never proposed for removal ------------------------------
#     An earlier run proposed removing the main clone, because 'main' is trivially
#     contained in origin/main.
Assert ($aSource -match "\`$b -eq 'main' -or \`$b -eq 'master'") `
    'class B skips the tree holding the default branch'

# --- the no-delete guarantee ----------------------------------------------------------
#     Asserted against the source, not only against behaviour: the promise is that no such
#     flag exists, and a behavioural test can only show that the flag was not passed.
Assert ($aSource -notmatch '(?im)\[switch\]\s*\$Fix')    'check-debt.ps1 has no -Fix switch'
Assert ($aSource -notmatch '(?im)\[switch\]\s*\$Force')  'check-debt.ps1 has no -Force switch'
Assert ($aSource -notmatch '(?im)\[switch\]\s*\$Delete') 'check-debt.ps1 has no -Delete switch'
Assert ($aSource -notmatch '(?m)^\s*Remove-Item -LiteralPath \$f\.What') 'check-debt.ps1 never removes a finding'
# Remove-Item appears only inside the temp-file cleanup of Invoke-Git and inside proposal
# TEXT. Anything else would be the script acting on its own findings.
$removeLines = @(($aSource -split "`n") | Where-Object { $_ -match 'Remove-Item' })
foreach ($l in $removeLines) {
    Assert (($l -match '\$f\.FullName') -or ($l -match 'Remove-Item -Recurse `"')) `
        "every Remove-Item in check-debt.ps1 is temp-file cleanup or proposal text: $($l.Trim())"
}

# --- a clean tree reports nothing, and exits zero either way ---------------------------
$d = New-Scratch
$r = Invoke-Check $d
Assert ($r.code -eq 0) 'a clean tree exits zero'
Assert ($r.text -match 'nothing to prune') 'a clean tree says so'

$d = New-Scratch
Set-Content -LiteralPath (Join-Path $d 'instructions/rules/orphan.md') -Value "# orphan`r`n" -Encoding UTF8
$r = Invoke-Check $d
Assert ($r.code -eq 0) 'a tree WITH findings still exits zero - this is a report, not a gate'
Assert ($r.text -match 'Nothing was removed') 'the report states that nothing was removed'
Assert ($r.text -match 'deletes nothing') 'the header states the no-delete guarantee'

Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ''
if ($script:Failures -gt 0) {
    Write-Host ("check-debt.tests: {0} assertion(s) failed out of {1}" -f $script:Failures, $script:Ran) -ForegroundColor Red
    exit 1
}
Write-Host ("check-debt.tests: {0} assertions passed" -f $script:Ran) -ForegroundColor Green
exit 0
