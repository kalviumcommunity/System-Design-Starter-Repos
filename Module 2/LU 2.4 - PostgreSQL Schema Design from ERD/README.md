# Helpdesk — Schema Repair

The migration in `migrations/001_initial_schema.sql` was repaired to correctly
implement the ER diagram (source of truth): UUID primary keys, NOT NULL and
CHECK constraints from the ERD, `TIMESTAMPTZ` timestamps with `DEFAULT NOW()`
for `created_at`, UUID foreign keys, an explicit `ON DELETE` on every FK, and
the rejected `tags TEXT[]` array replaced by proper `tags` + `ticket_tags`
tables.

## ERD-to-Schema Decisions

### Decision 1: Column type — `id` and all FK columns are UUID, not SERIAL/INTEGER
ERD said: every entity's `id` is `uuid PK`, and every FK (`org_id`, `created_by`,
`assignee_id`, `ticket_id`, `author_id`, `tag_id`, `added_by`) references a `uuid`.
Schema decided: `UUID PRIMARY KEY DEFAULT gen_random_uuid()` for every PK, and
`UUID` for every FK column (never `SERIAL`/`INTEGER`).
Reason: the original schema used `SERIAL`/`INTEGER`, which both contradicts the
ERD and leaks sequential, guessable IDs across tenants. UUIDs are generated
server-side by default and keep FK types consistent with the PKs they reference,
so joins and references are type-correct.

### Decision 2: ON DELETE — `comments.ticket_id` CASCADE vs `comments.author_id` RESTRICT
ERD said: a Ticket "has comments" and an Agent "authored" comments.
Schema decided: `ticket_id REFERENCES tickets(id) ON DELETE CASCADE`, but
`author_id REFERENCES agents(id) ON DELETE RESTRICT`.
Reason: a comment has no meaning without its ticket, so comments should die with
the ticket (CASCADE). But the author is an audit record — we must never silently
lose who wrote a comment — so an agent who still has comments cannot be deleted
(RESTRICT). Same reasoning makes `tickets.created_by` RESTRICT (preserve who
filed the ticket) while `tickets.assignee_id` is `SET NULL` (an unassigned ticket
is still a valid, open ticket).

### Decision 3: Default value — `internal` is `BOOLEAN NOT NULL DEFAULT FALSE`, and `created_at` is `TIMESTAMPTZ NOT NULL DEFAULT NOW()`
ERD said: `Comment.internal` is a `boolean` ("visible to agents only"); every
`created_at` is a `timestamp`.
Schema decided: `internal BOOLEAN NOT NULL DEFAULT FALSE`, and every `created_at`
is `TIMESTAMPTZ NOT NULL DEFAULT NOW()`.
Reason: the broken schema stored `internal` as `TEXT DEFAULT 'false'`, which
allows garbage values and string/boolean confusion; a real `BOOLEAN` defaulting
to `FALSE` means a new comment is public unless explicitly marked internal.
`TIMESTAMPTZ` (not `TIMESTAMP`) stores an absolute instant regardless of server
timezone, and `DEFAULT NOW()` means callers never forget to set the creation time.

## Rejected Table Shape

### Shape: `tickets.tags TEXT[]` (tags as an array column on the ticket)
What it was: the broken schema added `ALTER TABLE tickets ADD COLUMN tags TEXT[]`,
storing a ticket's tags as a Postgres text array directly on the ticket row.
Why rejected: it collapses a many-to-many relationship into a denormalized array.
It cannot reference the real `Tag` entity (so there is no shared tag identity,
`org_id`, or `color_hex`), it cannot store per-association metadata the ERD
requires on `TicketTag` (`added_by`, `added_at`), and it has no referential
integrity — a tag name in the array can be misspelled or orphaned with nothing
stopping it.
What would break: renaming or deleting a tag can't propagate (you'd have to
rewrite every array), you can't answer "who tagged this ticket and when", you
can't enforce "a tag belongs to an org", and "find all tickets with tag X" turns
into array scans instead of an indexed join. The correct shape is the `tags`
entity plus a `ticket_tags` join table (`ticket_id`, `tag_id`, `added_by`,
`added_at`) that resolves the M:N and carries its own attributes.

## Running the tests
The graded suite is the starter repo's **original** `tests/schema.test.sql` (36
assertions), used unchanged:
```bash
npm install
npm run db:reset   # drops & recreates helpdesk_test, runs the migration
npm test           # runs the ORIGINAL tests/schema.test.sql — all must pass
```

`tests/extra_checks.sql` is a **supplementary** file (not a replacement). It
validates each constraint directly — the role CHECK in isolation (a real-org
insert, so it's the CHECK not an FK, plus a positive control) and all ten
ON DELETE actions:
```bash
pg_prove -d helpdesk_test tests/schema.test.sql tests/extra_checks.sql
```
See `tests/RESTORE_ORIGINAL_TESTS.md` if you need to restore the original suite.
