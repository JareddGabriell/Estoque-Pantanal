---
name: tdd
description: Test-driven development walkthrough for this repository (spec issue, red, green, refactor), with examples for the Quarkus server (@QuarkusTest, RestAssured, Testcontainers through Dev Services) and the Android app (Turbine, Robolectric, in-memory Room). Use it when implementing a feature or fixing a bug in server/ or android/.
---

# TDD walkthrough

Follow `.claude/rules/tdd.md`. This skill shows how each step looks in this codebase.

Some of the libraries used below are added in Phases 3 and 4 of the setup (`docs/testing/README.md` will list them). If a dependency is missing, stop and say so. Do not add it silently as part of a feature.

## Step 0: the spec

- Find the GitHub issue (`gh issue view <N>`). Work on one acceptance criterion at a time.
- If there is no issue, or the criteria cannot be tested as written, stop and ask the human. Do not invent criteria.
- Pick the lowest layer that proves the criterion: domain unit test, then integration test (SQL, sync, HTTP), then UI test.

## Step 1: red

Write one test, run it, and read the failure. It must fail **on an assertion about the missing behavior**. These are failures for the wrong reason:

- a compile error, unless it is about the single new class or method the test introduces and the test is otherwise complete
- a missing CDI bean, a Dev Services startup error or a missing Docker daemon
- a typo in the test data

Show the human the failing output before writing production code.

## Step 2: green

Write the least code that makes the test pass, run the whole affected test class, then the module's unit tests.

## Step 3: refactor

Improve names and structure with the tests green. Run the tests after each step. Do not change behavior.

## Bug fixes

Start with a test that reproduces the bug as reported, and confirm it fails the same way the bug shows up. Then fix it. Mention the issue in the test name or a comment (`// Regression test for #31`).

---

## Server examples (Quarkus 4, Java 25)

### Domain unit test (JUnit + AssertJ)

Suggested order rule: when the last count is at or below the minimum, order `target - counted`, rounded up to whole packages.

```java
package app.beverageinventory.order;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class SuggestedQuantityTest {

    @Test
    void roundsUpToWholePackages() {
        // min 10, target 24, counted 7, 6 units per package -> needs 17 -> 3 packages
        var quantity = SuggestedQuantity.packagesToOrder(7, 10, 24, 6);

        assertThat(quantity).isEqualTo(3);
    }

    @Test
    void ordersNothingAboveTheMinimum() {
        assertThat(SuggestedQuantity.packagesToOrder(11, 10, 24, 6)).isZero();
    }
}
```

Red: the first run fails because `packagesToOrder` returns a placeholder `0`, not because the class is missing. Create the method returning `0` first if needed, so the failure is on the assertion.

### Property test (jqwik)

```java
@Property
void neverOrdersLessThanTheGap(@ForAll @IntRange(min = 0, max = 500) int counted,
                               @ForAll @IntRange(min = 1, max = 48) int unitsPerPackage) {
    int min = 10, target = 24;
    Assume.that(counted <= min);

    int packages = SuggestedQuantity.packagesToOrder(counted, min, target, unitsPerPackage);

    assertThat(packages * unitsPerPackage).isGreaterThanOrEqualTo(target - counted);
    assertThat((packages - 1) * unitsPerPackage).isLessThan(target - counted);
}
```

### Integration test (@QuarkusTest + RestAssured + real PostgreSQL)

Quarkus Dev Services starts a PostgreSQL container through Testcontainers when no datasource URL is configured, and Flyway migrates it. Docker must be running. Never replace it with a mock or an in-memory database.

```java
package app.beverageinventory.sync;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

@QuarkusTest
class SyncPushIdempotencyTest {

    @Test
    void resendingTheSameBatchDoesNotDuplicateCounts() {
        String batch = SyncFixtures.pushBatchWithOneCount(); // client-generated UUIDs

        pushAs(TestUsers.staff(), batch).then().statusCode(200);
        pushAs(TestUsers.staff(), batch).then().statusCode(200);

        given().auth().oauth2(TestUsers.staff().accessToken())
            .when().get("/sync/pull?since=")
            .then().statusCode(200)
            .body("counts.size()", equalTo(1));
    }
}
```

Notes:

- The test artifact in Quarkus 4 is `io.quarkus:quarkus-junit` (formerly `quarkus-junit5`). `@QuarkusTest` is `io.quarkus.test.junit.QuarkusTest`.
- Credentials come from helpers (`TestUsers`), never as literals next to a key (secret scan).
- LANDMINE: never run PIT against `@QuarkusTest` classes. Quarkus restarts for every mutant.

---

## Android examples (Kotlin)

### ViewModel test (coroutines-test + Turbine + AssertK)

```kotlin
class CountViewModelTest {

    @get:Rule val mainDispatcher = MainDispatcherRule() // sets Dispatchers.Main to a TestDispatcher

    @Test
    fun `saving a count shows it as pending sync`() = runTest {
        val repository = FakeCountRepository() // fake at the edge, real domain
        val viewModel = CountViewModel(repository, FixedClock(Instant.parse("2026-01-10T10:00:00Z")))

        viewModel.uiState.test {
            assertThat(awaitItem().pendingSync).isEqualTo(0)

            viewModel.onSave(productId = PRODUCT_ID, quantity = 7)

            assertThat(awaitItem().pendingSync).isEqualTo(1)
            cancelAndIgnoreRemainingEvents()
        }
    }
}
```

No `delay` or `Thread.sleep`: virtual time from `runTest` and Turbine's `awaitItem()` do the waiting.

### Room in-memory DAO test (Robolectric)

```kotlin
@RunWith(RobolectricTestRunner::class)
class OutboxDaoTest {

    private lateinit var db: AppDatabase

    @Before
    fun setUp() {
        db = Room.inMemoryDatabaseBuilder(ApplicationProvider.getApplicationContext(), AppDatabase::class.java)
            .allowMainThreadQueries()
            .build()
    }

    @After
    fun tearDown() = db.close()

    @Test
    fun `saving a count writes the count and its outbox entry together`() = runTest {
        val count = aCount(id = UUID.fromString("0b6f6c1e-4a52-4a8e-9a0c-6d1f1f7c2a10"))

        db.countDao().saveWithOutbox(count)

        assertThat(db.countDao().all()).containsExactly(count)
        assertThat(db.outboxDao().pending().map { it.entityId }).containsExactly(count.id)
    }
}
```

### Migration test (MigrationTestHelper)

Each schema version bump gets a test that migrates from the previous exported schema and checks the data survived. The exported schema JSON files are tracked and must never be edited.

### Compose UI test on Robolectric

```kotlin
@RunWith(RobolectricTestRunner::class)
class CountScreenTest {

    @get:Rule val compose = createComposeRule()

    @Test
    fun `shows the pending sync badge`() {
        compose.setContent { CountScreen(state = CountUiState(pendingSync = 2), onSave = { _, _ -> }) }

        compose.onNodeWithText("2 pendentes").assertIsDisplayed()
    }
}
```

User-facing text comes from `strings.xml` in pt-BR. Tests may match on it, but resolve it with `getString` once the text has plurals or formatting.

## Done checklist

- Every acceptance criterion has a test that was seen failing for the right reason.
- The module's unit tests pass (the Stop hook runs them when `server/src` or `android/` changed).
- No `Thread.sleep`, real network or real clock in tests.
- The PR's "How to verify" section names the tests that prove each criterion.
