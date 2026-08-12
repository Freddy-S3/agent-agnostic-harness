<#
.SYNOPSIS
    Installs this provider-neutral agent harness into a specific agent host.

.DESCRIPTION
    The repository is the single source of truth. This script projects it into the
    layout a given host expects: the root instruction file is renamed, agent files
    get the host's suffix, and MCP config is emitted in the host's shape.

    Files that already exist and differ are backed up as <name>.bak-<timestamp>
    unless -Force is given.

    One step reaches outside the host's harness directories: global core.hooksPath
    is pointed at git-hooks/ so the commit-msg hook can enforce the "no agent
    co-author" rule. Suppress it with -SkipGitHooks. An existing core.hooksPath set
    by something else is reported, never overwritten.

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

.PARAMETER Link
    Junction skills/ and memories/ into the destination instead of copying, so the
    installed harness stays a live view of this repository.

.PARAMETER SkipGitHooks
    Do not touch global core.hooksPath. The commit-msg hook will not be active.

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

    [switch]$Link,

    [switch]$SkipGitHooks
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
        True when the path is a junction or symlink. Says nothing about where it
        points - use Test-JunctionPointsTo when that is the question being asked.
    #>
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $item = Get-Item -LiteralPath $Path -Force
    return ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
}

function Get-JunctionTarget {
    <# The path a junction resolves to, or $null if it is not a link. #>
    param([string]$Path)

    if (-not (Test-IsJunction $Path)) { return $null }
    $target = (Get-Item -LiteralPath $Path -Force).Target
    # .Target is a string collection on some PowerShell versions and a bare
    # string on others; normalise before comparing or the compare silently fails.
    if ($target -is [array]) { $target = $target[0] }
    if ([string]::IsNullOrWhiteSpace($target)) { return $null }
    return $target.TrimEnd('\')
}

function Test-JunctionPointsTo {
    <#
        True only when $Path is a link AND it resolves to $Target.

        The distinction matters and has bitten once already. This function used to
        be Test-IsJunction, whose docstring claimed it meant "already linked back to
        this repository" while the code only ever asked "is this a link at all". When
        the harness repository was renamed on disk, the installer re-ran, found the
        old junctions still present but dangling, printed "already linked", and
        skipped them - leaving every skill and memory unreachable while reporting a
        clean install. An idempotency check has to compare the target state, not the
        shape; "already linked" is exactly the kind of claim that needs the stronger
        test behind it.
    #>
    param([string]$Path, [string]$Target)

    $actual = Get-JunctionTarget $Path
    if ($null -eq $actual) { return $false }
    return $actual -ieq $Target.TrimEnd('\')
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

    if (Test-JunctionPointsTo $dst $src) {
        Write-Host "  ($DestName is linked to this repo - already live, skipped)"
        return
    }

    if (Test-IsJunction $dst) {
        # Same failure as the link step, reached when -Link was not passed: skipping
        # here on the strength of "it is a link" would leave a dangling junction in
        # place and copy nothing into it, so the install reports success and the
        # destination stays empty. Say so instead of skipping quietly.
        $stale = Get-JunctionTarget $dst
        Write-Host "  WARNING: $DestName is a link to $stale, not to this repo." -ForegroundColor Yellow
        Write-Host "           Nothing was copied. Re-run with -Link to repoint it." -ForegroundColor Yellow
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

        if (Test-JunctionPointsTo $dst $src) {
            Write-Host "  ($name already linked to this repo)"
            continue
        }

        if (Test-IsJunction $dst) {
            # A link to somewhere else, or a dangling one left behind by a rename.
            # A junction holds no data, so it is removed without a backup - and with
            # Directory.Delete($path, $false) rather than Remove-Item -Recurse, which
            # on PowerShell 5.1 can follow the reparse point and delete the target's
            # contents. That target is the repository itself.
            $stale = Get-JunctionTarget $dst
            Write-Action 'relink ' "$name was -> $stale"
            if (-not $DryRun) { [System.IO.Directory]::Delete($dst, $false) }
        }
        elseif ((Test-Path -LiteralPath $dst) -and -not $DryRun) {
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

# --- 3b. git hooks ---------------------------------------------------------

# AGENTS.md forbids adding an agent as a commit co-author. Prose alone did not
# stop it, so the installer points git at git-hooks/, where commit-msg strips
# the trailer. This is the one step that writes outside $DestRoot: core.hooksPath
# is global git config. Use -SkipGitHooks to leave git config alone.
if (-not $SkipGitHooks) {
    Write-Host "git hooks" -ForegroundColor Green

    $gitHookDir = Join-Path $SourceRoot 'git-hooks'
    if (-not (Test-Path -LiteralPath $gitHookDir)) {
        Write-Host "  (no git-hooks/ in source - skipped)"
    }
    else {
        $desired = $gitHookDir.Replace('\', '/')

        # `git config --get` exits 1 when the key is unset; that is not an error here.
        $current = & git config --global --get core.hooksPath 2>$null
        if ($LASTEXITCODE -ne 0) { $current = $null }
        if ($current) { $current = $current.Trim() }

        if ($current -eq $desired) {
            Write-Host "  (core.hooksPath already points here)"
            $script:Skipped++
        }
        elseif ($current) {
            # Someone else owns this setting. Overwriting it would silently disable
            # their hooks, which is exactly the class of bug this section exists to
            # prevent, so report and let the user decide.
            Write-Host "  core.hooksPath is already set to:" -ForegroundColor Yellow
            Write-Host "    $current" -ForegroundColor Yellow
            Write-Host "  Leaving it alone. To use the harness hooks instead, run:" -ForegroundColor Yellow
            Write-Host "    git config --global core.hooksPath '$desired'" -ForegroundColor Yellow
            $script:Skipped++
        }
        else {
            Write-Action 'config ' "core.hooksPath -> $desired"
            if (-not $DryRun) {
                & git config --global core.hooksPath $desired
            }
        }

        # A hook needs the executable bit on POSIX. Git for Windows does not, but the
        # repository is shared, so keep the index mode correct from whichever machine
        # installs. Harmless when already set.
        if (-not $DryRun) {
            Push-Location $SourceRoot
            try {
                & git update-index --chmod=+x git-hooks/commit-msg 2>$null | Out-Null
            }
            catch { }
            finally { Pop-Location }
        }

        Write-Host "  note: core.hooksPath is global and replaces per-repo .git/hooks." -ForegroundColor Yellow
        Write-Host "        A repo that needs its own hooks must set a local core.hooksPath." -ForegroundColor Yellow
    }
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
