# AI Agent Rules

Rules for any AI assistant (Cursor, Claude Code, Copilot, etc.) working in this repository.

## Stack
- Ruby 3.4, Rails 8 (API-only), PostgreSQL 16, RSpec, Docker Compose.
- Prefer commonly used, well-maintained libraries. Do not add a gem when Rails or the standard library already covers the need.
- Run all tooling inside Docker (`docker compose run --rm test ...`); do not rely on the host Ruby.

## Code style
- Concise, clear code. No comments that restate the code; comment only constraints the code cannot express.
- Follow `rubocop-rails-omakase` (`bin/rubocop`).
- Small single-purpose classes with a `.call` entry point for services.

## Layers (keep the boundaries)
- `config/routes.rb` + `app/controllers`: HTTP only (auth, parsing, rendering). No business logic, no direct SQL.
- `app/validators`: request payload contracts (dry-validation).
- `app/services`: business logic and transaction boundaries.
- `app/repositories`: all data access and locking queries. Services never build queries on models directly.
- `app/models`: ActiveRecord mappings and associations only.
- `app/serializers`: response bodies.
- `app/errors`: `AppError` subclasses; each carries its HTTP status and error code.
- `app/utils`: stateless helpers (money conversion, tokens).

## Money and concurrency
- Money is always integer cents (`bigint`). Never use floats; parse amounts with `Money.to_cents`.
- Every balance change goes through `Payments::CreateBulkPayment`: one DB transaction, all involved firm rows locked with `SELECT ... ORDER BY id FOR UPDATE`, balances re-checked after locking.
- The service runs as multiple instances: never rely on in-process state (mutexes, memory caches) for correctness.
- Database constraints (CHECK, FK, unique) are the last line of defense; keep them in migrations.

## Database
- Schema and reference data changes are migrations only (`db/migrate`). Never edit an applied migration.

## Errors and logging
- Client errors are 4xx with a stable `error.code`; server errors are 5xx with a generic message. Never leak exception details, SQL or stack traces in responses.
- Use `Rails.logger` with proper levels: `debug` details, `info` business events, `warn` denied/invalid requests, `error` unexpected failures (with backtrace).
- Never log secrets (API tokens, Authorization header).

## Testing
- Every change needs specs; money paths (parsing, debit/credit, rollback, idempotency) need unit specs covering edge cases.
- Run `docker compose run --rm test` before committing; the suite must be green.

## Git
- Small, logical commits with imperative messages.
