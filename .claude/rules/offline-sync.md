# Offline sync

This is the most important rule set in the project. Staff count stock in a stock room with unreliable Wi-Fi, so every count has to survive a lost connection, a retry and an app restart. Treat any change that touches sync the way other projects treat tenant isolation.

## Local data (Android)

- MUST treat Room as the only source of truth for the UI. Screens observe Room through the ViewModel.
- NEVER read from the network straight into a screen. Network results are written to Room, and the UI picks them up from there.
- MUST write every user change to Room and to the local outbox in the same Room transaction.
- MUST send the outbox from WorkManager with a network constraint and exponential backoff. NEVER send it from a ViewModel or a coroutine tied to a screen.
- MUST keep an outbox entry until the server acknowledges it, and delete it only after the acknowledgement.
- MUST keep pending outbox entries across process death and reboot. That is why the outbox lives in Room and not in memory.

## Identity and idempotency

- MUST generate every entity id on the client as a UUID, before the first write.
- NEVER let the server assign ids to synced entities, and NEVER reuse an id.
- MUST make `POST /sync/push` idempotent: resending the same batch, completely or partially, never duplicates or changes data that was already applied.
- MUST design every push handler for at-least-once delivery. A batch can arrive twice, out of order, or after a later batch.

## Data rules

- Counts (`Count`, `CountItem`) are append-only. NEVER update or overwrite a count. A correction is a new count.
- Deletes are soft deletes: set `deleted_at`. NEVER physically delete a synced row, because other devices still need to learn about the delete through pull.
- Catalog edits (suppliers and products, manager only) use last-write-wins by `updated_at`. MUST compare `updated_at` on the server and ignore an incoming version that is older than the stored one.
- MUST let the server decide permissions on every pushed change. A staff device that pushes a catalog edit is rejected per item, and the rest of the batch still applies.

## Protocol

- Endpoints: `POST /sync/push` and `GET /sync/pull?since=<cursor>`.
- The cursor is opaque to the client. The client stores the last cursor it got and sends it back unchanged.
- MUST include soft-deleted rows in pull results, so that deletes propagate.
- MUST make pull pages deterministic, ordered by the server's change sequence and not by wall-clock time on the device.
- MUST version breaking changes to the push or pull payloads. Old app builds stay installed on phones for a while.

## Auth

- JWT access token plus a rotating refresh token.
- The first login on each device needs a connection. After that, the app works offline with the cached session until the refresh token expires.
- NEVER drop unsent outbox entries on logout or token expiry. They are sent after the next successful login.

## Testing

- MUST cover push idempotency, resend of a partial batch and out-of-order delivery with integration tests against real PostgreSQL. NEVER test sync with a mocked database.
- MUST test the outbox with `work-testing` and an in-memory Room database.
- LANDMINE: a test that only checks the happy path of sync proves nothing. Every sync change needs at least one resend or out-of-order case.
