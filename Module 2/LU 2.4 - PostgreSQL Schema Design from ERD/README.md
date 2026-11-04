# Helpdesk Schema Repair

Fixes `migrations/001_initial_schema.sql` so it matches the Helpdesk ER diagram.

## Run the tests

Needs PostgreSQL, pgTAP, and `pg_prove`.

```bash
npm run db:reset
psql -d helpdesk_test -c 'CREATE EXTENSION IF NOT EXISTS pgtap;'
npm test
```

## ERD-to-Schema Decisions

### Decision 1: Column type for timestamps
ERD said: `created_at`, `resolved_at`, `deactivated_at`, and `added_at` are `timestamp`.
Schema decided: `TIMESTAMPTZ` for all of them, not `TIMESTAMP`.
Reason: A plain `TIMESTAMP` stores a clock reading with no time zone, so nobody can tell which moment it means. `TIMESTAMPTZ` stores the exact moment, so agents and customers in different time zones see correct times, and the gap between `created_at` and `resolved_at` is reliable.

### Decision 2: ON DELETE for the two Agent links on Ticket
ERD said: `created_by` is required and `assignee_id` is optional. It says nothing about what happens when the agent is deleted.
Schema decided: `created_by` uses `ON DELETE RESTRICT`, and `assignee_id` uses `ON DELETE SET NULL`.
Reason: `created_by` is an audit record, so the database refuses to lose who filed the ticket. `assignee_id` is only the current owner, so if that agent is deleted, the ticket stays open and becomes unassigned for someone else to pick up.

### Decision 3: Default value for ticket status
ERD said: `status` is one of `open|pending|resolved|closed`. It does not say what a new ticket starts as.
Schema decided: `status TEXT NOT NULL CHECK (...) DEFAULT 'open'`.
Reason: If the starting state lives only in application code, a script or a direct insert can skip it. A schema default makes every new ticket start as `open`, however the row is created.

## Rejected Table Shape

### Shape: `tickets.tags TEXT[]` (tags stored as an array on the ticket)
What it was: A `tags` array column on `tickets`, with each tag stored as plain words inside the ticket row.
Why rejected: Ticket to Tag is a many-to-many relationship, and an array does not resolve it. A tag in an array has no ID, so it cannot have its own `color_hex` or belong to an organization, and the array cannot record who added the tag or when. `tags` and `ticket_tags` hold all of this.
What would break: Renaming a tag would mean rewriting every ticket that uses it, and spellings like "Billing" and "billing" would silently become two tags. A foreign key cannot reach inside an array, so nothing could check that a tag exists.
