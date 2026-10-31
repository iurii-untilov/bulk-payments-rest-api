# Bulk Payments Service

A REST API that lets a firm pay many other firms in one request. The whole batch is accepted (`201`) or the whole batch is denied (`422`); money never moves partially, and concurrent requests hitting different load-balanced instances cannot overdraw a balance.

Stack: Ruby 3.4, Rails 8.1 (API-only), PostgreSQL 16, RSpec, Docker Compose.

## How to run and verify

Requirements: Docker with Compose v2.

```bash
docker compose up --build -d api        # builds the image, runs migrations once, starts the API on :3000
docker compose run --rm test            # runs the RSpec suite against a separate test database
```

The `migrate` container creates the schema and seeds the three firms from the specification (plus one demo API key per firm), then exits; `api` starts only after it succeeds.

Send the sample request (Pinecrest pays Nair and Lopez):

```bash
curl -i -X POST http://localhost:3000/api/v1/bulk_payments \
  -H "Authorization: Bearer bp_demo_pinecrest_0ab992762cb5ac80503d0cd511fccca3" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: sample-1" \
  -d '{
    "payer_firm_uuid": "3f1c9a2e-7b4d-4c1e-9a55-2d8e6f0b7c41",
    "payments": [
      { "amount": "6250",    "payee_firm_uuid": "e5f18b3c-2a9d-4c07-8e6b-1d4a7f9c3b25", "description": "Overflow returns, August 2026" },
      { "amount": "5800.5",  "payee_firm_uuid": "e5f18b3c-2a9d-4c07-8e6b-1d4a7f9c3b25", "description": "Amended returns, August 2026" },
      { "amount": "1200.75", "payee_firm_uuid": "8b2e4c71-0d3a-4f6e-b1c9-5a7d2e9f4c10", "description": "Bookkeeping cleanup, 3 clients" }
    ]
  }'
```

Check balances:

```bash
docker compose exec db psql -U bulk_payments -d bulk_payments_production -c "SELECT id, name, balance_cents FROM firms ORDER BY id"
```

Expected after the first request: Pinecrest `3674875`, Lopez `170075`, Nair `1405050`. Repeating the request with the same `Idempotency-Key` replays the stored `201` without moving money again. Each repeat with a new key (or no key) pays again, and the fourth batch is denied with `422 insufficient_funds`, because only $10,246.25 is left.

Start over with a fresh database: `docker compose down -v`.

### Demo API keys (development only)

| Firm | UUID | Token |
|---|---|---|
| Pinecrest CPA Group | `3f1c9a2e-7b4d-4c1e-9a55-2d8e6f0b7c41` | `bp_demo_pinecrest_0ab992762cb5ac80503d0cd511fccca3` |
| Lopez Bookkeeping | `8b2e4c71-0d3a-4f6e-b1c9-5a7d2e9f4c10` | `bp_demo_lopez_114eb19faba08e6b01ea46eefe4dbb8f` |
| Nair Tax Services | `e5f18b3c-2a9d-4c07-8e6b-1d4a7f9c3b25` | `bp_demo_nair_4e3611ceeb76395e5ef02b2a8b1f51bf` |

Only SHA-256 digests are stored in the database. Generate a real key with `docker compose run --rm api ./bin/rails 'api_keys:generate[FIRM_UUID]'` (the token is printed once).

### Behind a TLS-inspecting corporate proxy

If `bundle install` fails during the build with `certificate verify failed`, put the proxy's root CA (PEM) into `certs/<name>.crt`. The Dockerfile adds every `certs/*.crt` to the container trust store; the folder is git-ignored.

## API

`POST /api/v1/bulk_payments`

Headers: `Authorization: Bearer <token>` (required), `Content-Type: application/json`, `Idempotency-Key: <1-255 printable ASCII chars>` (optional, recommended).

`201 Created`:

```json
{
  "payer_firm_uuid": "3f1c9a2e-7b4d-4c1e-9a55-2d8e6f0b7c41",
  "payer_balance": "36748.75",
  "payments": [
    { "id": 1, "payee_firm_uuid": "e5f18b3c-...", "amount": "6250.00", "description": "Overflow returns, August 2026" }
  ]
}
```

Errors always have the shape `{ "error": { "code", "message", "details"?, "request_id" } }`:

