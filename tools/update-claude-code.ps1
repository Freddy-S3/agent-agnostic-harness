# Upgrades the winget-managed Claude Code CLI.
# winget-installed builds keep Claude Code's own auto-updater disabled, so the
# package manager is the only thing that moves the version. Run at logon, before
# a session or VS Code holds claude.exe open.
[CmdletBinding()]
param(
    [string]$LogPath = "$env:LOCALAPPDATA\claude-code-update.log"
)

$ErrorActionPreference = 'Continue'
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

# winget replaces claude.exe in place, and Windows refuses the delete while any
# session holds it open (0x8a150003, "Access is denied"). Defer rather than fail:
# the logon trigger will catch it before anything is running.
$busy = Get-Process -Name claude -ErrorAction SilentlyContinue
if ($busy) {
    "[$stamp] deferred - claude.exe in use by PID(s) $($busy.Id -join ', ')" |
        Add-Content -Path $LogPath -Encoding utf8
    return
}

$output = winget upgrade --id Anthropic.ClaudeCode --silent `
    --accept-source-agreements --accept-package-agreements --disable-interactivity 2>&1
$code = $LASTEXITCODE

# 0x8A15002B: no applicable upgrade found. Not a failure.
$status = if ($code -eq 0) { 'upgraded' }
          elseif ($code -eq -1978335189) { 'already current' }
          else { "failed (exit $code)" }

"[$stamp] $status" | Add-Content -Path $LogPath -Encoding utf8
$output | Out-String | Add-Content -Path $LogPath -Encoding utf8

# Keep the log from growing without bound.
$lines = Get-Content -Path $LogPath -ErrorAction SilentlyContinue
if ($lines.Count -gt 500) { $lines[-500..-1] | Set-Content -Path $LogPath -Encoding utf8 }
