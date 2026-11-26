<#
.SYNOPSIS
  Require pull requests to target the repository default branch.

.EXIT CODES
  0  Target is the repository default branch.
  4  Required branch names are missing.
  6  Target is not the repository default branch.
#>
[CmdletBinding()]
param(
    [string] $BaseBranch,
    [string] $DefaultBranch
)

$ErrorActionPreference = 'Stop'
if (-not $BaseBranch -or -not $DefaultBranch) {
    Write-Output 'BLOCKED: both -BaseBranch and -DefaultBranch are required.'
    exit 4
}

if ($BaseBranch -cne $DefaultBranch) {
    Write-Output "BLOCKED: pull requests must target the repository default branch '$DefaultBranch'; the requested base is '$BaseBranch'."
    exit 6
}

Write-Output "PR target: $BaseBranch (repository default)"
exit 0
