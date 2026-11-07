param(
    [Parameter(Mandatory = $true)][string]$ServerName,
    [Parameter(Mandatory = $true)][string]$IdentityFile,
    [Parameter(Mandatory = $true)][string]$KnownHostsFile,
    [ValidatePattern('^[a-z_][a-z0-9_-]*$')][string]$UserName = 'queuebridge',
    [ValidateRange(1, 65535)][int]$LocalPort = 4317,
    [ValidateRange(1, 65535)][int]$RemotePort = 4317,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
if ($ServerName -notmatch '^(?=.{1,253}$)[a-zA-Z0-9](?:[a-zA-Z0-9.-]*[a-zA-Z0-9])?$') {
    throw 'ServerName must be a DNS name or address without command options.'
}
if (!(Test-Path -LiteralPath $IdentityFile -PathType Leaf)) { throw 'Identity file not found.' }
if (!(Test-Path -LiteralPath $KnownHostsFile -PathType Leaf)) { throw 'Pinned known-hosts file not found.' }
$identity = (Resolve-Path -LiteralPath $IdentityFile).Path
$knownHosts = (Resolve-Path -LiteralPath $KnownHostsFile).Path
$arguments = @(
    '-N', '-T', '-F', 'NUL',
    '-o', 'BatchMode=yes',
    '-o', 'IdentitiesOnly=yes',
    '-o', 'StrictHostKeyChecking=yes',
    '-o', "UserKnownHostsFile=$knownHosts",
    '-o', 'GlobalKnownHostsFile=NUL',
    '-o', 'PasswordAuthentication=no',
    '-o', 'KbdInteractiveAuthentication=no',
    '-o', 'ForwardAgent=no',
    '-o', 'ExitOnForwardFailure=yes',
    '-o', 'ServerAliveInterval=30',
    '-o', 'ServerAliveCountMax=3',
    '-i', $identity,
    '-R', "127.0.0.1:${RemotePort}:127.0.0.1:${LocalPort}",
    "${UserName}@${ServerName}"
)

if ($DryRun) {
    $arguments | ConvertTo-Json -Compress
    return
}

while ($true) {
    & ssh @arguments
    Write-Warning 'The queue tunnel disconnected; retrying in 10 seconds.'
    Start-Sleep -Seconds 10
}
