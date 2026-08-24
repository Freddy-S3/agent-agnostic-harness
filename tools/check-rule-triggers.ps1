<#
.SYNOPSIS
    Verifies the progressive-disclosure split in instructions/ is intact.

.DESCRIPTION
    The core instructions/AGENTS.md is loaded into every session on every host. Conditional
    detail lives in instructions/rules/ and is loaded only when a trigger row in the core names
    it. Codex has no import directive, so a rule file with no trigger row is a file nobody ever
    opens, and a trigger row pointing at a missing file is an instruction nobody can follow.
    Neither failure is visible by reading either file on its own, which is why this runs.

    Checks:
      1. Every .md in instructions/rules/ (except README.md) has a trigger row in the core.
      2. Every rules/ path referenced by the core exists on disk.
      3. The core stays under -MaxCoreBytes, so the hot path does not silently regrow.

    Exit 0 when all checks pass, 1 otherwise.
#>
[CmdletBinding()]
param(
    [string] $RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [int]    $MaxCoreBytes = 26000
)

$ErrorActionPreference = 'Stop'

$core     = Join-Path $RepoRoot 'instructions\AGENTS.md'
$rulesDir = Join-Path $RepoRoot 'instructions\rules'

if (-not (Test-Path -LiteralPath $core))     { Write-Error "Missing core: $core"; exit 1 }
if (-not (Test-Path -LiteralPath $rulesDir)) { Write-Error "Missing rules dir: $rulesDir"; exit 1 }

$coreText = Get-Content -LiteralPath $core -Raw
$failures = New-Object System.Collections.Generic.List[string]

# 1. Every rule file is triggered from the core.
$ruleFiles = Get-ChildItem -LiteralPath $rulesDir -Filter *.md |
             Where-Object { $_.Name -ne 'README.md' }

foreach ($f in $ruleFiles) {
    if ($coreText -notmatch [regex]::Escape("rules/$($f.Name)")) {
        $failures.Add("untriggered: instructions/rules/$($f.Name) is never named by AGENTS.md, so nothing will ever open it")
    }
}

# 2. Every referenced rules/ path exists.
$referenced = [regex]::Matches($coreText, 'instructions/rules/([A-Za-z0-9._-]+\.md)') |
              ForEach-Object { $_.Groups[1].Value } |
              Sort-Object -Unique

foreach ($name in $referenced) {
    if (-not (Test-Path -LiteralPath (Join-Path $rulesDir $name))) {
        $failures.Add("dangling: AGENTS.md points at instructions/rules/$name, which does not exist")
    }
}

# 3. The hot path has not regrown.
$coreBytes = (Get-Item -LiteralPath $core).Length
if ($coreBytes -gt $MaxCoreBytes) {
    $failures.Add("oversize: AGENTS.md is $coreBytes bytes, over the $MaxCoreBytes ceiling - move conditional detail into instructions/rules/ rather than raising this")
}

Write-Host "rule triggers" -ForegroundColor Green
Write-Host ("  core: {0:N0} bytes (ceiling {1:N0})" -f $coreBytes, $MaxCoreBytes)
Write-Host ("  rule files: {0}; triggered references: {1}" -f $ruleFiles.Count, $referenced.Count)

if ($failures.Count -gt 0) {
    foreach ($msg in $failures) { Write-Host "  $msg" -ForegroundColor Red }
    exit 1
}

Write-Host "  all rule files triggered and all references resolve" -ForegroundColor Green
exit 0
