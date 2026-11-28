# Testing

## Strategy

| Layer | Server | Android |
|---|---|---|
| Unit | JUnit + AssertJ | JUnit + coroutines-test + Turbine + MockK + AssertK |
| Property | jqwik (order math, idempotency) | Kotest property or jqwik on `:core:domain`, whichever is supported |
| Integration | `@QuarkusTest` + RestAssured + Testcontainers (real PostgreSQL) | Room in-memory + `MigrationTestHelper`, `work-testing` |
| UI | n/a | Compose UI Test on Robolectric |
| Visual regression | n/a | Roborazzi |
| Contract | OpenAPI generated from code, diffed in CI | Consumes the same contract |
| E2E | n/a | Maestro on an emulator or a real phone |
| Mutation | PIT on domain classes | PIT on `:core:domain` |
| Coverage | JaCoCo (report only) | Kover (report only) |

Most of these tools are not set up yet. Phase 3 sets up the server layers and Phase 4 the Android ones. The quality bar in `AGENTS.md` shows what actually runs today.

## Rules

- Tests are written with AI assistance, and a human reviews every test. Mutation testing is the objective check that a test catches regressions. A mutant that survives in reviewed code is a finding.
- NEVER mock PostgreSQL to test SQL, migrations or sync. Use Testcontainers through Quarkus Dev Services.
- NEVER mock the domain itself. Mock only the edges: clock, network and platform services.
- MUST keep tests deterministic: inject the clock, use no real network, no `Thread.sleep` or `delay` to wait, and no dependence on test order.
- MUST use `runTest` and test dispatchers for coroutines, and Turbine for `Flow`.
- NEVER disable a flaky test without an open issue linked in the skip annotation. Fix the cause.
- NEVER write a test without a real assertion. A test that only checks "no exception" must say so in its name and assert on the outcome.
- NEVER lower a coverage or mutation threshold to make a build pass without a justification in the PR.
- MUST pass test credentials through helper parameters, never as literals next to a key name, so gitleaks stays useful.
- MUST cover every bug fix with a test that failed before the fix (see `tdd.md`).

## PIT

- MUST run PIT only on pure domain classes and their unit tests.
- LANDMINE: NEVER point PIT at `@QuarkusTest` classes. Quarkus restarts the application for every mutant, so a run takes hours.

## Thresholds

- Coverage (JaCoCo, Kover) and mutation scores start as `[measured]` once their reports exist. They become `[gate]` only when a CI job fails the build below a set threshold.
