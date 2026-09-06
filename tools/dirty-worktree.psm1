Set-StrictMode -Version Latest

# These paths are machine-managed or generated artifacts, not project work.
# They are classified here so a closeout guard can focus on changes that need a
# branch, a stash, or an explicit discard decision.
$script:ManagedPatterns = @(
    '(^|[\\/])memories[\\/]repo[\\/]tasks([\\/]|$)',
    '(^|[\\/])\.claude[\\/]settings\.local\.json$',
    '(^|[\\/])tmp([\\/]|$)',
    '(^|[\\/])tools[\\/]__pycache__([\\/]|$)',
    '\.pyc$',
    '(^|[\\/])skills[\\/][^\\/]+[\\/]SKILL\.md\.bak-[^\\/]+$'
)

function Invoke-DirtyGit([string]$Path) {
    $saved = @{}
    foreach ($name in @('GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_COMMON_DIR', 'GIT_OBJECT_DIRECTORY', 'GIT_ALTERNATE_OBJECT_DIRECTORIES')) {
        $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
        Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
    }
    try {
        $result = @(& git -c "safe.directory=$Path" -c core.excludesFile= -C $Path status --porcelain=v1 --untracked-files=all 2>$null)
        if ($LASTEXITCODE -ne 0) { return $null }
        return $result
    } finally {
        foreach ($name in $saved.Keys) {
            if ($null -eq $saved[$name]) {
                Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
            } else {
                Set-Item -Path "Env:$name" -Value $saved[$name]
            }
        }
    }
}

function Get-StatusPaths([string]$StatusLine) {
    $path = if ($StatusLine.Length -gt 3) { $StatusLine.Substring(3).Trim() } else { '' }
    if ($path -match '^(.*) -> (.*)$') { return @($Matches[1], $Matches[2]) }
    return @($path)
}

function Test-ManagedDirtyPath([string]$StatusLine) {
    foreach ($path in Get-StatusPaths $StatusLine) {
        foreach ($pattern in $script:ManagedPatterns) {
            if ($path -match $pattern) { return $true }
        }
    }
    return $false
}

function Get-DirtyWorktreePaths([string]$Path) {
    $status = Invoke-DirtyGit $Path
    if ($null -eq $status) { return $null }
    return @($status | Where-Object {
        -not [string]::IsNullOrWhiteSpace([string]$_) -and -not (Test-ManagedDirtyPath ([string]$_))
    })
}

Export-ModuleMember -Function Get-DirtyWorktreePaths
