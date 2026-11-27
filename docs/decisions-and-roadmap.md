# Decisions and roadmap

## Context
The restaurant tracks its beverage stock by hand, in a WhatsApp list split by supplier. This app replaces that list. The manager registers suppliers and products, and the staff count the stock on their phones. The restaurant's existing point-of-sale (POS) system stays as it is.

## Feasibility
- **Distribution:** the app is not published on the Play Store. Signed APKs go to GitHub Releases and are installed by invitation through a limited-distribution account in the Android Developer Console (up to 20 devices). Since 30 Sep 2026, Brazil requires a verified developer even for apps installed outside the store.
- **Persistence:** data lives on a server with an automatic daily backup, stored on a different medium.
- **Offline:** Wi-Fi drops in the stock room, so the app is native and offline-first. Changes are queued and sent once the connection is back.
- **WhatsApp:** the app opens a `wa.me` link with the order text already filled in. It does not use the WhatsApp API.

## Decisions
- **App:** Kotlin, Jetpack Compose, Room (source of truth for the UI), WorkManager (sends the queue), Hilt and DataStore.
- **Backend:** Quarkus (Java 25), PostgreSQL and Flyway, packaged with Docker Compose. The preferred deployment is a local server at the restaurant, backed up off-site.
- **Sync:**
  - The app generates UUIDs, and the server drops duplicate submissions.
  - Endpoints: `POST /sync/push` and `GET /sync/pull?since=`.
  - Deletions are soft deletes (`deleted_at`).
  - Counts are append-only and are never overwritten.
- **Authentication:**
  - The login screen is the same for everyone. The user's role (manager or staff) defines their permissions.
  - Sessions use JWT. Each device needs a connection for its first login.
- **Monorepo:** `android/`, `server/`, `infra/`, `docs/` and `.github/workflows/`.

## Stock rules
- **Per product:**
  - Minimum stock: when a count reaches it, the product raises an alert.
  - Target stock: the level an order brings the product back up to.
  - Package type and units per package.
- **Counting** is always done in units.
- **Suggested order:**
  - Quantity: target − counted, rounded up to whole packages.
  - Items are grouped by supplier.

## Data model (draft)
- **Supplier:** id, name, whatsapp, notes, updated_at, deleted_at
- **Product:** id, supplier_id, sku, name, description, unit, package, units_per_package, min_stock, target_stock, updated_at, deleted_at
- **Count:** id, supplier_id, user_id, counted_at
- **CountItem:** id, count_id, product_id, quantity, notes
- **User:** id, login, password_hash, name, role, active

## Roadmap
1. Inventory MVP with manual counts.
2. Automatic stock deduction from the sales recorded at the POS.
3. Waiter app.
4. Further POS integrations, if the vendor provides an official interface.