| Status | `code` | When |
|---|---|---|
| 400 | `malformed_request` | Body is not valid JSON |
| 400 | `validation_failed` | Payload or `Idempotency-Key` invalid; `details` lists errors per field and payment index |
| 401 | `unauthorized` | Missing, unknown or revoked API key |
| 403 | `forbidden` | The key belongs to a different firm than `payer_firm_uuid` |
| 409 | `idempotency_key_conflict` | Key reused with a different payload |
| 422 | `insufficient_funds` | Payer cannot cover the total (`details`: required / available) |
| 422 | `unknown_payee` | A payee firm does not exist (`details`: the uuids) |
| 503 | `service_unavailable` | Row locks not acquired within 5s; safe to retry |
| 500 | `internal_error` | Anything unexpected; no internals leaked, full error logged with the `request_id` |

`GET /up` is the health check for the load balancer.

## Solution and approach

### Request flow

1. **Authenticate** (`Authenticatable` concern): the bearer token is hashed and looked up among active keys, which yields the calling firm.
2. **Validate** (`BulkPaymentContract`, dry-validation): structure, types, amount format, limits, no self-payment.
3. **Authorize**: `payer_firm_uuid` must be the authenticated firm.
4. **Idempotency** (`Idempotency::Execute`): if the key was seen, replay the stored response, or return 409 if the payload differs.
5. **Pay** (`Payments::CreateBulkPayment`), in one transaction:
   - `SET LOCAL lock_timeout = '5s'`
   - `SELECT ... FROM firms WHERE uuid IN (payer, payees...) ORDER BY id FOR UPDATE`
   - every payee must exist, and the payer's locked balance must cover the total
   - debit the payer (`UPDATE ... WHERE balance_cents >= total`), credit each payee by its summed amount, bulk-insert the payments
   - store the idempotency key and response in the same transaction, then commit.

Any denial raises before commit, so the whole batch rolls back.

### Code layout

```
config/routes.rb                  routing
app/controllers                   HTTP: auth concern, controller, central error mapping
app/validators                    request contract (dry-validation)
app/services                      business logic and transaction boundaries
app/repositories                  data access and locking queries
app/models                        ActiveRecord mappings
app/serializers                   response bodies
app/errors                        AppError hierarchy (status + code per error)
app/utils                         Money (string <-> cents), ApiToken (generate / digest)
db/migrate                        schema and seed data
spec/                             unit specs per layer + request specs
```

### Multiple load-balanced instances

The spec stresses that several instances serve traffic. This drives most of the design:

- **No in-process state for correctness.** Mutexes or caches are per process and useless across instances; all coordination happens in PostgreSQL.
- **Overdraft race.** A transaction alone is not enough: at READ COMMITTED two requests could both read the same balance and both pass the check. Locking the payer row with `FOR UPDATE` serializes payments per payer across all instances; the balance is re-checked after the lock, the debit itself is conditional, and a `CHECK (balance_cents >= 0)` constraint is the last line of defense.
- **Deadlocks.** A pays B while B pays A would deadlock if each locked its own row first. All involved rows are locked in one statement ordered by `id`, so lock acquisition order is global. `lock_timeout` bounds waiting; lock timeouts and deadlocks return a retryable `503`.
- **Retries.** A client or load balancer retrying after a timeout may hit another instance. The `Idempotency-Key` is stored in the database with a unique `(firm_id, key)` index, in the same transaction as the payments, so the retry either replays the stored response or (if racing) loses on the unique index, rolls back, and replays the winner's response.
- **Stateless auth.** API keys are checked against the database on every request; there are no sessions.
- **Migrations run once** in a dedicated `migrate` container, not on every instance's boot.
- **Operations.** Logs go to stdout tagged with the request id (also returned as `X-Request-Id` and in error bodies), so a request can be traced across instances. Connection budget: `instances x RAILS_MAX_THREADS` must stay below Postgres `max_connections`.

I checked this manually against the running stack: 10 parallel $1,000 payments from Lopez (balance $4,102.25) gave exactly 4 × `201` and 6 × `422`, and 20 simultaneous crossing payments between Nair and Lopez all succeeded with no deadlocks. The total money in the system stayed constant.

### Security

- Per-firm API keys: high-entropy random tokens; only SHA-256 digests are stored; keys can be revoked (`revoked_at`).
- A key can only pay on behalf of its own firm (403 otherwise); payees are just identifiers.
- Authentication runs before the body is parsed; tokens and the Authorization header are filtered from logs.
- 5xx responses never contain exception details; Brakeman reports no warnings.
- `FORCE_SSL=true` enables HTTPS redirect / HSTS when deployed behind a TLS-terminating load balancer.

### Logging

Standard Rails tagged logger to stdout; level via `RAILS_LOG_LEVEL` (default `info` in production):

