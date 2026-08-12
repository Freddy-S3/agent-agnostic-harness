# Starts the queue dashboard if it is not already up, then returns immediately.
# Idempotent by design: every Claude Code session runs this, and only the first one
# that finds the port free actually spawns a server.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/queue-dashboard/start.ps1
#   ... -File tools/queue-dashboard/start.ps1 -Restart   # stop a live server and relaunch

param([switch]$Restart)

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

# Staleness has to be checked BEFORE the up-check, not after. The whole failure mode is
# that the port answers and is serving old code, so any guard placed after the early exit
# below would never run in the exact case it exists to catch. This has now happened twice:
# the worktree was left on a merged PR branch, the launcher saw a healthy port, and the
# dashboard quietly served a build two PRs behind while looking entirely normal.
#
# Returns $true (stale), $false (current), or $null (cannot tell - no git, no network,
# no origin/main). Unknown is never treated as stale; a launcher that cries wolf offline
# gets ignored, which costs more than the thing it warns about.
function Test-Stale([string]$root) {
  try {
    $head = & git -C $root rev-parse --verify HEAD 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }

    # Fetching on every session start would put the network in a hot path for no gain;
    # a merged PR does not need to be noticed within the hour.
    $fetchHead = Join-Path $root '.git\FETCH_HEAD'
    $age = if (Test-Path $fetchHead) {
      (Get-Date) - (Get-Item $fetchHead).LastWriteTime
    } else {
      [TimeSpan]::MaxValue
    }
    if ($age.TotalHours -ge 1) { & git -C $root fetch origin --quiet 2>$null | Out-Null }

    & git -C $root rev-parse --verify origin/main 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { return $null }

    # Ask "is origin/main contained in HEAD", not "is HEAD contained in origin/main".
    # The second question is the intuitive one and it is wrong: a branch that was merged
    # and then left behind is still an ancestor of main, so it answers "yes, fine" for
    # precisely the checkout this guard exists to catch. Asking it this way round also
    # covers a feature branch that never picked up later main commits.
    & git -C $root merge-base --is-ancestor origin/main HEAD 2>$null | Out-Null
    return ($LASTEXITCODE -ne 0)
  } catch {
    return $null
  }
}

# The launcher and the running server are often not the same checkout - the whole point of
# a pinned worktree is that they differ. Checking $PSScriptRoot's repo would therefore audit
# the wrong HEAD in precisely the split this guard exists for, so resolve the root from the
# listening process's own command line and fall back to $PSScriptRoot only if that fails.
function Get-ServingRoot([int]$p) {
  try {
    $owner = Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction Stop |
      Select-Object -First 1 -ExpandProperty OwningProcess
    $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$owner" -ErrorAction Stop).CommandLine
    $m = [regex]::Match($cmd, '([A-Za-z]:\\[^"]*?)tools\\queue-dashboard\\server\.mjs')
    if ($m.Success) { return $m.Groups[1].Value.TrimEnd('\') }
    return $null
  } catch {
    return $null
  }
}

function Stop-Dashboard([int]$p) {
  try {
    $owners = Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction Stop |
      Select-Object -ExpandProperty OwningProcess -Unique
    foreach ($owner in $owners) { Stop-Process -Id $owner -Force -ErrorAction Stop }
    Start-Sleep -Milliseconds 800
    return $true
  } catch {
    Write-Note "could not stop the server on port ${p}: $($_.Exception.Message)"
    return $false
  }
}

$localRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

if (Test-Up $port) {
  $repoRoot = Get-ServingRoot $port
  if (-not $repoRoot) { $repoRoot = $localRoot }
  if ((Test-Stale $repoRoot) -ne $true) { exit 0 }

  # Warn by default rather than killing a server the user may be typing an answer into.
  # Submitted answers are already on disk; unsent text in a box is not, and silently
  # discarding it to fix a staleness problem the user has not seen yet is the wrong trade.
  $msg = "dashboard on port $port is running from $repoRoot, which is BEHIND origin/main - " +
         "it may be serving stale code. Fix: git -C `"$repoRoot`" pull --ff-only, then re-run " +
         "this script with -Restart."
  Write-Note $msg
  Write-Warning $msg

  if (-not $Restart) { exit 0 }
  if (-not (Stop-Dashboard $port)) { exit 0 }
} elseif ((Test-Stale $localRoot) -eq $true) {
  # Nothing is running, so there is no typed text to lose and nothing to ask about.
  Write-Note "starting from $localRoot, which is behind origin/main - consider pulling"
}

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
