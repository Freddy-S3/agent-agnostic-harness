Set-StrictMode -Version Latest

$script:ExcludedFolderNames = @(
    'temp',
    'tmp',
    'Dispatch images',
    'archive-view-screenshots',
    'unattended-runs'
)

function ConvertTo-NormalizedPath([string]$Path) {
    try {
        return ([IO.Path]::GetFullPath($Path)).TrimEnd('\', '/').ToLowerInvariant()
    } catch {
        return $Path.TrimEnd('\', '/').ToLowerInvariant()
    }
}

function Test-ExcludedFolder([string]$Name) {
    return $Name.StartsWith('.') -or $Name.StartsWith('_') -or $script:ExcludedFolderNames -contains $Name
}

function Get-RemoteSlug([string]$Remote) {
    if (-not $Remote) { return $null }
    $value = $Remote.Trim().TrimEnd('/') -replace '\.git$', ''
    if ($value -match '[:/]([^/:]+/[^/]+)$') {
        return $Matches[1].ToLowerInvariant()
    }
    return $null
}

function Invoke-GitProbe([string]$Path, [string[]]$Arguments) {
    # Git hooks export GIT_DIR for the repository being committed. Without clearing it,
    # every sibling probe reads that one repository's remote and all folders collapse into
    # the same family - exactly the false over-limit result the commit backstop must avoid.
    $names = @('GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_COMMON_DIR', 'GIT_OBJECT_DIRECTORY', 'GIT_ALTERNATE_OBJECT_DIRECTORIES')
    $saved = @{}
    foreach ($name in $names) {
        $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
        Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
    }
    try {
        & git -c "safe.directory=$Path" -C $Path @Arguments 2>$null
    } finally {
        foreach ($name in $names) {
            if ($null -eq $saved[$name]) {
                Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
            } else {
                Set-Item -Path "Env:$name" -Value $saved[$name]
            }
        }
    }
}

function Get-FallbackFamily([string]$Name) {
    switch -Regex ($Name) {
        '^(aah-|agent-agnostic-harness(?:-|$))' { return 'agent-agnostic-harness' }
        '^(agent-operations-console(?:-|$))' { return 'agent-operations-console' }
        '^(PW-|Portfolio-Website(?:-|$))' { return 'Portfolio-Website' }
        '^(job-applications(?:-|$))' { return 'job-applications' }
        '^(hoshi-candle-co(?:-|$))' { return 'hoshi-candle-co' }
        default { return "folder:$($Name.ToLowerInvariant())" }
    }
}

function Get-FolderFamily([string]$Path) {
    $name = Split-Path -Leaf $Path
    $gitMarker = Join-Path $Path '.git'
    if (Test-Path -LiteralPath $gitMarker) {
        $remote = $null
        try {
            $remote = (Invoke-GitProbe $Path @('config', '--get', 'remote.origin.url') | Select-Object -First 1)
        } catch { $remote = $null }
        $slug = Get-RemoteSlug ([string]$remote)
        if ($slug) { return "repo:$slug" }

        $common = $null
        try {
            $common = (Invoke-GitProbe $Path @('rev-parse', '--path-format=absolute', '--git-common-dir') | Select-Object -First 1)
        } catch { $common = $null }
        if ($common) { return "git-common:$(ConvertTo-NormalizedPath ([string]$common))" }
    }
    return Get-FallbackFamily $name
}

function Get-FolderRecords([string]$WorkspaceRoot) {
    $root = (Resolve-Path -LiteralPath $WorkspaceRoot -ErrorAction Stop).ProviderPath
    foreach ($folder in Get-ChildItem -LiteralPath $root -Directory -Force) {
        if (Test-ExcludedFolder $folder.Name) { continue }
        [pscustomobject]@{
            Name    = $folder.Name
            Path    = $folder.FullName
            Family  = Get-FolderFamily $folder.FullName
            Excluded = $false
        }
    }
}

function Resolve-FamilyKey([string]$Family, [object[]]$Records) {
    if (-not $Family) { return $null }
    $exact = @($Records | Where-Object { $_.Family -eq $Family })
    if ($exact.Count -gt 0) { return $exact[0].Family }

    $friendly = Get-FallbackFamily $Family
    $suffix = "/$($friendly.ToLowerInvariant())"
    $matches = @($Records | Where-Object {
        $_.Family.ToLowerInvariant().EndsWith($suffix)
    })
    if ($matches.Count -gt 0) { return $matches[0].Family }
    return $Family
}

function Get-FamilyViolations {
    param(
        [Parameter(Mandatory)][string]$WorkspaceRoot,
        [string]$CandidatePath,
        [string]$Family,
        [int]$MaxFolders = 3
    )

    $records = @(Get-FolderRecords $WorkspaceRoot)
    if ($CandidatePath) {
        $candidate = ConvertTo-NormalizedPath $CandidatePath
        $known = @($records | Where-Object { (ConvertTo-NormalizedPath $_.Path) -eq $candidate })
        if ($known.Count -eq 0) {
            if (-not $Family) { $Family = Get-FallbackFamily (Split-Path -Leaf $CandidatePath) }
            if ($Family -like 'folder:*') { throw 'A new candidate path needs -Family so its project type is unambiguous.' }
            $Family = Resolve-FamilyKey $Family $records
            $records += [pscustomobject]@{
                Name     = Split-Path -Leaf $CandidatePath
                Path     = $CandidatePath
                Family   = $Family
                Excluded = $false
            }
        } elseif (-not $Family) {
            # A commit or claim passes its current tree as the candidate. Scope the
            # backstop to that tree's family so unrelated workspace debt does not block
            # an otherwise healthy repository.
            $Family = $known[0].Family
        } else {
            $Family = Resolve-FamilyKey $Family $records
        }
    }

    $groups = @($records | Group-Object Family)
    foreach ($group in $groups) {
        if ($Family -and $group.Name -ne $Family) { continue }
        if ($group.Count -le $MaxFolders) { continue }
        [pscustomobject]@{
            Family = $group.Name
            Count  = $group.Count
            Max    = $MaxFolders
            Paths  = @($group.Group | ForEach-Object { $_.Path })
        }
    }
}

Export-ModuleMember -Function Get-FolderRecords, Get-FamilyViolations, Get-FolderFamily