- `debug`: validation error details.
- `info`: accepted batches (payer id, count, total cents) and idempotent replays.
- `warn`: every 4xx with its code.
- `error`: 5xx and lock failures, with backtraces.

### Testing

`docker compose run --rm test` runs 98 examples covering:

- money parsing edge cases;
- the validation contract;
- API key authentication;
- the payment service: the spec's sample balances, spending the exact balance, rollback on insufficient funds, unknown payees and insert failures, ordered locking, and lock timeouts and deadlocks;
- idempotency: replay, conflict, per-firm scope, losing a concurrent race;
- repositories and database constraints;
- request specs for every status code, including a 500 that leaks nothing.

Lint and security: `bin/rubocop`, `bin/brakeman`.

## Assumptions

- **Amounts:** strings matching `^\d+(\.\d{1,2})?$`, greater than 0, at most $10,000,000,000,000. JSON numbers are rejected so they never pass through floats; amounts are converted with `BigDecimal` to integer cents.
- **Limits:** 1 to 1000 payments per request; descriptions are required, not blank and at most 1000 characters.
- **UUIDs:** must be lowercase canonical UUIDs, matching the format in the spec.
- **Payees:** the same payee may appear several times (the sample does). Paying yourself is a validation error (400).
- **Status codes:** an unknown payee denies the whole request with 422. Like insufficient funds, it's a business denial that needs the database, while 400 is reserved for problems detectable from the payload alone.
- **Column types:** money columns are `bigint`, not `INTEGER`, because 32-bit cents cap at about $21.4M. The uuid column stays `TEXT` as specified. Timestamps were added to the tables.
- **Idempotency:** the `Idempotency-Key` header is optional so the plain sample request works. Only successful responses are stored, so after a denial (for example insufficient funds) the same key can be retried once the balance is topped up.
- **Seed data:** the seed firms and demo keys are a migration, as required. The demo tokens are public in this README and must not reach a real environment.

## Issues I ran into

- **Rails 8.1** `db:migrate` **loads** `schema.rb` **on a fresh database** instead of running the migrations. That marks every migration as applied, so the seed-data migration was silently skipped and the API returned 401 for the demo keys. The fix is `schema_dump: false` for production in `config/database.yml`, which makes production always build the database from the migrations. The test database still loads `schema.rb`; tests create their own data with factories.
- **A corporate TLS-inspecting proxy** broke `gem`/`bundle` downloads inside containers. The proxy's root CA can be supplied through the git-ignored `certs/` folder.
- **The host only has Ruby 2.6**, so the app was generated and all tooling runs inside the `ruby:3.4` image.
- **Replayed responses list JSON keys in a different order** than the original response, because the body is stored as `jsonb`. The JSON is semantically identical.

## Possible improvements

- Automated concurrency tests: multi-threaded specs with non-transactional fixtures, covering parallel overdraft and crossing payments.
- A load-balancing demo with nginx and `docker compose up --scale api=3`.
- Rate limiting per firm, shared across instances (Redis or at the load balancer), and PgBouncer for the connection budget.
- An expiry and cleanup job for idempotency keys, and a "processing" state so concurrent duplicates get a fast `409` instead of waiting on locks.
- A `bulk_payments` batch table that payments reference, an audit/ledger table (double-entry) and a `GET` endpoint for payment history.
- Moving payee credits into one `UPDATE ... FROM (VALUES ...)` statement for very large batches.
- Structured JSON logs (for example lograge), metrics and tracing; OpenAPI documentation.
- Key management endpoints (rotate/revoke) and scoped permissions.

## How I worked (AI usage)

- **Cursor (Plan and Agent modes, Claude Opus 5.5)** was the only AI tool. I used it for all of the work in this repository:
  - analyzing the PDF requirements and extending them with my own;
  - asking clarifying design questions (auth method, multi-instance scope, status codes);
  - writing the implementation plan in `docs/plans/`;
  - scaffolding, code, tests and the Docker setup;
  - debugging the `schema.rb` seed issue;
  - this README.
- The requirements and key decisions came from me: the stack, the layering, security tied to the payer, the error-handling policy, the AI rules and the answers to the agent's design questions. The agent proposed the framework and other options, then implemented them.
- `AGENTS.md` contains the AI rules used during development.
- [`docs/ai-logs/`](docs/ai-logs/README.md) has the raw, unedited transcript (JSONL plus a verbatim Markdown rendering) and a log of my questions and decisions during the session.

## Two quick questions

**How much time did you spend on this task?** Less than 3h

**How proud are you of your work?** Good enough
