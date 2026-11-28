# Continuous integration

GitHub Actions repeats the local git hook checks on every PR, builds the modules that changed, and scans for secrets. The workflows live in `.github/workflows/`.

## Workflows

| Workflow | Trigger | Jobs |
|---|---|---|
| `ci.yml` | PR to `main`, push to `main`, manual | `changes`, `server`, `android`, `policy`, `shellcheck`, `secret-scan`, `compose-validate` |
| `pr-title.yml` | PR opened, edited, reopened or updated | `pr-title` |
| `nightly.yml` | Every day at 03:17 (America/Sao_Paulo), manual | `server-mutation`, `android-e2e` (placeholders until Phases 3 and 4) |

## Jobs in `ci.yml`

| Job | Runs | What it does |
|---|---|---|
| `changes` | always | On a PR, lists the changed files and tells the module jobs whether to run |
| `server` | PR that changes `server/**` or `ci.yml`; every push to `main` | JDK 25 Temurin, `./gradlew build` (compile, tests with Testcontainers through Dev Services) |
| `android` | PR that changes `android/**` or `ci.yml`; every push to `main` | JDK 25 Temurin (the daemon JVM in `android/gradle/gradle-daemon-jvm.properties`), `./gradlew assembleDebug lintDebug testDebugUnitTest`. Uploads the lint report when it fails |
| `policy` | always | `.githooks/run-tests.sh`; `commit-subject.sh`, `no-ai-coauthor.sh` and `no-emoji.sh` with `--range` on the PR commits (or the pushed commits on `main`); `no-emoji.sh --tracked` |
| `shellcheck` | always | ShellCheck on every tracked `*.sh` file or file with a shell shebang under `.githooks/` and `.claude/hooks/`, with `.shellcheckrc` |
| `secret-scan` | always | Betterleaks on the whole git history, with the same flags and files as `.githooks/pre-push` |
| `compose-validate` | always | Copies `infra/.env.example` to `infra/.env` and runs `docker compose -f infra/docker-compose.yml config -q` |

A PR that touches only `docs/` runs `changes` and the shared jobs; `server` and `android` show as skipped.

LANDMINE: the module jobs are filtered inside the workflow, with the `changes` job, not with `on.pull_request.paths`. A job skipped by its `if` condition reports success to a required status check. A workflow that never starts leaves its required checks pending, and the PR cannot be merged.

`pr-title` checks the PR title with `commit-subject.sh --subject` (the squash merge turns the title into the commit subject on `main`), `no-emoji.sh`, and `no-ai-coauthor.sh` on the title and body. The title and body reach the scripts through `env`, never through `${{ }}` inside `run`, so a crafted title cannot inject shell commands.

## Pinned versions

- Every action is pinned to a commit SHA, with the release tag in a comment. Dependabot updates both.
- `gradle/actions/setup-gradle` uses `cache-provider: basic`, the MIT-licensed cache built on `actions/cache`. The default `enhanced` provider is proprietary. The action also validates the Gradle wrapper checksums. Only runs on `main` write the cache; PR runs read it.
- ShellCheck and Betterleaks are downloaded from their GitHub releases and checked against a SHA-256 checksum written in `ci.yml`. A mismatch fails the job before the binary runs.

LANDMINE: change a tool version and its checksum together, in the same commit. Take the checksum from the release (`checksums.txt` for Betterleaks, the asset digest for ShellCheck). Betterleaks must stay on 1.x: 2.x drops `--log-opts` and `.gitleaksignore` (see `.gitleaks.toml`).

## Dependabot

`.github/dependabot.yml` opens one grouped PR per week for each of `server/` (Gradle), `android/` (Gradle) and GitHub Actions. Titles start with `build(deps):` or `ci(deps):`, so they pass `pr-title` as long as they fit in 72 characters. Shorten a longer title before merging.

## Required checks

CI reports on every PR, but a red check blocks the merge only when the `main` ruleset requires it. The ruleset is proposed in issue #3 and applied by a human. The checks to require are `changes`, `server`, `android`, `policy`, `shellcheck`, `secret-scan`, `compose-validate` and `pr-title`.

LANDMINE: `changes` must be required too. When it fails, `server` and `android` are skipped because they depend on it, and a skipped job counts as a passing required check.

## Running the same checks locally

```bash
.githooks/run-tests.sh
.githooks/checks/commit-subject.sh --range origin/main..HEAD
.githooks/checks/no-emoji.sh --tracked
shellcheck .githooks/commit-msg .githooks/pre-push .githooks/*.sh .githooks/*/*.sh .claude/hooks/*.sh .claude/hooks/lib/*.sh
betterleaks git --no-banner --redact --config .gitleaks.toml --gitleaks-ignore-path . .
cp -n infra/.env.example infra/.env && docker compose -f infra/docker-compose.yml config -q
(cd server && ./gradlew build)
(cd android && ./gradlew assembleDebug lintDebug testDebugUnitTest)
```
