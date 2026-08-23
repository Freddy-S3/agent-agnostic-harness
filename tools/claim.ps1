<#
.SYNOPSIS
  Advisory write-claim registry for concurrent agent sessions.

.DESCRIPTION
  The unit of conflict is a working tree, not a repository. Two agents in the same
  repository but different git worktrees cannot collide; two agents in one tree can, and
  did. Claims are therefore keyed on a normalised tree path.

  Claims are exclusive for writes and unnecessary for reads. A read-only agent takes no
  claim and is never blocked by one, so investigation fans out freely while editing
  serialises.

  A second claim kind, 'cascade', covers shared generated output that does not corrupt on
  concurrent edit but collides at merge time. It is claimed by name, independently of any
  tree.

  Enforcement happens at two points. A spawner runs 'acquire' and refuses to start a
  writing agent when it returns EXIT_CONFLICT. Independently, the 'pre-commit' hook in
  git-hooks/ runs 'verify' and refuses an agent commit in a tree this session does not
  hold. An instruction to check is not a mechanism; the hook is the mechanism, because it
  binds every host equally and does not rely on the agent choosing to obey.

  Sessions die unannounced on usage limits, so a claim expires. An expired claim does not
  deadlock the tree; it is reported as stale and may be taken over, and the takeover is
  recorded in the new claim so the successor knows to look for half-applied work.

.PARAMETER Action
  check | verify | acquire | release | heartbeat | list

  'check' answers "is this tree free for me to take". 'verify' answers the different
  question the hook needs: "does this session already hold this tree". They are not
  inverses - check succeeds on a free tree, verify fails on one.

.EXAMPLE
  .\claim.ps1 acquire -Tree C:\Users\Faruk\Repo\Portfolio-Website -Session sess-1
  .\claim.ps1 acquire -Cascade portfolio-site -Session sess-1
  .\claim.ps1 heartbeat -Tree C:\Users\Faruk\Repo\Portfolio-Website -Session sess-1
  .\claim.ps1 release -Tree C:\Users\Faruk\Repo\Portfolio-Website -Session sess-1

.NOTES
  Exit codes: 0 success, 3 conflict (claim held by a live peer, or 'verify' found no
  claim held by this session), 4 usage error.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet('check', 'verify', 'acquire', 'release', 'heartbeat', 'list')]
    [string]$Action,

    [string]$Tree,
    [string]$Cascade,
    [string]$Session,
    [string]$Note,

    # Minutes without a heartbeat after which a claim is presumed dead. Long enough to
    # survive a slow operation, short enough that a killed session does not hold a tree
    # for a whole sitting.
    [int]$StaleMinutes = 30,

    # Take over a stale claim. Refused against a live one - that is the whole point.
    [switch]$Force,

    [string]$RegistryPath
)

$ErrorActionPreference = 'Stop'
$EXIT_CONFLICT = 3
$EXIT_USAGE = 4

function Get-Registry {
    if ($RegistryPath) { $p = $RegistryPath }
    elseif ($env:HARNESS_CLAIM_DIR) { $p = $env:HARNESS_CLAIM_DIR }
    else { $p = Join-Path $HOME '.claude-harness\claims' }
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
    return $p
}

