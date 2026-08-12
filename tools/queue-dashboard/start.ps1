# Starts the queue dashboard if it is not already up, then returns immediately.
# Idempotent by design: every Claude Code session runs this, and only the first one
# that finds the port free actually spawns a server.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/queue-dashboard/start.ps1

$ErrorActionPreference = 'Stop'
$port = if ($env:QUEUE_DASHBOARD_PORT) { [int]$env:QUEUE_DASHBOARD_PORT } else { 4317 }
$server = Join-Path $PSScriptRoot 'server.mjs'
$log = Join-Path $env:TEMP 'queue-dashboard.log'

# Cheapest check that actually catches the case: can something accept a connection?
# A process check would miss a wedged server and a port check would not.
# The running server holds the log open for its stdout redirect, so a note from the
# launcher can fail on a sharing violation. Never let that take down the launcher.
function Write-Note([string]$msg) {
  try { "$(Get-Date -Format s) $msg" | Add-Content $log -ErrorAction Stop }
  catch { }
}

function Test-Up([int]$p) {
  $client = New-Object System.Net.Sockets.TcpClient
  try { $client.Connect('127.0.0.1', $p); return $true }
  catch { return $false }
  finally { $client.Dispose() }
}

if (Test-Up $port) { exit 0 }

# Refuse to start a build with no auth in it. This is not hypothetical: a concurrent
# session checked out another branch in the shared clone and swapped server.mjs for a
# pre-auth version while a tailnet proxy was about to be pointed at the port. Run the
# dashboard from a pinned worktree, and fail closed if the file ever lacks the gate.
if (-not (Select-String -Path $server -Pattern 'timingSafeEqual' -Quiet)) {
  Write-Note "refusing to start: $server has no token gate"
  exit 0
}

$node = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $node) {
  # Say what is actually wrong rather than failing silently. A missing Node here has
  # been misdiagnosed before.
  Write-Note "node not found on PATH; dashboard not started"
  exit 0
}

# The child reads PORT, not QUEUE_DASHBOARD_PORT. Without this the launcher would probe
# one port and start the server on another - they only agreed by both defaulting to 4317.
$env:PORT = "$port"

# Binding the tailnet address is opt-in and marked by a file rather than an env var, so
# the autostart hook can enable it without env plumbing and the choice stays visible next
# to the queue it exposes. Delete the file to go back to loopback-only.
$queueDir = if ($env:QUEUE_DIR) { $env:QUEUE_DIR } else { Join-Path $HOME '.claude-harness\queue' }
$env:QUEUE_TAILSCALE = if (Test-Path (Join-Path $queueDir '.dashboard-tailnet')) { '1' } else { '0' }

try {
  Start-Process -FilePath $node -ArgumentList $server -WindowStyle Hidden `
    -RedirectStandardOutput $log -RedirectStandardError "$log.err"
} catch {
  # Losing a start race against another session is expected and harmless.
  Write-Note "start failed: $($_.Exception.Message)"
}
exit 0
