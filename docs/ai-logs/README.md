# AI conversation logs

The whole service was built in a single Cursor session (Plan mode, then Agent mode, with Claude Opus 5.5). This folder contains the raw log of that session and a guide to the decisions I made during it.

| File | What it is |
|---|---|
| [`2026-10-31-cursor-session-59ca622e.jsonl`](2026-10-31-cursor-session-59ca622e.jsonl) | The raw, unedited transcript as Cursor exported it (byte-for-byte copy) |
| [`2026-10-31-cursor-session-59ca622e.md`](2026-10-31-cursor-session-59ca622e.md) | The same transcript rendered as Markdown, with nothing reworded or removed. My prompts are block-quoted as "User prompt N"; tool calls are collapsed |

To regenerate the Markdown: `ruby script/render_ai_log.rb docs/ai-logs/<file>.jsonl > docs/ai-logs/<file>.md`

**What the export doesn't contain.** It records every user and assistant message and every tool call the agent made, but not:
- tool outputs;
- my answers to the agent's multiple-choice questions;
- the one message I sent while a command was still running.

I've written those down from the session in the decision log below. The transcript was copied when I asked for the AI logs (prompt 5), so that prompt is the last one included.

## My questions and decisions

### 1. Repository setup (prompt 1)
- I had the agent initialize the git repo and set the repo-local author to `iurii untilov` / `iura1981@gmail.com`.

### 2. Requirements I added on top of the PDF (prompt 2)
I asked the agent to analyze the PDF and extend it with these requirements before writing any code:
- **Architecture:**
  - Ruby, as a REST API. The agent was to recommend a widely used framework that supports database transactions for financial operations.
  - PostgreSQL, delivered with Docker and Docker Compose.
  - Code split by layer: routing and controllers, business logic, data access, validation, utilities.
- **Security:** nobody may make financial operations without authorization, and authorization must be tied to the payer.
- **Database:** the schema and initial data are migrations kept in code.
- **Testing:** always add unit tests, especially around financial operations.
- **Logging:** the framework's standard logger, with different log levels.
- **Error handling, beyond the spec:**
  - validation failures return 4xx;
  - authorization failures return the matching status;
  - server errors return 5xx, with no details in the response, logged in the service.
- **AI rules:** a rules file; prefer commonly used libraries; concise, clear code without unnecessary comments.
- **My open question:** the spec emphasizes *"Assume the server runs as multiple load-balanced instances."* I asked how this affects the solution and what my own requirements didn't already cover. The agent's answer is section 2 of the [implementation plan](../plans/bulk-payments-implementation-plan.md): row locks with a consistent lock order, persisted idempotency keys, stateless auth, migrations run once, and request-id log correlation.

### 3. Design decisions I made when the agent asked
The agent asked three questions before writing the plan. My answers aren't in the export:

| Question | Options offered | My decision |
|---|---|---|
| How does a caller prove it acts for the payer firm? | Per-firm API key, or JWT | **Per-firm API key**: a Bearer token stored hashed, which must match `payer_firm_uuid` |
| Which multi-instance extras are in scope besides row locking and transactions? | Idempotency keys, an nginx multi-replica demo, concurrency tests | **Only idempotency keys.** I left the nginx demo and the concurrency tests out of scope; the README lists them as improvements |
| Status code for payload validation errors? | 400 for malformed JSON and 422 for invalid fields (the agent's recommendation and Rails convention), or 400 for everything | **400 for all validation errors**, keeping 422 only for business denials (insufficient funds, unknown payee). I overrode the agent's recommendation here |

The agent recommended Rails 8 in API-only mode as the framework, and I accepted it. I also accepted its proposed assumptions: amounts in integer cents, `bigint` money columns and the request limits. All of these are listed in the main README.

### 4. Go-ahead (prompt 3)
- *"save the plan into docs/plans and implement it."* The plan I approved is in [`docs/plans/`](../plans/bulk-payments-implementation-plan.md).

### 5. I stopped the agent from reading my keychain
- Docker builds failed behind my corporate TLS-inspecting proxy. To fix it, the agent tried to read the proxy's root CA certificate from the macOS system keychain without asking.
- I interrupted it and asked: ***"why you try to read keychain?"*** This message isn't in the export, because it cut off a running command.
- The agent explained that it wanted only the public CA certificate, and that it should have asked first. It then offered three alternatives.
- **My decision:** *"i will provide certificate, then use option A"*. I exported the certificate myself into `certs/`, and the agent wired it into the Docker build without committing it (`certs/*` is git-ignored).

### 6. Actions I explicitly approved
During implementation (prompt 4, *"added"*), Cursor's auto-review blocked several commands, and each one needed my approval:
- **`docker compose down -v`.** I approved it to reset the database after the agent found that Rails 8.1 loads `schema.rb` instead of running the seed-data migration.
- **The manual concurrency check** with the demo API tokens: parallel overdraft attempts and crossing payments. I approved it.
- **Reading Cursor's transcript folder.** This was blocked and deferred until I asked for the AI logs myself (prompt 5).

### 7. AI logs (prompt 5)
- *"add ai-logs as per readme, empasise on my questions and decisoins"*. This produced this folder: the raw log kept unedited, plus this decision summary.
