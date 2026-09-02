$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$fixtures = @(
    @{ Name = 'successful.md'; Status = 'complete'; Route = 'report'; Marker = '### Observed facts' },
    @{ Name = 'inconclusive.md'; Status = 'inconclusive'; Route = 'report'; Marker = '### Unresolved questions' },
    @{ Name = 'hypothesis.md'; Status = 'partial'; Route = 'report'; Marker = '### Hypotheses' },
    @{ Name = 'companion-wiki.md'; Status = 'complete'; Route = 'report-and-wiki-draft'; Marker = '### Inferences' }
)

$required = @(
    '^# Investigation report:',
    '^Status: ',
    '^Question: ',
    '^Scope: ',
    '^Methods: ',
    '^Output route: ',
    '^Wiki destination: ',
    '^## Findings$',
    '^### Observed facts$',
    '^### Inferences$',
    '^### Hypotheses$',
    '^### Unresolved questions$',
    '^## Evidence$',
    '^## Uncertainty$',
    '^## Recommended next steps$',
    '^## Recovery and follow-up$'
)

$skillPath = Join-Path $root 'skills\investigation\SKILL.md'
if (-not (Test-Path -LiteralPath $skillPath)) {
    throw "Missing investigation skill: $skillPath"
}

$skill = Get-Content -Raw -LiteralPath $skillPath
if ($skill -notmatch '(?m)^name:\s+investigation\s*$') {
    throw 'Investigation skill has no matching name in frontmatter'
}
if ($skill -notmatch '(?m)^description:\s+".+"\s*$') {
    throw 'Investigation skill has no quoted description in frontmatter'
}
if ($skill -match '(?m)^disable-model-invocation:\s*true\s*$') {
    throw 'Investigation skill must remain model-invocable'
}

foreach ($fixture in $fixtures) {
    $path = Join-Path $root "skills\investigation\fixtures\$($fixture.Name)"
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing investigation fixture: $path"
    }

    $text = Get-Content -Raw -LiteralPath $path
    foreach ($pattern in $required) {
        if ($text -notmatch "(?m)$pattern") {
            throw "$($fixture.Name) is missing required report section: $pattern"
        }
    }
    if ($text -notmatch "(?m)^Status:\s+$([regex]::Escape($fixture.Status))$") {
        throw "$($fixture.Name) has the wrong status"
    }
    if ($text -notmatch "(?m)^Output route:\s+$([regex]::Escape($fixture.Route))$") {
        throw "$($fixture.Name) has the wrong output route"
    }
    if ($text -notmatch '(?m)Evidence:\s+\[E\d+\]') {
        throw "$($fixture.Name) has no finding-to-evidence reference"
    }
    if ($text -notmatch "(?m)^$([regex]::Escape($fixture.Marker))$") {
        throw "$($fixture.Name) is missing its classification marker: $($fixture.Marker)"
    }
    if ($fixture.Route -eq 'report-and-wiki-draft') {
        if ($text -notmatch '(?m)^Wiki destination:\s+.+$') {
            throw "$($fixture.Name) has no exact wiki destination"
        }
        if ($text -notmatch '(?m)^Publication:\s+pending operator approval$') {
            throw "$($fixture.Name) does not keep publication approval-gated"
        }
    } elseif ($text -notmatch '(?m)^Wiki destination:\s+none selected$') {
        throw "$($fixture.Name) should remain report-only without a selected wiki destination"
    }
}
