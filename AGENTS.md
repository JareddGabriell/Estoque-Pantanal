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

Each file in `.claude/rules/` uses MUST / NEVER statements. Read the ones that match the change.

| File | Theme |
|---|---|
| `.claude/rules/offline-sync.md` | Room as source of truth, outbox, UUIDs, idempotent push, append-only counts, soft deletes, last-write-wins. The most important rule set |
| `.claude/rules/android-architecture.md` | Compose, unidirectional state, `StateFlow`, Room, WorkManager, Hilt, pt-BR strings, pure `:core:domain` |
| `.claude/rules/server-architecture.md` | Flyway owns the schema, immutable migrations, layers, DTOs, Bean Validation, RFC 7807 errors, JWT in the header |
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

Git hooks are local and only run after `.githooks/install.sh`. `--no-verify` skips them, and Claude Code is denied that flag in `.claude/settings.json`. Until the Phase 2 CI repeats these checks on every PR, a `[gate]` that rests only on a git hook can still be bypassed by someone who skips the installer or the hooks.

| Rule | Status | Enforced by |
|---|---|---|
| Commit subject: Conventional Commits, allowed types, at most 72 characters, no trailing period | `[gate]` | commit-msg and pre-push hooks: `.githooks/checks/commit-subject.sh` |
| No AI co-author or attribution in commit messages | `[gate]` | commit-msg and pre-push hooks: `no-ai-coauthor.sh`. Claude Code attribution disabled in `.claude/settings.json` |
| No emoji in commit messages | `[gate]` | commit-msg and pre-push hooks: `no-emoji.sh --file`, `--range` |
| No emoji in tracked files and file names | `[gate]` | pre-push hook: `no-emoji.sh --tracked` |
| The check scripts and Claude Code hooks pass their own tests | `[gate]` | pre-push hook: `.githooks/run-tests.sh` |
| Claude Code does not edit tracked Flyway migrations | `[gate]` | PreToolUse hook: `.claude/hooks/protect-tracked-file.sh flyway` (Write, Edit and MultiEdit only; shell commands and humans are not covered) |
| Claude Code does not edit tracked Room schema JSON | `[gate]` | PreToolUse hook: `.claude/hooks/protect-tracked-file.sh room` (same limits) |
| Claude Code leaves `server/src` and `android/` compiling with unit tests green | `[gate]` | Stop hook: `.claude/hooks/stop-verify.sh` (uncommitted changes only) |
| Claude Code does not run `gh pr merge` or any command containing `--no-verify` | `[gate]` | `permissions.deny` in `.claude/settings.json`. Rules match the command text, so other bypasses (`-n`, `-c core.hooksPath=...`, wrapper scripts) are not caught |
| No secrets in the repository | `[backlog]` | `.gitleaks.toml` exists. pre-push runs gitleaks only when it is installed. CI `secret-scan` comes in Phase 2 |
| PR title follows the commit rules | `[backlog]` | Phase 2: `pr-title` workflow |
| No AI attribution in PR bodies or issues | `[backlog]` | Review. Claude Code PR attribution is disabled |
| Branch naming `<type>/<issue>-<slug>`, `Refs: #N` in commit bodies | `[backlog]` | Review |
| Squash merge only, no direct commits to `main` | `[backlog]` | Repository settings and branch protection, not configured in this PR |
| English everywhere except pt-BR user-facing strings | `[backlog]` | Review |
| Offline sync rules (`offline-sync.md`) | `[backlog]` | Review and `android-reviewer`. Phases 3 and 4 add the integration tests |
| Android architecture rules | `[backlog]` | Review and `android-reviewer` (advisory) |
| Server architecture rules (layers, DTOs, no cycles) | `[backlog]` | Review. Phase 3: ArchUnit |
| Flyway owns the schema (`schema-management.strategy=none`) | `[backlog]` | Review. Phase 3 can assert it in a test |
| Security and observability rules | `[backlog]` | Review |
| Server build and tests pass on every PR | `[backlog]` | Phase 2: CI `server` job |
| Android build, lint and unit tests pass on every PR | `[backlog]` | Phase 2: CI `android` job |
| TDD: failing test first, bug fix starts with a reproducing test | `[backlog]` | Review (process rule) |
| Coverage (JaCoCo, Kover) | `[backlog]` | Phases 3 and 4 add reports (`[measured]`). It becomes `[gate]` only when CI enforces a threshold |
| Mutation score (PIT) | `[backlog]` | Phases 3 and 4, nightly. Same path to `[measured]`, then `[gate]` |
