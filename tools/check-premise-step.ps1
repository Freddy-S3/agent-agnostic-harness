<#
.SYNOPSIS
  Verify that premise interrogation is still a reachable, required step.

.DESCRIPTION
  This rule is prose, and prose rots silently. Three things have to hold for it to work at
  all, and each can be broken by an edit that looks unrelated:

    1. The rule file exists and AGENTS.md triggers it. (check-rule-triggers.ps1 owns the
       general case; this checks the specific row, because a row can be deleted without
       leaving a dangling reference behind.)
    2. /ship asks for the premise at Gate 1 and /freddy interrogates it before owner
       selection. A rule nothing invokes is a rule nobody runs.
    3. The grill skills are model-invocable. The rule routes to /grilling for premises too
       large to check cheaply, and that routing only works while none of the three skills
       carries disable-model-invocation. Adding that key would break the route with no
       error anywhere - which is exactly the failure this whole gap was reported as, and
       the reason it is worth a check rather than a sentence.

  Silent on success, verbose on failure.

.EXAMPLE
  powershell -NoProfile -File tools\check-premise-step.ps1
#>
[CmdletBinding()]
param([string] $RepoRoot)

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }

$failures = New-Object System.Collections.Generic.List[string]

function Get-Text($rel) {
    $p = Join-Path $RepoRoot $rel
    if (-not (Test-Path -LiteralPath $p)) { return $null }
    return (Get-Content -LiteralPath $p -Raw -Encoding UTF8)
}

# 1. The rule exists and is triggered.
$rulePath = 'instructions/rules/premise-interrogation.md'
$rule = Get-Text $rulePath
if (-not $rule) {
    $failures.Add("missing: $rulePath - the premise-interrogation rule is gone")
} else {
    foreach ($marker in 'What must be true', 'cheapest check', 'could be dropped') {
        if ($rule -notmatch [regex]::Escape($marker)) {
            $failures.Add("rule no longer asks '$marker' - the four questions are the rule")
        }
    }
}

$core = Get-Text 'instructions/AGENTS.md'
if (-not $core) {
    $failures.Add('missing: instructions/AGENTS.md')
} elseif ($core -notmatch 'premise-interrogation\.md') {
    $failures.Add('instructions/AGENTS.md no longer triggers premise-interrogation.md, so no session will read it')
}

# 2. The step is required by the two things that start substantial work.
$ship = Get-Text 'skills/ship/SKILL.md'
if (-not $ship) {
    $failures.Add('missing: skills/ship/SKILL.md')
} else {
    if ($ship -notmatch 'premise-interrogation\.md') {
        $failures.Add('/ship no longer cites premise-interrogation.md before Phase 1-2 planning')
    }
    if ($ship -notmatch '(?m)^Premise:') {
        $failures.Add('/ship Gate 1 output no longer carries a Premise line, so Faruk approves without seeing what the work stands on')
    }
}

$freddy = Get-Text 'skills/freddy/SKILL.md'
if (-not $freddy) {
    $failures.Add('missing: skills/freddy/SKILL.md')
} elseif ($freddy -notmatch 'premise-interrogation\.md') {
    $failures.Add('/freddy delivery overlay no longer interrogates the premise before owner selection')
}

# 3. The escalation route is reachable. This is the check that would have caught the
#    reported blocker, had it been real.
foreach ($skill in 'grilling', 'grill-me', 'grill-with-docs') {
    $rel  = "skills/$skill/SKILL.md"
    $text = Get-Text $rel
    if (-not $text) {
        $failures.Add("missing: $rel - the premise rule routes to /$skill and cannot")
        continue
    }
    if ($text -match '(?im)^\s*disable-model-invocation:\s*true\s*$') {
        $failures.Add("$rel sets disable-model-invocation: true - a router can no longer reach /$skill, so premise escalation silently stops working and only a typed slash command finds it")
    }
}

if ($failures.Count -gt 0) {
    Write-Host 'premise interrogation' -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  $f" -ForegroundColor Red }
    exit 1
}

Write-Host 'premise interrogation' -ForegroundColor Green
Write-Host '  rule triggered, required by /ship and /freddy, and all three grill skills are model-invocable'
exit 0
