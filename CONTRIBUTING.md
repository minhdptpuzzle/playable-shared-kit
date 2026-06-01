# Contributing

`main` must be treated as a pull-only branch.

No one should push directly to `main`. Every update must land through a pull request, and only `@minhdptpuzzle` should review, approve, and merge that pull request.

## Expected Flow

1. Contributors pull the latest `main`.
2. Contributors create a topic branch in their own fork or in a non-protected branch.
3. Contributors push only to that topic branch.
4. Contributors open a pull request targeting `minhdptpuzzle/playable-shared-kit:main`.
5. CI and policy checks run automatically.
6. Only `@minhdptpuzzle` gives the approval that matters.
7. Only `@minhdptpuzzle` performs the merge into `main`.

## Access Model

This repository is a personal repository, not an organization-owned repository.

That matters because GitHub policy can block direct updates to `main`, but the cleanest way to guarantee owner-only merge authority in a personal repo is still account access:

1. Keep `@minhdptpuzzle` as the only account with `write`, `maintain`, or `admin` access.
2. Give everyone else `read` access only.
3. Require contributors to work from forks or non-protected branches.

If another person keeps `write` access, GitHub may still allow that person to act on merges once PR requirements are satisfied. The workflow in this repo is therefore designed around a stricter rule: only `@minhdptpuzzle` keeps write-capable access.

## Main Branch Protection

Configure branch protection for `main` directly in GitHub.

Required settings for `main`:

1. Require a pull request before merging.
2. Require exactly 1 or more approvals.
3. Require review from Code Owners.
4. Dismiss stale approvals when new commits are pushed.
5. Require approval of the most recent reviewable push.
6. Require the `owner-approval` status check from the `Owner Approval Gate` workflow.
7. Require conversation resolution before merging.
8. Block force pushes.
9. Block branch deletion.
10. Apply the restrictions to administrators too.

The result should be:

1. `main` receives changes only through PR merge.
2. Direct push to `main` is blocked, including for `@minhdptpuzzle`.
3. `@minhdptpuzzle` is still the only practical merge actor because no one else keeps write-capable repository access.

These branch protection settings live on GitHub, not in this repository. Once they are configured successfully, they do not need a setup script committed in the repo.

## Files That Enforce The Policy

- `.github/CODEOWNERS` makes `@minhdptpuzzle` the required code owner for the whole repository.
- `.github/workflows/owner-approval-gate.yml` fails until `@minhdptpuzzle` has an active approval on the PR.
- `.github/PULL_REQUEST_TEMPLATE.md` reminds contributors that `main` is PR-only and owner-merged.

## Notes

- Other users may still comment on PRs, but their approval must not be treated as merge authority.
- If the repository is ever moved into an organization, add explicit push restrictions for `main` so GitHub enforces the merge actor at the branch level too.
- If automation ever needs to update `main`, grant that GitHub App the minimum required path through branch protection instead of widening human access.