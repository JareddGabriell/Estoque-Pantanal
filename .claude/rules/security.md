# Security

The repository is public. Assume everything committed is read by strangers.

## Secrets

- NEVER commit secrets: keystores, `.env` files, `local.properties`, `keystore.properties`, JWT signing keys, database passwords or API tokens.
- MUST read secrets from environment variables or a vault, and make the application fail at startup when a required secret is missing. NEVER fall back to a default secret.
- MUST keep CI secrets in GitHub Actions secrets. NEVER echo them in a workflow step.
- MUST keep `infra/.env.example` free of real values. It documents the variable names only.
- MUST treat a secret that was committed, even if it was removed later, as leaked. Rotate it; deleting it from the history does not make it safe again.
- MUST run gitleaks with `.gitleaks.toml`. NEVER add broad allowlists. Silence a reviewed false positive with a line-level `gitleaks:allow` comment or a fingerprint in `.gitleaksignore`, and justify it in the PR.

## Logging and personal data

- NEVER log passwords, password hashes, JWTs, refresh tokens, `Authorization` headers or signing keys, not even at debug level.
- NEVER log personal data: names, logins, phone numbers (supplier WhatsApp numbers included) or free-text notes. Log public ids instead (see `observability.md`).
- NEVER put real restaurant data in the repository, test fixtures or screenshots. Use invented data.

## Passwords and sessions

- MUST hash passwords with a slow, salted algorithm made for passwords (bcrypt or Argon2id through a maintained library). NEVER use plain SHA or MD5, and NEVER store reversible passwords.
- MUST compare secrets in constant time.
- MUST keep access tokens short-lived and rotate the refresh token on every use. A refresh token that is reused after rotation revokes the whole token family.
- MUST store tokens on Android in app-private storage (DataStore), encrypted with a key from the Android Keystore. NEVER store them in plain SharedPreferences or on external storage.
- MUST allow cleartext HTTP only in debug builds, through `network_security_config`. Release builds use HTTPS only.

## Input

- MUST validate every input on the server, even when the app already validated it.
- MUST use parameterized queries. NEVER build SQL by concatenating strings.