# A claim key must be stable across the spellings of the same location: trailing
# separators, mixed case, and short vs long form all name one tree.
function Resolve-Key {
    if ($Cascade) {
        if ($Tree) { throw 'Pass -Tree or -Cascade, not both.' }
        return @{ Kind = 'cascade'; Key = $Cascade.Trim().ToLowerInvariant() }
    }
    if (-not $Tree) { throw 'Pass -Tree <path> or -Cascade <name>.' }
    $full = try { (Resolve-Path -LiteralPath $Tree).ProviderPath } catch { $Tree }
    $norm = $full.TrimEnd('\', '/').ToLowerInvariant()
    return @{ Kind = 'tree'; Key = $norm }
}

function Get-ClaimFile($resolved, $registry) {
    $sha = [System.Security.Cryptography.SHA1]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes("$($resolved.Kind)|$($resolved.Key)")
    $hash = ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join ''
    return Join-Path $registry "$($resolved.Kind)-$($hash.Substring(0,16)).json"
}

function Read-Claim($file) {
    if (-not (Test-Path $file)) { return $null }
    try { return Get-Content $file -Raw | ConvertFrom-Json } catch { return $null }
}

function Test-Stale($claim, $staleMinutes) {
    if (-not $claim) { return $true }
    $hb = [datetime]::MinValue
    if (-not [datetime]::TryParse($claim.heartbeat, [ref]$hb)) { return $true }
    return ((Get-Date).ToUniversalTime() - $hb.ToUniversalTime()).TotalMinutes -gt $staleMinutes
}

function Write-Claim($file, $resolved, $takeoverOf) {
    $now = (Get-Date).ToUniversalTime().ToString('o')
    $existing = Read-Claim $file
    $claim = [ordered]@{
        kind        = $resolved.Kind
        key         = $resolved.Key
        session     = $Session
        status      = 'active'
        started     = if ($existing -and $existing.session -eq $Session) { $existing.started } else { $now }
        heartbeat   = $now
        branch      = if ($resolved.Kind -eq 'tree') { Get-BranchOf $resolved.Key } else { $null }
        note        = $Note
        takeover_of = $takeoverOf
    }
    $claim | ConvertTo-Json -Depth 4 | Set-Content -Path $file -Encoding utf8
    return $claim
}

function Get-BranchOf($treePath) {
    if (-not (Test-Path $treePath)) { return $null }
    try { return (git -C $treePath rev-parse --abbrev-ref HEAD 2>$null) } catch { return $null }
}

function Show-Claim($claim, $staleMinutes) {
    $state = if (Test-Stale $claim $staleMinutes) { 'STALE' } else { 'live' }
    "{0,-8} {1,-6} {2}`n         session={3} branch={4} heartbeat={5}" -f `
        $claim.kind, $state, $claim.key, $claim.session, $claim.branch, $claim.heartbeat
}

if ($Action -eq 'list') {
    $registry = Get-Registry
    $files = Get-ChildItem $registry -Filter '*.json' -File -ErrorAction SilentlyContinue
    if (-not $files) { Write-Output 'No claims held.'; exit 0 }
    foreach ($f in $files) {
        $c = Read-Claim $f.FullName
        if ($c) { Write-Output (Show-Claim $c $StaleMinutes) }
    }
    exit 0
}

if (-not $Session -and $Action -ne 'check') {
    Write-Error 'A -Session identity is required to acquire, release, or heartbeat a claim.'
    exit $EXIT_USAGE
}

try { $resolved = Resolve-Key } catch { Write-Error $_; exit $EXIT_USAGE }
$registry = Get-Registry
$file = Get-ClaimFile $resolved $registry
$existing = Read-Claim $file
$stale = Test-Stale $existing $StaleMinutes

switch ($Action) {

    'check' {
        if (-not $existing) { Write-Output "free: $($resolved.Key)"; exit 0 }
        if ($stale) { Write-Output "stale: $($resolved.Key) held by $($existing.session) since $($existing.heartbeat)"; exit 0 }
        Write-Output "held: $($resolved.Key) by $($existing.session), heartbeat $($existing.heartbeat)"
        exit $EXIT_CONFLICT
    }

    'verify' {
        # A commit is proof of life, so a claim this session already owns is refreshed
        # rather than rejected for being stale. Staleness exists to let a peer take over a
        # dead session's tree, not to lock the live session out of its own.
        if (-not $existing) {
            Write-Output "UNCLAIMED: $($resolved.Key) is not claimed by anyone."
            exit $EXIT_CONFLICT
        }
        if ($existing.session -ne $Session) {
            $state = if ($stale) { 'a stale claim from' } else { 'a live claim held by' }
            Write-Output "NOTYOURS: $($resolved.Key) has $state $($existing.session), not $Session."
            exit $EXIT_CONFLICT
        }
        Write-Claim $file $resolved $existing.takeover_of | Out-Null
        Write-Output "verified: $($resolved.Key) held by $Session"
        exit 0
    }

    'acquire' {
        if ($existing -and $existing.session -eq $Session) {
            Write-Claim $file $resolved $existing.takeover_of | Out-Null
            Write-Output "reacquired: $($resolved.Key)"
            exit 0
        }
        if ($existing -and -not $stale) {
            Write-Output "CONFLICT: $($resolved.Key) is held by $($existing.session) (heartbeat $($existing.heartbeat))."
            if ($resolved.Kind -eq 'tree') {
                Write-Output 'Do not write in this tree. Create your own worktree off the default branch and claim that path instead.'
            } else {
                Write-Output 'Do not regenerate this cascade. Wait for release, or claim a different cascade.'
            }
            exit $EXIT_CONFLICT
        }
        if ($existing -and $stale -and -not $Force) {
            Write-Output "STALE: $($resolved.Key) was held by $($existing.session) (heartbeat $($existing.heartbeat))."
            Write-Output 'That session did not release it, so it may have died mid-operation. Read its run journal for an INTENT with no OUTCOME before writing anything, then re-run with -Force to take it over.'
            exit $EXIT_CONFLICT
        }
        $takeover = if ($existing) { $existing.session } else { $null }
        Write-Claim $file $resolved $takeover | Out-Null
        if ($takeover) { Write-Output "acquired (took over stale claim from $takeover): $($resolved.Key)" }
        else { Write-Output "acquired: $($resolved.Key)" }
        exit 0
    }

    'heartbeat' {
        if (-not $existing) { Write-Error "No claim to heartbeat for $($resolved.Key)."; exit $EXIT_USAGE }
        if ($existing.session -ne $Session) {
            Write-Output "CONFLICT: $($resolved.Key) is held by $($existing.session), not $Session."
            exit $EXIT_CONFLICT
        }
        Write-Claim $file $resolved $existing.takeover_of | Out-Null
        Write-Output "heartbeat: $($resolved.Key)"
        exit 0
    }

    'release' {
        if (-not $existing) { Write-Output "already free: $($resolved.Key)"; exit 0 }
        if ($existing.session -ne $Session -and -not $Force) {
            Write-Output "CONFLICT: $($resolved.Key) is held by $($existing.session), not $Session. Releasing another session's live claim needs -Force."
            exit $EXIT_CONFLICT
        }
        Remove-Item $file -Force
        Write-Output "released: $($resolved.Key)"
        exit 0
    }
}
