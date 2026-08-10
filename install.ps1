<#
.SYNOPSIS
    Installs this provider-neutral agent harness into a specific agent host.

.DESCRIPTION
    The repository is the single source of truth. This script projects it into the
    layout a given host expects: the root instruction file is renamed, agent files
    get the host's suffix, and MCP config is emitted in the host's shape.

    Nothing outside the host's harness directories is modified. Files that already
    exist and differ are backed up as <name>.bak-<timestamp> unless -Force is given.

.PARAMETER Target
    Which host to install for: copilot, claude, or codex.

.PARAMETER DestRoot
    Override the destination root. Defaults to the host's conventional directory
    under $env:USERPROFILE (.copilot / .claude / .codex).

.PARAMETER IncludeMemories
    Copy memories/ into the destination. On by default; use -IncludeMemories:$false
    to skip when the host has its own durable memory store.

.PARAMETER Mcp
    Also emit the MCP server configuration for the target host.

.PARAMETER DryRun
    Report every action without writing anything.

.PARAMETER Force
    Overwrite differing files without creating a backup.

.EXAMPLE
    .\install.ps1 -Target copilot

.EXAMPLE
    .\install.ps1 -Target claude -Mcp -DryRun
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('copilot', 'claude', 'codex')]
    [string]$Target,

    [string]$DestRoot,

    [bool]$IncludeMemories = $true,

    [switch]$Mcp,

    [switch]$DryRun,

    [switch]$Force,

    [switch]$Link
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$SourceRoot = $PSScriptRoot
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$script:Actions = 0
$script:Skipped = 0

# --- host layout -----------------------------------------------------------

# InstructionName: what the always-loaded root instruction file must be called.
# AgentSuffix:     the extension the host recognises for agent definitions.
# ScopedInstructions: whether the host understands applyTo-scoped *.instructions.md.
switch ($Target) {
    'copilot' {
        $DefaultRoot = Join-Path $env:USERPROFILE '.copilot'
        $InstructionName = 'copilot-instructions.md'
        $InstructionSubdir = 'instructions'
        $AgentSuffix = '.agent.md'
        $ScopedInstructions = $true
        $McpFileName = 'mcp-config.json'
        $McpFormat = 'json'
    }
    'claude' {
        $DefaultRoot = Join-Path $env:USERPROFILE '.claude'
        $InstructionName = 'CLAUDE.md'
        $InstructionSubdir = ''          # CLAUDE.md sits at the root
        $AgentSuffix = '.md'
        $ScopedInstructions = $false
        $McpFileName = 'mcp-servers.generated.json'
        $McpFormat = 'json'
    }
    'codex' {
        $DefaultRoot = Join-Path $env:USERPROFILE '.codex'
        $InstructionName = 'AGENTS.md'
        $InstructionSubdir = ''
        $AgentSuffix = '.md'
        $ScopedInstructions = $false
        $McpFileName = 'mcp-servers.generated.toml'
        $McpFormat = 'toml'
    }
}

if ([string]::IsNullOrWhiteSpace($DestRoot)) { $DestRoot = $DefaultRoot }

# --- helpers ---------------------------------------------------------------

function Write-Action {
    param([string]$Verb, [string]$Detail)
    if ($DryRun) { Write-Host "  [dry-run] $Verb $Detail" }
    else { Write-Host "  $Verb $Detail" }
    $script:Actions++
}

function New-Dir {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) { return }
    if (-not $DryRun) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}

