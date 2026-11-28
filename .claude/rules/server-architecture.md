---
paths:
  - "server/**"
---

# Server architecture

Applies to everything under `server/`. Stack: Quarkus 4.0.x, Java 25, Gradle Kotlin DSL, PostgreSQL 18, Flyway.

## Schema

- MUST make Flyway the only owner of the database schema. Migrations live in `server/src/main/resources/db/migration/` and are named `V<version>__<description>.sql`.
- MUST set `quarkus.hibernate-orm.schema-management.strategy=none` in every profile. NEVER let Hibernate create, update or validate the schema by generating DDL.
- NEVER edit, rename or delete a migration once it is merged. Fix a mistake with a new migration. A Claude Code hook blocks edits to migrations that exist in `origin/main`. On a feature branch, a migration that is not merged yet can still be edited.
- MUST make every migration safe to run on a database with real data. Backfill in the migration, and add `NOT NULL` only after the backfill.
- LANDMINE: Quarkus 4 removed `quarkus.hibernate-orm.database.generation`. Use `schema-management.strategy`.
- LANDMINE: the Hibernate ORM dialect in Quarkus 4 targets PostgreSQL 16 or later by default. Set `quarkus.datasource.db-version` if you ever have to run against an older server.

## Layers

- Resource (JAX-RS): HTTP only. It maps DTOs and calls one service method. No business logic, no transactions.
- Service: orchestration and business rules. It calls repositories and domain code.
- Repository: data access. The repository owns the transaction (`@Transactional` on repository methods), and the service owns the orchestration.
- MUST keep pure business rules (order math, last-write-wins comparison) in plain Java classes with no Quarkus, JPA or CDI dependency, so they can be unit-tested and mutation-tested.
- NEVER call a repository from a resource.

## API contract

- MUST use DTOs (Java records) for every request and response. NEVER return a JPA entity or a Panache entity from a resource.
- MUST validate input with Bean Validation (`@Valid` on the parameter, constraints on the DTO).
- MUST return errors as RFC 7807 problem details (`application/problem+json`, with `type`, `title`, `status`, `detail` and `instance`). RFC 9457 replaces RFC 7807 and keeps the same format.
- MUST map exceptions to problem details in one place (`ExceptionMapper`). NEVER let a stack trace or a database message reach the response.
- MUST expose only public identifiers (client UUIDs) in URLs and payloads. NEVER expose internal sequence ids.
- LANDMINE: Quarkus 4 uses Jackson 3, whose packages moved from `com.fasterxml.jackson.databind` to `tools.jackson.databind`. Check imports when you copy examples written for Quarkus 3.

## Auth

- MUST read the JWT only from the `Authorization: Bearer <token>` header. NEVER accept a token from a query parameter, a cookie or the request body.
- MUST declare the role on every endpoint (`@RolesAllowed`, `@PermitAll`, `@Authenticated`). NEVER leave an endpoint without an explicit access rule.
- MUST enforce manager-only operations on the server, even when the app already hides them.

## Sync

- MUST follow `offline-sync.md` for `/sync/push` and `/sync/pull`.

## Configuration

- MUST read secrets from the environment or a vault, and fail at startup when a required one is missing (see `security.md`).
- NEVER put real credentials in `application.properties`, even for the dev profile. Use Dev Services in dev and test.
