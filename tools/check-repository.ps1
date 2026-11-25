<#
.SYNOPSIS
  Resolve the Git repository for a Ship target before delivery-mode setup.

.DESCRIPTION
  This is the professional-mode repository preflight. It distinguishes a valid
  repository from a plain folder and from a parent folder containing a nested
  repository. Initialization is opt-in because it changes project state.

.EXIT CODES
  0  A repository was found or initialized.
  2  No repository was found.
  3  Initialization was unsafe or the path is ambiguous.
  4  The check could not run.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Path,
    [switch] $Initialize
)

$ErrorActionPreference = 'Stop'

function Write-Result([hashtable] $Result, [int] $ExitCode) {
    [pscustomobject]$Result | ConvertTo-Json -Compress
    exit $ExitCode
}

function Invoke-Git([string] $WorkingDirectory, [string[]] $Arguments) {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = @(& git -C $WorkingDirectory @Arguments 2>$null)
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    [pscustomobject]@{ Output = $output; Code = $code }
}

try {
    $target = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    if (-not (Test-Path -LiteralPath $target -PathType Container)) {
        Write-Result @{ schemaVersion = 1; status = 'invalid-path'; path = $target; reason = 'Target is not a directory.' } 4
    }

    $rootResult = Invoke-Git $target @('rev-parse', '--show-toplevel')
    if ($rootResult.Code -eq 0 -and $rootResult.Output.Count -gt 0) {
        $rootOutput = $rootResult.Output
        $root = (Resolve-Path -LiteralPath ($rootOutput -join '').Trim()).Path
        $gitDirResult = Invoke-Git $target @('rev-parse', '--git-dir')
        $gitDir = if ($gitDirResult.Code -eq 0) { ($gitDirResult.Output -join '').Trim() } else { $null }
        $headResult = Invoke-Git $target @('rev-parse', '--verify', 'HEAD')
        $hasCommit = $headResult.Code -eq 0 -and $headResult.Output.Count -gt 0
        Write-Result @{
            schemaVersion = 1
            status = 'found'
            path = $target
            root = $root
            gitDir = $gitDir
            hasCommit = $hasCommit
            action = 'none'
        } 0
    }

    $nestedCandidates = @(
        Get-ChildItem -LiteralPath $target -Directory -Force -ErrorAction SilentlyContinue |
            ForEach-Object {
                $candidateResult = Invoke-Git $_.FullName @('rev-parse', '--show-toplevel')
                if ($candidateResult.Code -eq 0 -and $candidateResult.Output.Count -gt 0) {
                    $candidateOutput = $candidateResult.Output
                    $candidateRoot = (Resolve-Path -LiteralPath ($candidateOutput -join '').Trim()).Path
                    if ($candidateRoot -eq $_.FullName) { $candidateRoot }
                }
            } |
            Sort-Object -Unique
    )

    if ($Initialize) {
        if ($nestedCandidates.Count -gt 0) {
            Write-Result @{
                schemaVersion = 1
                status = 'nested-candidate'
                path = $target
                nestedCandidates = $nestedCandidates
                action = 'select-candidate'
                reason = 'A nested repository exists; initializing the parent would create the wrong project root.'
            } 3
        }

        if (Test-Path -LiteralPath (Join-Path $target '.git')) {
            Write-Result @{
                schemaVersion = 1
                status = 'invalid-git'
                path = $target
                action = 'repair-or-inspect'
                reason = 'A .git entry exists but Git could not resolve it.'
            } 3
        }

        $initResult = Invoke-Git $target @('init', '-b', 'main')
        if ($initResult.Code -ne 0) {
            $initResult = Invoke-Git $target @('init')
        }
        if ($initResult.Code -ne 0) {
            Write-Result @{ schemaVersion = 1; status = 'initialization-failed'; path = $target; action = 'inspect-git-error' } 4
        }

        Write-Result @{
            schemaVersion = 1
            status = 'initialized'
            path = $target
            root = $target
            gitDir = (Join-Path $target '.git')
            hasCommit = $false
            action = 'baseline-commit-required'
        } 0
    }

    if ($nestedCandidates.Count -gt 0) {
        Write-Result @{
            schemaVersion = 1
            status = 'nested-candidate'
            path = $target
            nestedCandidates = $nestedCandidates
            action = 'select-candidate'
            reason = 'A nested repository exists; use that project root or explicitly choose initialization.'
        } 2
    }

    Write-Result @{
        schemaVersion = 1
        status = 'missing'
        path = $target
        action = 'initialize-after-approval'
        reason = 'The target is not inside a Git repository.'
    } 2
} catch {
    Write-Result @{ schemaVersion = 1; status = 'check-failed'; path = $Path; action = 'inspect-error'; reason = $_.Exception.Message } 4
}
