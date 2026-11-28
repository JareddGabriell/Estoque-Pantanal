# beverage-inventory

Offline-first beverage inventory app for a single restaurant. The manager registers suppliers and products, each with a minimum stock, a target stock, a package type and units per package. Staff count the stock on Android phones, often without a connection. From the latest counts, the app builds a suggested order per supplier and opens WhatsApp with the text ready (a `wa.me` link, not the WhatsApp API).

Users: one manager (admin) and 4 to 6 staff. Everyone uses the same login screen, and the role decides the permissions.

Suggested order: for each product whose last count is at or below its minimum, order `target - counted`, rounded up to whole packages, grouped by supplier.

## Stack

| Module | Technology |
|---|---|
| `android/` | Kotlin, Jetpack Compose, Room, WorkManager, Hilt, DataStore. Package `app.beverageinventory`, minSdk 26 |
| `server/` | Quarkus 4.0.x, Java 25, Gradle Kotlin DSL, PostgreSQL 18, Flyway, SmallRye JWT |
| `infra/` | Docker Compose for PostgreSQL, backup scripts |
| `docs/` | Decisions, roadmap, development environment, testing |

Each module has its own Gradle wrapper. Run Gradle from the module directory (`cd server && ./gradlew test`) or with the module path (`./server/gradlew -p server test`).

## Layout

```
android/            Android app (one :app module today; :core:domain comes in Phase 4)
server/             Quarkus API
infra/              docker-compose.yml, .env.example
docs/               project documentation
.claude/rules/      rules for agents and humans, one theme per file
.claude/hooks/      Claude Code hooks and their tests
.claude/agents/     subagents (android-reviewer)
.claude/skills/     skills (tdd)
.githooks/          git hooks; .githooks/checks/ holds the policy checks shared with CI
.github/            CI workflows, Dependabot, PR template (see docs/ci.md)
```

## How we work

- **The GitHub issue is the spec.** Acceptance criteria live in the issue body. No work starts without an issue.
- **TDD:** the spec is approved, a failing test is confirmed for the right reason, then the minimal implementation, then the refactor. A bug fix starts with a test that reproduces it.
- **Branches:** `<type>/<issue>-<slug>` from `main`, one PR per issue, squash-merged by a human. Never commit to `main`.
- **Commits and PR titles:** Conventional Commits, English, imperative, at most 72 characters. The body explains why and ends with `Refs: #N` or `Closes: #N`.
- **No AI attribution and no emoji** in files, commits, PRs or issues.
- **Language:** everything in the repository is in English, except user-facing Android strings, which are in pt-BR.
- **Landmines** are marked `LANDMINE:` in comments and docs.
- Set up a clone with `.githooks/install.sh` (see `docs/dev-environment.md`).

## Rules

Each file in `.claude/rules/` uses MUST / NEVER statements. Read the ones that match the change. Claude Code loads `.claude/rules/` automatically. Rules marked "scoped" have `paths` frontmatter and load only when Claude reads or edits a file under that path. The others load in every session.

| File | Theme |
|---|---|
| `.claude/rules/offline-sync.md` | Room as source of truth, outbox, UUIDs, idempotent push, append-only counts, soft deletes, last-write-wins. The most important rule set |
| `.claude/rules/android-architecture.md` | Scoped to `android/**`. Compose, unidirectional state, `StateFlow`, Room, WorkManager, Hilt, pt-BR strings, pure `:core:domain` |
| `.claude/rules/server-architecture.md` | Scoped to `server/**`. Flyway owns the schema, immutable migrations, layers, DTOs, Bean Validation, RFC 7807 errors, JWT in the header |
| `.claude/rules/security.md` | Secrets, password hashing, tokens, personal data |
| `.claude/rules/observability.md` | Log levels, no database exception messages, public ids only |
| `.claude/rules/testing.md` | Test strategy per layer and testing rules |
| `.claude/rules/tdd.md` | The TDD loop |
| `.claude/rules/commits-and-prs.md` | Commits, branches, PRs, specs, markers |

## Quality bar

Legend:

- `[gate]`: enforced automatically by a git hook, a Claude Code hook or a CI job. It fails and blocks.
- `[measured]`: reported automatically, but does not block.
- `[backlog]`: not enforced yet. It relies on review, or on a tool planned for a later phase (noted).

Git hooks are local and only run after `.githooks/install.sh`. `--no-verify` skips them, and Claude Code is denied that flag in `.claude/settings.json`. CI (`.github/workflows/`, see `docs/ci.md`) repeats the hook checks on every PR, so skipping the hooks only moves the failure to the PR.

