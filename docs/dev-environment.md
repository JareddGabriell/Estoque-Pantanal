# Development environment

The project is developed on two machines: a Fedora Linux workstation and a Windows 11 PC.

## Tools

| Tool | Purpose | Notes |
|---|---|---|
| Git | Version control | On Windows: `git config --global core.longpaths true` |
| GitHub CLI (`gh`) | Repository, releases and secrets | `gh auth login` |
| Android Studio | App, SDK and emulator | Ships with the JDK that the Android Gradle build uses |
| JDK 25 (Temurin) | Quarkus backend | Separate from the Android Studio JDK |
| IntelliJ IDEA | Backend | — |
| Docker | PostgreSQL and Quarkus Dev Services | On Windows, Docker Desktop (WSL2 backend) |
| DBeaver | Inspecting the database | — |
| perl | `no-emoji.sh` check | Shipped with Git for Windows and Fedora |
| jq or python3 | Claude Code hooks read their JSON input | Either one is enough. Fedora has python3. On Windows, install jq (`winget install jqlang.jq`) |
| gitleaks | Secret scan in the pre-push hook | Optional locally. When it is missing, pre-push skips the scan, and CI runs it from Phase 2 |

## Fedora

- **Android Studio:** the official `.tar.gz`, extracted to `~/.local/opt/android-studio`. A desktop entry in `~/.local/share/applications/android-studio.desktop` launches it through the native launcher `bin/studio`.
- **Emulator:** needs read/write access to `/dev/kvm`.
- **Repository:** `~/beverage-inventory`.

## Windows

- **Project folder:** keep it outside OneDrive, whose syncing interferes with Gradle, and outside the WSL filesystem.
- **Emulator:** Docker Desktop enables Hyper-V. Turn on the "Windows Hypervisor Platform" feature so the emulator can run alongside it.

## Common setup

- **Physical device:** enable USB or wireless debugging. Open the API port in the firewall, for the private network only.
- **API address:**
  - From the emulator, the host machine is `10.0.2.2`.
  - From a physical device, use the host's LAN IP.
  - Plain HTTP is allowed only in debug builds, through `network_security_config`.
- **Line endings:** `.gitattributes` enforces LF everywhere except `*.bat`, `*.cmd` and `*.ps1`.

## Secrets

This repository is public. Never commit the keystore, `.env` files, `local.properties` or any real restaurant data. In CI, the keystore and its passwords live in GitHub Actions secrets.

## Setup order

1. Create the Android project in `android/` with the Android Studio wizard (Empty Activity, Compose, Kotlin DSL).
2. Generate the Quarkus project in `server/` at code.quarkus.io, with these extensions: REST Jackson, Hibernate ORM Panache, JDBC PostgreSQL, Flyway, SmallRye JWT and SmallRye Health.
3. Start PostgreSQL with Docker Compose and check that `/q/health` responds.
4. Add the CI workflows.

## Git hooks

Run this once per clone, on each machine:

```bash
.githooks/install.sh
```

It sets `git config core.hooksPath .githooks` for this clone and lists any missing tools. The hooks call the scripts in `.githooks/checks/`, which are the same scripts CI uses:

| Hook | Runs |
|---|---|
| `commit-msg` | `commit-subject.sh --file`, `no-ai-coauthor.sh --file`, `no-emoji.sh --file` on the new message |
| `pre-push` | `.githooks/run-tests.sh`; then `commit-subject.sh`, `no-ai-coauthor.sh` and `no-emoji.sh` with `--range` on the pushed commits; `no-emoji.sh --tracked`; and gitleaks, when it is installed |

To run the checks by hand:

```bash
.githooks/run-tests.sh                                   # tests of every check and Claude Code hook
.githooks/checks/commit-subject.sh --subject "feat(sync): add push endpoint"
.githooks/checks/commit-subject.sh --range origin/main..HEAD
.githooks/checks/no-emoji.sh --tracked
```

LANDMINE: `git commit --no-verify` and `git push --no-verify` skip the hooks. Do not use them. CI repeats the checks from Phase 2 on.

On Windows, run the installer from Git Bash. Git runs the hooks with its bundled bash on every platform.

## Claude Code

The project settings in `.claude/settings.json` disable commit and PR attribution, allow the routine commands, and add these hooks:

- PreToolUse: blocks edits to Flyway migrations and Room schema JSON files that are already tracked by git.
- Stop: when `server/src` or `android/` has uncommitted changes, runs `./gradlew test` (server) or `./gradlew testDebugUnitTest` (android) and sends failures back to Claude.

## Conventions

See [AGENTS.md](../AGENTS.md) and `.claude/rules/commits-and-prs.md`. In short: code, commits, README, docs and issues are in English, and commits follow [Conventional Commits](https://www.conventionalcommits.org/).
