<#
.SYNOPSIS
  Tests for tools/strip-pr-attribution.ps1, written by constructing the trailer rather
  than by reading the code.

.DESCRIPTION
  The filter exists because the prose version of this rule was violated 33 times. So the
  cases below feed it every shape the trailer actually appeared in - link form, bare form,
  emoji, horizontal rule above it, a commit-style Co-Authored-By line, one stranded
  mid-body - and assert the output is clean.

  Two negative cases matter as much as the positives. A filter that deletes any line
  mentioning Claude Code would eat harness PR #7, whose body legitimately explains that
  the commit-msg hook strips a `Co-Authored-By: Claude` trailer. And a body with no
  trailer must come back byte-for-byte unchanged apart from tail normalisation, or every
  PR body starts drifting through the filter.

.EXAMPLE
  powershell -NoProfile -File tools\tests\strip-pr-attribution.tests.ps1
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

$tool = Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) 'strip-pr-attribution.ps1'
if (-not (Test-Path $tool)) { throw "strip-pr-attribution.ps1 not found at $tool" }

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("pr-attr-" + [guid]::NewGuid().ToString('n').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $root | Out-Null

# Run through a file, which is the path `gh pr create --body-file` actually uses.
function Invoke-Strip([string] $body) {
    $f = Join-Path $root ([guid]::NewGuid().ToString('n').Substring(0, 8) + '.md')
    [System.IO.File]::WriteAllText($f, $body)
    & powershell -NoProfile -File $tool -Path $f | Out-Null
    return [System.IO.File]::ReadAllText($f)
}

function Invoke-Check([string] $body) {
    $f = Join-Path $root ([guid]::NewGuid().ToString('n').Substring(0, 8) + '.md')
    [System.IO.File]::WriteAllText($f, $body)
    & powershell -NoProfile -File $tool -Path $f -Check 2>&1 | Out-Null
    return $LASTEXITCODE
}

$robot = [char]::ConvertFromUtf32(0x1F916)
$link = 'Generated with [Claude Code](https://claude.com/claude-code)'

$shapes = @{
    'link form with emoji'   = "Real body.`n`nMore detail.`n`n$robot $link`n"
    'link form no emoji'     = "Real body.`n`n$link`n"
    'bare text form'         = "Real body.`n`n$robot Generated with Claude Code`n"
    'horizontal rule above'  = "Real body.`n`n---`n$robot $link`n"
    'commit trailer leaked'  = "Real body.`n`nCo-Authored-By: Claude Opus 5 <noreply@anthropic.com>`n"
    'stranded mid-body'      = "Intro.`n`n$robot $link`n`nClosing paragraph that must survive.`n"
    'trailing whitespace'    = "Real body.`n`n$robot $link   `n"
    'CRLF line endings'      = "Real body.`r`n`r`n$robot $link`r`n"
}

foreach ($name in $shapes.Keys) {
    $out = Invoke-Strip $shapes[$name]
    Assert ($out -notmatch 'Generated with')   "$name - 'Generated with' removed"
    Assert ($out -notmatch 'Co-Authored-By')   "$name - 'Co-Authored-By' removed"
    Assert (-not $out.Contains($robot))        "$name - the emoji is not left stranded"
    Assert ($out -match 'Real body|Intro')     "$name - the real body survives"
    Assert ((Invoke-Check $shapes[$name]) -eq 1) "$name - -Check exits 1 on a dirty body"
}

# The mid-body case must keep what came after the trailer, which is the whole reason the
# pattern is not anchored to the end of the document.
$out = Invoke-Strip $shapes['stranded mid-body']
Assert ($out -match 'Closing paragraph that must survive') 'text after a stranded trailer is kept'

# Negative 1: prose mentioning the tool is documentation, not attribution. This is harness
# PR #7's body, which a naive line-delete would have destroyed.
$prose = @"
This adds the commit-msg hook.

End-to-end: the commit on this branch was itself written with a ``Co-Authored-By: Claude Opus 5`` trailer, and the hook stripped it before the commit was created.

Generated output is unaffected.
"@
$out = Invoke-Strip $prose
Assert ($out -match 'the hook stripped it')      'inline prose about the trailer is preserved'
Assert ($out -match 'Generated output is unaffected') 'a line starting with "Generated" that is not the trailer survives'
Assert ((Invoke-Check $prose) -eq 0)             '-Check exits 0 on prose that merely mentions it'

# Negative 2: a clean body is returned unchanged apart from tail normalisation.
$clean = "A normal PR body.`n`nWith two paragraphs.`n"
$out = Invoke-Strip $clean
Assert ($out.TrimEnd() -eq $clean.TrimEnd()) 'a clean body is not altered'
Assert ((Invoke-Check $clean) -eq 0)         '-Check exits 0 on a clean body'

# The skill has to actually name the tool, or the mechanism is back to being prose.
$skill = Get-Content -LiteralPath (Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) '..\skills\pr\SKILL.md') -Raw -ErrorAction SilentlyContinue
Assert ($skill -and $skill -match 'strip-pr-attribution\.ps1') '/pr SKILL.md names the stripper'

Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ''
if ($script:Failures -gt 0) {
    Write-Host ("strip-pr-attribution.tests: {0} assertion(s) failed out of {1}" -f $script:Failures, $script:Ran) -ForegroundColor Red
    exit 1
}
Write-Host ("strip-pr-attribution.tests: {0} assertions passed" -f $script:Ran) -ForegroundColor Green
exit 0
