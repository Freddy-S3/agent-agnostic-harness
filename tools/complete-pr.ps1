[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[^/\s]+/[^/\s]+$')][string] $Repository,
    [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int] $Number,
    [Parameter(Mandatory)][ValidateSet('personal', 'delivery')][string] $Mode,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{40}$')][string] $ExpectedHead,
    [ValidatePattern('^[0-9a-fA-F]{40}$')][string] $ApprovedHead,
    [ValidateSet('squash', 'merge', 'rebase')][string] $Method = 'squash'
)

$ErrorActionPreference = 'Stop'
if ($Mode -eq 'delivery' -and $ApprovedHead -ne $ExpectedHead) {
    throw 'Delivery requires an explicit lgtm for the current head before merging.'
}

$default = gh repo view $Repository --json defaultBranchRef --jq .defaultBranchRef.name
if ($LASTEXITCODE -ne 0 -or -not $default) { throw 'Could not resolve the repository default branch.' }
$metadata = gh pr view $Number -R $Repository --json baseRefName,headRefOid,state,isDraft
if ($LASTEXITCODE -ne 0) { throw 'Could not read the pull request.' }
$pr = $metadata | ConvertFrom-Json
if ($pr.baseRefName -cne $default) { throw "PR #$Number must target '$default'." }
if ($pr.headRefOid -ne $ExpectedHead) { throw "PR #$Number changed since verification." }
if ($pr.state -eq 'MERGED') { return }
if ($pr.state -ne 'OPEN' -or $pr.isDraft) { throw "PR #$Number must be open and ready for review." }

gh pr checks $Number -R $Repository
if ($LASTEXITCODE -ne 0) { throw "PR #$Number has pending or unsuccessful checks." }

gh pr merge $Number -R $Repository "--$Method" --match-head-commit $ExpectedHead
if ($LASTEXITCODE -ne 0) { throw "GitHub did not accept the merge for PR #$Number." }
$merged = gh pr view $Number -R $Repository --json state,baseRefName,mergeCommit
if ($LASTEXITCODE -ne 0) { throw 'Could not verify the merge result.' }
$result = $merged | ConvertFrom-Json
if ($result.state -ne 'MERGED' -or $result.baseRefName -cne $default -or -not $result.mergeCommit.oid) {
    throw "PR #$Number has not landed on '$default'. Check for a merge queue before retrying."
}
Write-Output "PR #$Number merged into $default at $($result.mergeCommit.oid)."
