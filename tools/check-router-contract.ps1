param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

$contractPath = Join-Path $Root 'skills\faruk\ROUTER-CONTRACT.md'
$routerPaths = @{
    faruk  = Join-Path $Root 'skills\faruk\SKILL.md'
    freddy = Join-Path $Root 'skills\freddy\SKILL.md'
    sleep  = Join-Path $Root 'skills\sleep\SKILL.md'
}

if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
    throw "Shared router contract is missing: $contractPath"
}

$contract = Get-Content -Raw -LiteralPath $contractPath
foreach ($router in $routerPaths.Keys) {
    if (-not (Test-Path -LiteralPath $routerPaths[$router] -PathType Leaf)) {
        throw "Router skill is missing: $($routerPaths[$router])"
    }

    $skill = Get-Content -Raw -LiteralPath $routerPaths[$router]
    if ($skill -notmatch '(?m)^name:\s*' + [regex]::Escape($router) + '\s*$') {
        throw "/$router has no matching skill name in frontmatter."
    }

    if ($skill -match '(?m)^disable-model-invocation:\s*true\s*$') {
        throw "/$router disables model invocation."
    }
}

if ($contract -notmatch [regex]::Escape('/faruk') -or
    $contract -notmatch [regex]::Escape('/freddy') -or
    $contract -notmatch [regex]::Escape('/sleep')) {
    throw 'The shared router contract must name /faruk, /freddy, and /sleep.'
}

$expectedReferences = @{
    faruk  = 'ROUTER-CONTRACT.md'
    freddy = '../faruk/ROUTER-CONTRACT.md'
    sleep  = '../faruk/ROUTER-CONTRACT.md'
}

foreach ($router in $expectedReferences.Keys) {
    $skill = Get-Content -Raw -LiteralPath $routerPaths[$router]
    if ($skill -notmatch [regex]::Escape($expectedReferences[$router])) {
        throw "/$router does not point to the shared router contract."
    }
}

Write-Output 'Router contract check passed: /faruk, /freddy, and /sleep share the canonical contract.'