LANDMINE: a red CI check blocks the merge only when the `main` ruleset lists it as a required status check. Until that ruleset is applied on GitHub (proposed in issue #3), a `[gate]` enforced by CI fails visibly but does not stop a human from merging.

| Rule | Status | Enforced by |
|---|---|---|
| Commit subject: Conventional Commits, allowed types, at most 72 characters, no trailing period | `[gate]` | commit-msg and pre-push hooks, and the CI `policy` job on the PR commits: `.githooks/checks/commit-subject.sh` |
| No AI co-author or attribution in commit messages | `[gate]` | commit-msg and pre-push hooks, CI `policy`: `no-ai-coauthor.sh`. Claude Code attribution disabled in `.claude/settings.json` |
| No emoji in commit messages | `[gate]` | commit-msg and pre-push hooks, CI `policy`: `no-emoji.sh --file`, `--range` |
| No emoji in tracked files and file names | `[gate]` | pre-push hook and CI `policy`: `no-emoji.sh --tracked` |
| The check scripts and Claude Code hooks pass their own tests | `[gate]` | pre-push hook and CI `policy`: `.githooks/run-tests.sh` |
| Shell scripts in `.githooks/` and `.claude/hooks/` pass ShellCheck | `[gate]` | CI `shellcheck` job, ShellCheck 0.11.0 pinned by checksum, settings in `.shellcheckrc`. Every tracked `*.sh` file or file with a shell shebang under those folders is checked |
| No secrets in the repository | `[gate]` | CI `secret-scan` job: Betterleaks 1.10.1 pinned by checksum, whole history, with `.gitleaks.toml` and `.gitleaksignore`. pre-push runs it on the pushed commits only when Betterleaks 1.x is installed |
| PR title follows the commit rules | `[gate]` | `pr-title` workflow: `commit-subject.sh --subject`, `no-emoji.sh` and `no-ai-coauthor.sh` on the title |
| No AI attribution in PR bodies | `[gate]` | `pr-title` workflow: `no-ai-coauthor.sh` on the body. Claude Code PR attribution is disabled |
| Server build and tests pass | `[gate]` | CI `server` job: `./gradlew build` on JDK 25. Runs on PRs that change `server/**` or `ci.yml`, and on every push to `main` |
| Android build, lint and unit tests pass | `[gate]` | CI `android` job: `assembleDebug lintDebug testDebugUnitTest`. Runs on PRs that change `android/**` or `ci.yml`, and on every push to `main` |
| `infra/docker-compose.yml` is valid | `[gate]` | CI `compose-validate` job: `docker compose config -q` with `infra/.env.example` |
| Claude Code does not edit Flyway migrations merged into main | `[gate]` | PreToolUse hook: `.claude/hooks/protect-tracked-file.sh flyway` blocks files present in `origin/main`, and fails closed when `origin/main` is missing locally. Covers Write, Edit and MultiEdit only, not shell commands or humans, and is only as fresh as the last fetch |
| Claude Code does not edit Room schema JSON merged into main | `[gate]` | PreToolUse hook: `.claude/hooks/protect-tracked-file.sh room` (same criterion and limits) |
| Claude Code leaves `server/src` and `android/` compiling with unit tests green | `[gate]` | Stop hook: `.claude/hooks/stop-verify.sh` (uncommitted changes only) |
| Claude Code runs `gh pr merge` only after the human confirms it | `[gate]` | `.claude/settings.json` allows only the everyday `gh pr` subcommands (`view`, `create`, `checks`, `list`, `diff`, `status`, `edit`, `comment`), so any other `gh pr` form gets no allow rule. Commands with no rule only prompt in the default permission mode (auto mode decides them with its classifier), so `permissions.ask` names the merge forms explicitly, in every mode and ahead of the allow rules: `Bash(*pr merge*)` (`pr merge` anywhere in the command, including `gh -R owner/repo pr merge`), `Bash(gh pr -R *)` (the repository flag after `pr`, as in `gh pr -R owner/repo merge`) and `Bash(gh api *merge*)` (the REST merge endpoint). They also ask for other commands that match the same text. Same text-matching limits as the row below |
| Claude Code does not run any command containing `--no-verify` | `[gate]` | `permissions.deny` in `.claude/settings.json`. Rules match the command text, so other bypasses (`-n`, `-c core.hooksPath=...`, wrapper scripts) are not caught |
| No AI attribution in issues | `[backlog]` | Review |
| Branch naming `<type>/<issue>-<slug>`, `Refs: #N` in commit bodies | `[backlog]` | Review |
| Squash merge only, no direct commits to `main`, required CI checks | `[backlog]` | A `main` ruleset, proposed in issue #3 and not applied yet. Squash-only is a repository merge setting |
| English everywhere except pt-BR user-facing strings | `[backlog]` | Review |
| Offline sync rules (`offline-sync.md`) | `[backlog]` | Review and `android-reviewer`. Phases 3 and 4 add the integration tests |
| Android architecture rules | `[backlog]` | Review and `android-reviewer` (advisory) |
| Server architecture rules (layers, DTOs, no cycles) | `[backlog]` | Review. Phase 3: ArchUnit |
| Flyway owns the schema (`schema-management.strategy=none`) | `[backlog]` | Review. Phase 3 can assert it in a test |
| Security and observability rules | `[backlog]` | Review |
| TDD: failing test first, bug fix starts with a reproducing test | `[backlog]` | Review (process rule) |
| Coverage (JaCoCo, Kover) | `[backlog]` | Phases 3 and 4 add reports (`[measured]`). It becomes `[gate]` only when CI enforces a threshold |
| Mutation score (PIT) | `[backlog]` | Phases 3 and 4, in `nightly.yml` (a placeholder today). Same path to `[measured]`, then `[gate]` |
