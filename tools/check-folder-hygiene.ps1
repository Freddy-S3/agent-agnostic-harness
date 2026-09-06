<#
.SYNOPSIS
  Check or reserve a project-family folder slot.

.DESCRIPTION
  Active sibling checkouts for one repository family are capped at three: the canonical
  checkout, one pinned long-running service checkout, and one active task checkout. The
  guard groups Git folders by their origin repository, with explicit aliases for legacy
  names such as aah-* and PW-* when Git metadata is unavailable.

  Archives, dot-folders, underscore-folders, attachments, screenshots, and other named
  runtime folders are not active project checkouts and are excluded deliberately.

.EXAMPLE
  powershell -NoProfile -File tools\check-folder-hygiene.ps1 -Action check -WorkspaceRoot C:\Users\Faruk\Repo
  powershell -NoProfile -File tools\check-folder-hygiene.ps1 -Action assert-add -WorkspaceRoot C:\Users\Faruk\Repo -CandidatePath C:\Users\Faruk\Repo\aah-next -Family agent-agnostic-harness
  powershell -NoProfile -File tools\check-folder-hygiene.ps1 -Action list -WorkspaceRoot C:\Users\Faruk\Repo
#>
[CmdletBinding()]
param(
    [ValidateSet('check', 'assert-add', 'list')]
    [string]$Action = 'check',
    [Parameter(Mandatory)][string]$WorkspaceRoot,
    [string]$CandidatePath,
    [string]$Family,
    [int]$MaxFolders = 3
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'folder-hygiene.psm1') -Force

try {
    if ($Action -eq 'list') {
        $records = @(Get-FolderRecords $WorkspaceRoot)
        foreach ($group in @($records | Group-Object Family | Sort-Object Name)) {
            Write-Output ("{0}`t{1}`t{2}" -f $group.Name, $group.Count, (($group.Group.Path | Sort-Object) -join '; '))
        }
        exit 0
    }

    if ($Action -eq 'assert-add' -and -not $CandidatePath) {
        throw '-CandidatePath is required for -Action assert-add.'
    }

    $violations = @(Get-FamilyViolations -WorkspaceRoot $WorkspaceRoot -CandidatePath $CandidatePath -Family $Family -MaxFolders $MaxFolders)
    if ($violations.Count -eq 0) { exit 0 }

    foreach ($violation in $violations) {
        Write-Output ("FOLDER_LIMIT: {0} has {1} active folders; maximum is {2}." -f $violation.Family, $violation.Count, $violation.Max)
        foreach ($path in $violation.Paths) { Write-Output "  $path" }
    }
    exit 1
} catch {
    Write-Error $_
    exit 2
}
