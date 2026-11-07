$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'start-ssh-tunnel.ps1'
$fixture = Join-Path $PSScriptRoot 'test-ssh-tunnel.ps1'
$json = & $script -ServerName 'queue.example.com' -IdentityFile $fixture -KnownHostsFile $fixture -DryRun
$sshArgs = @($json | ConvertFrom-Json)
if ($sshArgs -notcontains 'StrictHostKeyChecking=yes') { throw 'Host key validation is missing.' }
if ($sshArgs -notcontains 'ExitOnForwardFailure=yes') { throw 'Forwarding failures are not detected.' }
if ($sshArgs -notcontains 'ForwardAgent=no') { throw 'Agent forwarding must be disabled.' }
if ($sshArgs -notcontains 'NUL') { throw 'User SSH configuration must not override the tunnel policy.' }
if ($sshArgs -notcontains '127.0.0.1:4317:127.0.0.1:4317') { throw 'The tunnel is not bound to loopback.' }
if ($sshArgs -notcontains 'queuebridge@queue.example.com') { throw 'The destination is incorrect.' }
$effective = (& ssh -G @sshArgs 2>$null) -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'OpenSSH rejected the tunnel configuration.' }
if ($effective -notmatch '(?m)^stricthostkeychecking true$') { throw 'OpenSSH did not enable host key validation.' }
if ($effective -notmatch '(?m)^exitonforwardfailure yes$') { throw 'OpenSSH did not enable forwarding failure detection.' }
if ($effective -notmatch '(?m)^remoteforward \[127\.0\.0\.1\]:4317 \[127\.0\.0\.1\]:4317$') { throw 'OpenSSH did not bind the remote port to loopback.' }
try {
    & $script -ServerName '-oProxyCommand=evil' -IdentityFile $fixture -KnownHostsFile $fixture -DryRun
    throw 'An unsafe hostname was accepted.'
} catch {
    if ($_.Exception.Message -eq 'An unsafe hostname was accepted.') { throw }
}