function Get-FileHashSafe {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Copy-Tracked {
    <#
        Copies one file, skipping identical content and backing up differing
        content so a hand-edited host file is never silently destroyed.
    #>
    param([string]$From, [string]$To)

    $fromHash = Get-FileHashSafe $From
    $toHash = Get-FileHashSafe $To

    if ($null -ne $toHash -and $fromHash -eq $toHash) {
        $script:Skipped++
        return
    }

    if ($null -ne $toHash -and -not $Force) {
        $backup = "$To.bak-$Stamp"
        Write-Action 'backup ' (Split-Path -Leaf $backup)
        if (-not $DryRun) { Copy-Item -LiteralPath $To -Destination $backup -Force }
    }

    New-Dir (Split-Path -Parent $To)
    Write-Action 'write  ' $To.Substring($DestRoot.Length).TrimStart('\')
    if (-not $DryRun) { Copy-Item -LiteralPath $From -Destination $To -Force }
}

function Write-ImportStub {
    <#
        Claude Code resolves @-imports when it reads the file, so its root instruction
        file must be a stub that points at the harness, never a copy of it. A copy looks
        identical on install day and then drifts silently forever, which is exactly what
        the stub exists to prevent. An existing file that already carries the import line
        is left alone, whatever else the user wrote around it.
    #>
    param([string]$From, [string]$To)

    $importPath = $From
    if ($importPath.StartsWith($env:USERPROFILE, [StringComparison]::OrdinalIgnoreCase)) {
        $importPath = '~' + $importPath.Substring($env:USERPROFILE.Length)
    }
    $importPath = $importPath.Replace('\', '/')
    $importLine = "@$importPath"

    if (Test-Path -LiteralPath $To) {
        $existing = Get-Content -LiteralPath $To -Raw
        if ($existing -and $existing.Contains($importLine) -and -not $Force) {
            # Already a live import; leave whatever wording the user put around it.
            $script:Skipped++
            return
        }
        if (-not $Force) {
            $backup = "$To.bak-$Stamp"
            Write-Action 'backup ' (Split-Path -Leaf $backup)
            if (-not $DryRun) { Copy-Item -LiteralPath $To -Destination $backup -Force }
        }
    }

    $stub = @"
# Agent Instructions (stub)

The real instructions live in the harness repository and are imported below.
Edit ``$importPath``; never edit this stub.

$importLine

## Import check

If you are reading this file and the ``Operating Modes`` section is not in your context,
the import above did not resolve. Say so in the first reply of the session, then re-run
the installer to rewrite this stub:

    .\install.ps1 -Target claude

Do not replace this stub with a copy of AGENTS.md. A copy stops tracking the harness.
"@

    New-Dir (Split-Path -Parent $To)
    Write-Action 'stub   ' $To.Substring($DestRoot.Length).TrimStart('\')
    if (-not $DryRun) { Set-Content -LiteralPath $To -Value $stub -Encoding UTF8 }
}

function Test-IsJunction {
    <#
        True when the path is a junction or symlink, meaning the destination is
        already linked back to this repository and must not be copied over.
    #>
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $item = Get-Item -LiteralPath $Path -Force
    return ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
}

function Copy-Tree {
    <# Mirrors a source subdirectory into the destination, file by file. #>
    param([string]$Name, [string]$DestName)

    $src = Join-Path $SourceRoot $Name
    if (-not (Test-Path -LiteralPath $src)) {
        Write-Host "  (no $Name/ in source - skipped)"
        return
    }
    if ([string]::IsNullOrWhiteSpace($DestName)) { $DestName = $Name }
    $dst = Join-Path $DestRoot $DestName

    if (Test-IsJunction $dst) {
        Write-Host "  ($DestName is linked to the repo - already live, skipped)"
        return
    }

    $files = Get-ChildItem -LiteralPath $src -Recurse -File
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($src.Length).TrimStart('\')
        Copy-Tracked $f.FullName (Join-Path $dst $rel)
    }
}

# --- preflight -------------------------------------------------------------

Write-Host ""
Write-Host "Harness install" -ForegroundColor Cyan
Write-Host "  source: $SourceRoot"
Write-Host "  target: $Target"
Write-Host "  dest:   $DestRoot"
if ($DryRun) { Write-Host "  mode:   DRY RUN (nothing will be written)" -ForegroundColor Yellow }
Write-Host ""

$rootInstruction = Join-Path $SourceRoot 'instructions\AGENTS.md'
if (-not (Test-Path -LiteralPath $rootInstruction)) {
    throw "Missing required source file: instructions\AGENTS.md"
}

New-Dir $DestRoot

# --- 1. root instruction file ---------------------------------------------

Write-Host "instructions" -ForegroundColor Green
if ([string]::IsNullOrWhiteSpace($InstructionSubdir)) {
    $instructionDest = Join-Path $DestRoot $InstructionName
}
else {
    $instructionDest = Join-Path (Join-Path $DestRoot $InstructionSubdir) $InstructionName
}
# Claude reads @-imports live, so it gets a stub. Other hosts get the real copy.
if ($Target -eq 'claude') {
    Write-ImportStub $rootInstruction $instructionDest
}
else {
    Copy-Tracked $rootInstruction $instructionDest
}

# Scoped *.instructions.md files rely on Copilot's applyTo frontmatter. Other
# hosts have no equivalent, so they are installed as reference material and the
# user is told they will not auto-apply.
$scoped = @(Get-ChildItem -LiteralPath (Join-Path $SourceRoot 'instructions') -Filter '*.instructions.md' -File -ErrorAction SilentlyContinue)
if ($scoped.Count -gt 0) {
    foreach ($s in $scoped) {
        Copy-Tracked $s.FullName (Join-Path (Join-Path $DestRoot 'instructions') $s.Name)
    }
    if (-not $ScopedInstructions) {
        Write-Host "  note: $($scoped.Count) scoped *.instructions.md copied as reference;" -ForegroundColor Yellow
        Write-Host "        $Target has no applyTo equivalent, so they will not auto-apply." -ForegroundColor Yellow
    }
}

# --- 2. agents -------------------------------------------------------------

Write-Host "agents" -ForegroundColor Green
$agentSrc = Join-Path $SourceRoot 'agents'
$agentFiles = @()
if (Test-Path -LiteralPath $agentSrc) {
    # README.md documents the format; it is not an agent definition.
    $agentFiles = @(Get-ChildItem -LiteralPath $agentSrc -Filter '*.md' -File |
        Where-Object { $_.Name -ne 'README.md' })
}
if ($agentFiles.Count -eq 0) {
    Write-Host "  (none defined)"
}
else {
    foreach ($a in $agentFiles) {
        $base = [System.IO.Path]::GetFileNameWithoutExtension($a.Name)
        Copy-Tracked $a.FullName (Join-Path (Join-Path $DestRoot 'agents') "$base$AgentSuffix")
    }
}

# --- 3. skills + hooks + memories -----------------------------------------

if ($Link) {
    # Junctions make the destination a live view of this repository, so editing
    # either path changes both and no reinstall is needed. Junctions are used
    # rather than symlinks because they need no administrator rights.
    Write-Host "linking skills + memories" -ForegroundColor Green

    $linkNames = @('skills')
    if ($IncludeMemories) { $linkNames += 'memories' }

    foreach ($name in $linkNames) {
        $src = Join-Path $SourceRoot $name
        $dst = Join-Path $DestRoot $name
        if (-not (Test-Path -LiteralPath $src)) { continue }

        if (Test-IsJunction $dst) {
            Write-Host "  ($name already linked)"
            continue
        }

        if ((Test-Path -LiteralPath $dst) -and -not $DryRun) {
            $backup = "$dst.bak-$Stamp"
            Write-Action 'backup ' (Split-Path -Leaf $backup)
            Copy-Item -LiteralPath $dst -Destination $backup -Recurse -Force
            Remove-Item -LiteralPath $dst -Recurse -Force
        }

        Write-Action 'link   ' "$name -> $src"
        if (-not $DryRun) {
            New-Item -ItemType Junction -Path $dst -Target $src | Out-Null
        }
    }

    if ($Target -eq 'claude') {
        Write-Host "  note: a single file cannot be linked reliably on Windows." -ForegroundColor Yellow
        Write-Host "        CLAUDE.md was written as an @-import stub, not a copy." -ForegroundColor Yellow
        Write-Host "        Claude Code resolves the import at read time, so it stays live." -ForegroundColor Yellow
    }

    Write-Host ""
}

Write-Host "skills" -ForegroundColor Green
Copy-Tree 'skills' 'skills'

Write-Host "hooks" -ForegroundColor Green
Copy-Tree 'hooks' 'hooks'
if ($Target -eq 'claude') {
    Write-Host "  note: Claude Code does not auto-run files in hooks/." -ForegroundColor Yellow
    Write-Host "        Register them under the 'hooks' key in ~\.claude\settings.json." -ForegroundColor Yellow
}

if ($IncludeMemories) {
    Write-Host "memories" -ForegroundColor Green
    Copy-Tree 'memories' 'memories'
}

# --- 4. MCP configuration -------------------------------------------------

if ($Mcp) {
    Write-Host "mcp" -ForegroundColor Green
    $template = Join-Path $SourceRoot 'config\mcp-config.template.json'
    if (-not (Test-Path -LiteralPath $template)) {
        Write-Host "  (no template found - skipped)" -ForegroundColor Yellow
    }
    else {
        $mcpDest = Join-Path $DestRoot $McpFileName

        if ($McpFormat -eq 'json') {
            Copy-Tracked $template $mcpDest
        }
        else {
            # Codex reads TOML. Translate the mcpServers map into [mcp_servers.<name>]
            # tables rather than shipping a second hand-maintained source file.
            $json = Get-Content -LiteralPath $template -Raw | ConvertFrom-Json
            $lines = New-Object System.Collections.Generic.List[string]
            $lines.Add("# Generated from config/mcp-config.template.json by install.ps1.")
            $lines.Add("# Merge these tables into ~\.codex\config.toml.")
            $lines.Add("#")
            $lines.Add("# CAUTION: Codex does not expand `${env:NAME} placeholders in config.toml.")
            $lines.Add("# Replace each one with a literal value, or drop the key and export it in the")
            $lines.Add("# environment before launching Codex so the server inherits it.")
            $lines.Add("")
            foreach ($prop in $json.mcpServers.PSObject.Properties) {
                $name = $prop.Name
                $srv = $prop.Value
                $lines.Add("[mcp_servers.$name]")
                $lines.Add("command = `"$($srv.command)`"")
                $argList = @()
                foreach ($a in $srv.args) { $argList += "`"$a`"" }
                $lines.Add("args = [$($argList -join ', ')]")
                if ($srv.PSObject.Properties.Name -contains 'env') {
                    $lines.Add("")
                    $lines.Add("[mcp_servers.$name.env]")
                    foreach ($e in $srv.env.PSObject.Properties) {
                        $lines.Add("$($e.Name) = `"$($e.Value)`"")
                    }
                }
                $lines.Add("")
            }
            Write-Action 'write  ' $McpFileName
            if (-not $DryRun) {
                Set-Content -LiteralPath $mcpDest -Value $lines -Encoding utf8
            }
        }

        Write-Host "  note: the template reads JIRA_URL, JIRA_PERSONAL_TOKEN, CONFLUENCE_URL," -ForegroundColor Yellow
        Write-Host "        CONFLUENCE_PERSONAL_TOKEN, and AGENT_CA_BUNDLE from the environment." -ForegroundColor Yellow
        if ($Target -eq 'claude') {
            Write-Host "  note: not merged into ~\.claude.json automatically - that file holds live" -ForegroundColor Yellow
            Write-Host "        session state. Register with: claude mcp add --scope user ..." -ForegroundColor Yellow
        }
    }
}

# --- summary ---------------------------------------------------------------

Write-Host ""
if ($DryRun) {
    Write-Host "Dry run complete: $($script:Actions) action(s) pending, $($script:Skipped) already current." -ForegroundColor Cyan
    Write-Host "Re-run without -DryRun to apply."
}
else {
    Write-Host "Installed: $($script:Actions) file action(s), $($script:Skipped) already current." -ForegroundColor Cyan
    Write-Host "Restart the $Target host so it rediscovers instructions and skills."
}
Write-Host ""
