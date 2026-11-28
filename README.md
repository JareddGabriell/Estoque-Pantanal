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

### API

```bash
cd server
./gradlew quarkusDev
```

In dev mode, Quarkus Dev Services starts a throwaway PostgreSQL container automatically, so Docker must be running. Once the API is up, check:

- `http://localhost:8080/api/ping`: connectivity check used by the app
- `http://localhost:8080/q/health`: health check, including the database connection

### Android app

Open `android/` in Android Studio and run the `app` configuration. From the emulator, the API is reachable at `http://10.0.2.2:8080`.

### Persistent database (optional)

Dev Services drops the database every time the API restarts. To keep data between runs, start the PostgreSQL defined in `infra/`:

1. Copy `infra/.env.example` to `infra/.env` and set the passwords.
2. Start the database:
   ```bash
   docker compose -f infra/docker-compose.yml up -d
   ```

## Secrets

Never commit the signing keystore, `.env` files, `local.properties` or any real restaurant data. In CI, these live in GitHub Actions secrets.

## Documentation

- [Decisions and roadmap](docs/decisions-and-roadmap.md)
- [Development environment](docs/dev-environment.md)
