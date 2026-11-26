<#
.SYNOPSIS
  Protect the PR readiness workflow's target-base and check-completion contract.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$script:Failures = 0
$script:Ran = 0

function Assert($condition, [string] $label) {
    $script:Ran++
    if ($condition) { return }
    $script:Failures++
    Write-Host "FAIL  $label" -ForegroundColor Red
}

$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
$workflow = Get-Content -Raw -LiteralPath (Join-Path $repoRoot '.github\workflows\pr-readiness.yml')
$prSkill = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'skills\pr\SKILL.md')

Write-Host 'check-pr-readiness-workflow.tests' -ForegroundColor Cyan

Assert ($workflow -match 'PR_BASE_BRANCH:\s*\$\{\{\s*github\.event_name\s*==\s*''pull_request''\s*&&\s*github\.event\.pull_request\.base\.ref\s*\|\|\s*github\.event\.repository\.default_branch') 'pull request runs select their actual base and other events use the repository default'
Assert ($workflow -match 'PR_DEFAULT_BRANCH:\s*\$\{\{\s*github\.event\.repository\.default_branch') 'the workflow resolves the repository default branch dynamically'
Assert ($workflow -match 'git fetch --no-tags origin "\$PR_BASE_BRANCH:refs/remotes/origin/\$PR_BASE_BRANCH"') 'the selected base branch is fetched'
Assert ($workflow -match '-BaseBranch "\$PR_BASE_BRANCH" -DefaultBranch "\$PR_DEFAULT_BRANCH"') 'the readiness checker receives both the actual and default branches'
Assert ($workflow -notmatch '-BaseBranch main') 'the readiness workflow does not hard-code main for pull requests'
Assert ($workflow -match 'tools/tests/check-pr-readiness-workflow\.tests\.ps1') 'the workflow runs this regression check'
Assert ($workflow -match 'tools/tests/check-pr-readiness\.tests\.ps1') 'the workflow runs PR readiness regression tests'
Assert ($workflow -match 'tools/tests/validate-factory-result\.tests\.ps1') 'the required readiness job runs factory contract tests'
Assert ($workflow -match 'mainline-target:') 'a stable mainline-target status check exists for branch rulesets'
Assert ($workflow -match 'tools/check-pr-target\.ps1') 'the mainline-target job checks the PR base'
Assert ($workflow -match '- edited') 'editing a PR base reruns readiness'
Assert ($prSkill -match '-BaseBranch <default-branch> -DefaultBranch <default-branch>') 'the PR skill checks against the repository default branch'
Assert ($prSkill -match 'pull request base must be the repository default branch') 'the PR skill forbids feature-branch targets'
Assert ($prSkill -notmatch 'For a stacked PR') 'the PR skill no longer directs work into parent feature branches'
Assert ($prSkill -match 'gh pr checks <number> --watch') 'the PR workflow waits for check results'
Assert ($prSkill -match 'Keep the task in progress while checks are pending') 'pending checks cannot be reported complete'
Assert ($prSkill -match 'inspect its annotations and failed job logs') 'failed checks require diagnosis from their evidence'
Assert ($prSkill -match 'Treat `mergeable` as Git conflict state only') 'mergeability cannot stand in for CI status'

if ($script:Failures -gt 0) {
    Write-Host ("check-pr-readiness-workflow.tests: {0} assertion(s) failed out of {1}" -f $script:Failures, $script:Ran) -ForegroundColor Red
    exit 1
}

Write-Host ("check-pr-readiness-workflow.tests: {0} assertions passed" -f $script:Ran) -ForegroundColor Green
exit 0
