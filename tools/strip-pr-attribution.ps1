<#
.SYNOPSIS
  Strip agent-attribution trailers from a pull request title or body. Every `gh pr
  create` and `gh pr edit` body must pass through this first.

.DESCRIPTION
  AGENTS.md forbids attributing work to an agent. For commit messages that rule has a
  mechanism - `git-hooks/commit-msg` strips the trailer and says what it removed - and it
  has held. For pull requests it was prose only: `skills/pr/SKILL.md` said "Never append a
  Generated with Claude Code footer", and 33 PR bodies across three repositories carried
  exactly that footer anyway.

  That is the harness's own standing rule playing out: a convention living only in prose
  is one the tooling will quietly violate. The rule did not fail where it was enforced. It
  failed where it was merely implied.

  So this is the enforcement point. It is deliberately a filter rather than a checker: a
  checker that says "your body is wrong" still needs someone to act on it, whereas a
  filter that every body passes through cannot be forgotten halfway.

  What counts as a trailer:
    - "Generated with [Claude Code](https://claude.com/claude-code)", with or without the
      robot emoji, with or without a horizontal rule above it.
    - A bare "Co-Authored-By: Claude ..." line, which is the commit-side trailer leaking
      into a PR body.
    - Either of those anywhere in the body, not only at the end, because an edited body
      can leave one stranded mid-document.

  What is deliberately NOT stripped: prose that happens to mention Claude Code. A sentence
  explaining that the commit-msg hook removes a `Co-Authored-By: Claude` trailer is
  documentation, not attribution, and harness PR #7 contains exactly that. Only a line
  whose whole content is the trailer is removed.

.PARAMETER Path
  File holding the body. Rewritten in place unless -Stdout is given.

.PARAMETER Text
  Body as a string instead of a file. Implies -Stdout.

.PARAMETER Stdout
  Write the cleaned text to stdout instead of rewriting the file.

.PARAMETER Check
  Do not modify anything; exit 1 if a trailer is present. For CI.

.EXAMPLE
  .\strip-pr-attribution.ps1 -Path body.md
  gh pr create --body-file body.md

.EXAMPLE
  .\strip-pr-attribution.ps1 -Text $body -Stdout
#>
[CmdletBinding()]
param(
    [string] $Path,
    [string] $Text,
    [switch] $Stdout,
    [switch] $Check
)

$ErrorActionPreference = 'Stop'

# One pattern, built once, so the filter and the -Check gate can never disagree about what
# a trailer is.
#
# (?m) anchors each alternative to a whole line: that is what keeps an inline mention in a
# sentence from being treated as attribution.
$script:TrailerPattern =
    '(?m)^[ \t]*(?:(?:---|\*\*\*|___)[ \t]*\r?\n[ \t]*)?' +
    '[\p{Cs}\p{So}️‍]*[ \t]*' +
    '(?:Generated with[ \t]*(?:\[Claude Code\]\([^)]*\)|Claude Code)' +
    '|Co-Authored-By:[ \t]*Claude\b[^\r\n]*)' +
    '[ \t]*\r?$'

function Remove-Attribution([string] $body) {
    if ($null -eq $body) { return '' }
    $cleaned = [regex]::Replace($body, $script:TrailerPattern, '')
    # Collapse the blank-line crater the removal leaves behind, then normalise the tail so
    # a stripped body does not differ from a hand-written one by trailing whitespace.
    $cleaned = [regex]::Replace($cleaned, '(\r?\n){3,}', "`n`n")
    return $cleaned.TrimEnd() + "`n"
}

function Test-Attribution([string] $body) {
    if ($null -eq $body) { return $false }
    return [regex]::IsMatch($body, $script:TrailerPattern)
}

if ($Text) {
    $body = $Text
} elseif ($Path) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "body file not found: $Path" }
    $body = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
} else {
    $body = [Console]::In.ReadToEnd()
    $Stdout = $true
}

if ($Check) {
    if (Test-Attribution $body) {
        Write-Host 'pr attribution: FOUND an agent-attribution trailer' -ForegroundColor Red
        foreach ($m in [regex]::Matches($body, $script:TrailerPattern)) {
            Write-Host ("  " + $m.Value.Trim()) -ForegroundColor Red
        }
        Write-Host '  AGENTS.md: never attribute a commit OR a pull request to an agent.'
        Write-Host '  Pipe the body through tools/strip-pr-attribution.ps1 before gh pr create/edit.'
        exit 1
    }
    Write-Host 'pr attribution: none' -ForegroundColor Green
    exit 0
}

$clean = Remove-Attribution $body
$removed = Test-Attribution $body

if ($Stdout -or $Text) {
    [Console]::Out.Write($clean)
} else {
    [System.IO.File]::WriteAllText($Path, $clean)
    if ($removed) {
        Write-Host "pr attribution: stripped a trailer from $Path" -ForegroundColor Yellow
    }
}
exit 0
