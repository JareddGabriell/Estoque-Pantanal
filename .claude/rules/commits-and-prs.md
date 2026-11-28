# Commits and pull requests

## Commits

- MUST follow Conventional Commits: `<type>(<scope>)!: <description>`, where scope and `!` are optional.
- MUST use one of these types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.
- MUST use a module as the scope (`android`, `server`, `infra`, `ci`, `docs`) or a domain (`sync`, `auth`, `order`).
- MUST write the subject in English, in the imperative ("add", not "added"), at most 72 characters, with no trailing period.
- MUST write a body that explains why the change was made and flags any landmine. It must make sense on its own in `git show`.
- MUST reference the issue in the body with `Refs: #N` or `Closes: #N`.
- NEVER add an AI co-author trailer, a "Generated with" line or any other AI attribution. Claude Code attribution is disabled in `.claude/settings.json`.
- NEVER use emoji anywhere, including in the subject and the body.
- NEVER bypass the hooks with `--no-verify`. A failing hook means the change is not ready.

## Branches

- MUST branch from `main` and name the branch `<type>/<issue>-<slug>`, for example `feature/12-supplier-crud`, `fix/31-order-rounding` or `chore/1-agent-instructions`.
- MUST keep branches short-lived. `main` is the only permanent branch.
- MUST rebase on `main` instead of merging `main` into the branch.
- NEVER commit directly to `main`.

## Pull requests

- MUST open one PR per issue, targeting `main`, and leave the merge to a human.
- MUST give the PR a title that follows the commit rules. PRs are squash-merged, so the title becomes the commit subject on `main`.
- MUST fill in the template sections: What, Why, How to verify, Risk and rollback.
- MUST state in the PR description any test or threshold that was skipped, disabled or lowered, and why.
- NEVER put AI attribution in the PR title or body, or in issues.
- MUST merge only with `gh pr merge <n> --squash --delete-branch`, and only after the human explicitly approves the merge in the session.
- NEVER merge a PR with failing or pending checks once CI exists (Phase 2).

## Specs

- The GitHub issue is the spec. Its acceptance criteria live in the issue body.
- MUST get the issue approved before implementation starts (see `tdd.md`).

## Markers

- MUST mark non-obvious traps with `LANDMINE:` in code comments and docs, so they can be found with `git grep LANDMINE`.

## Enforcement

The commit-msg and pre-push hooks run `.githooks/checks/commit-subject.sh`, `no-ai-coauthor.sh` and `no-emoji.sh`. Install them with `.githooks/install.sh`. PR title checks, branch naming and `Refs:` lines are not enforced yet; see the quality bar in `AGENTS.md`.
