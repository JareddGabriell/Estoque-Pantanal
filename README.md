# Beverage Inventory

Offline-first beverage inventory app for restaurants.

The manager registers suppliers and products, each with a minimum and a target stock level. Staff count the stock with the Android app, which keeps working without a connection. From the counts, the app builds a suggested order for each supplier and sends it through WhatsApp.

## Structure

| Folder | Contents |
|---|---|
| `android/` | Android app (Kotlin, Jetpack Compose, Room, WorkManager) |
| `server/` | API (Quarkus, Java 25, PostgreSQL, Flyway) |
| `infra/` | Docker Compose and backup scripts |
| `docs/` | Decisions, roadmap and development environment |

## Running locally

Prerequisites: Docker, JDK 25 and Android Studio.

1. Copy `infra/.env.example` to `infra/.env` and set the passwords.
2. Start the database:
   ```bash
   docker compose -f infra/docker-compose.yml up -d
   ```
3. Run the API from `server/` with `./mvnw quarkus:dev`, then check that `http://localhost:8080/q/health` responds.
4. Open `android/` in Android Studio and run the app on the emulator. From the emulator, the API is reachable at `http://10.0.2.2:8080`.

## Secrets

Never commit the signing keystore, `.env` files, `local.properties` or any real restaurant data. In CI, these live in GitHub Actions secrets.

## Documentation

- [Decisions and roadmap](docs/decisions-and-roadmap.md)
- [Development environment](docs/dev-environment.md)
