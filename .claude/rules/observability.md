# Observability

## Log levels

| Level | Use it for | Example |
|---|---|---|
| `ERROR` | A failure that needs human action, and the request or job could not complete | Database unreachable, migration failed at startup |
| `WARN` | Something unexpected that the system handled, but that may need attention if it repeats | Sync batch rejected an item for a permission error, refresh token reused |
| `INFO` | Business events and lifecycle, at most a few lines per request | Server started, sync push applied N items for device D |
| `DEBUG` | Detail for diagnosing one problem locally. Off in production | Cursor values, per-item decisions in a batch |
| `TRACE` | Not used | |

## Rules

- MUST log with the framework logger (JBoss Logging in Quarkus, a wrapper around `android.util.Log` that is disabled in release builds on Android). NEVER use `System.out`, `printStackTrace()` or `println`.
- MUST identify entities by their public ids only (client UUIDs, device id, request id). NEVER log names, logins, phone numbers, notes or tokens (see `security.md`).
- NEVER log `getMessage()` of a database exception (`SQLException`, `PersistenceException`, `ConstraintViolationException` from Hibernate). These messages can contain the SQL and the bound values. Log the exception class, the SQL state or constraint name, and a public id.
- MUST log an exception once, where it is handled. NEVER log it and rethrow it.
- MUST attach the exception as the throwable argument when logging an error, not as text in the message.
- MUST write log messages in English, as one line, with stable wording that can be searched.
- MUST give every HTTP request a request id, return it in a response header, and include it in problem details, so that a staff member's error screen can be matched to a server log line.

## Health

- MUST keep `/q/health` reporting the database connection. NEVER add checks to it that call external services.
