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

## Conventions

- Code, commits, README, docs and issues are written in English.
- Commits follow [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `chore:`, `docs:`...).
