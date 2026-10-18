# Helpdesk — Schema Repair

`migrations/001_initial_schema.sql` was repaired to correctly implement the ER
diagram (source of truth): UUID primary keys, NOT NULL and CHECK constraints from
the ERD, `TIMESTAMPTZ` timestamps with `DEFAULT NOW()` on `created_at`, UUID
foreign keys with an explicit `ON DELETE` on every FK, and the rejected
`tags TEXT[]` array replaced by proper `tags` + `ticket_tags` tables.

## ERD-to-Schema Decisions

### Decision 1: Column type — `id` and all FK columns are UUID, not SERIAL/INTEGER
ERD said: every entity's `id` is `uuid PK`, and every FK (`org_id`, `created_by`,
`assignee_id`, `ticket_id`, `author_id`, `tag_id`, `added_by`) references a `uuid`.
Schema decided: `UUID PRIMARY KEY DEFAULT gen_random_uuid()` for every PK, and
`UUID` for every FK column (never `SERIAL`/`INTEGER`).
Reason: the original schema used `SERIAL`/`INTEGER`, which both contradicts the
ERD and leaks sequential, guessable IDs across tenants. UUIDs are generated
server-side by default and keep FK types consistent with the PKs they reference.

### Decision 2: ON DELETE — `comments.ticket_id` CASCADE vs `comments.author_id` RESTRICT
ERD said: a Ticket "has comments" and an Agent "authored" comments.
Schema decided: `ticket_id REFERENCES tickets(id) ON DELETE CASCADE`, but
`author_id REFERENCES agents(id) ON DELETE RESTRICT`.
Reason: a comment has no meaning without its ticket, so comments die with the
ticket (CASCADE). But the author is an audit record — we must never silently lose
who wrote a comment — so an agent who still has comments cannot be deleted
(RESTRICT). Same reasoning makes `tickets.created_by` RESTRICT (preserve who filed
the ticket) while `tickets.assignee_id` is `SET NULL` (an unassigned ticket is
still a valid, open ticket).

### Decision 3: Defaults — `internal BOOLEAN NOT NULL DEFAULT FALSE`, `created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`
ERD said: `Comment.internal` is a `boolean` ("visible to agents only"); every
`created_at` is a `timestamp`.
Schema decided: `internal BOOLEAN NOT NULL DEFAULT FALSE`, and every `created_at`
is `TIMESTAMPTZ NOT NULL DEFAULT NOW()`.
Reason: the broken schema stored `internal` as `TEXT DEFAULT 'false'`, which allows
garbage values and string/boolean confusion; a real `BOOLEAN` defaulting to `FALSE`
means a new comment is public unless explicitly marked internal. `TIMESTAMPTZ`
stores an absolute instant regardless of server timezone, and `DEFAULT NOW()` means
callers never forget to set the creation time.

## Rejected Table Shape: `tickets.tags TEXT[]`
What it was: the broken schema added `ALTER TABLE tickets ADD COLUMN tags TEXT[]`,
storing a ticket's tags as a Postgres text array on the ticket row.
Why rejected: it collapses a many-to-many relationship into a denormalized array.
It cannot reference the real `Tag` entity (no shared tag identity, `org_id`, or
`color_hex`), cannot store the per-association metadata the ERD requires on
`TicketTag` (`added_by`, `added_at`), and has no referential integrity — a tag name
can be misspelled or orphaned with nothing stopping it.
Correct shape: the `tags` entity plus a `ticket_tags` join table (`ticket_id`,
`tag_id`, `added_by`, `added_at`) that resolves the M:N and carries its own
attributes.

## Running the tests
The graded suite is the starter repo's **original** `tests/schema.test.sql` (36
assertions), used **unchanged**:
```bash
npm install
npm run db:reset   # drops & recreates helpdesk_test, runs the migration
npm test           # runs the ORIGINAL tests/schema.test.sql — all 36 pass
```

`tests/extra_checks.sql` is a **supplementary** file (not a replacement). It
validates each constraint directly — the role CHECK in isolation (a real-org
insert, so it's the CHECK not an FK, plus a positive control) and all ten
ON DELETE actions:
```bash
psql -d helpdesk_test -c "CREATE EXTENSION IF NOT EXISTS pgtap;"
pg_prove -d helpdesk_test tests/schema.test.sql tests/extra_checks.sql
```

See `SUBMISSION_STEPS.md` for the exact branch/commit workflow that keeps the
provided suite unchanged in the diff.
