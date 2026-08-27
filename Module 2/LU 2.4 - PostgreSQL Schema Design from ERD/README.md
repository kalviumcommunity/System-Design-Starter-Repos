# Helpdesk Schema Repair — LU 2.4 Assignment

## What This Is

You are a backend engineer on the Helpdesk team. A colleague wrote the first draft of the PostgreSQL schema in `migrations/001_initial_schema.sql`. It had **intentional errors** — wrong column types, missing constraints, wrong ON DELETE behaviour, and a rejected table shape that should have never been there.

The job was to **fix the schema so it correctly implements the ER diagram** from the assignment question. The ER diagram is the source of truth. The repaired schema matches it exactly, and all 36 pgTAP tests in `tests/schema.test.sql` pass.

---

## ERD-to-Schema Decisions

### Decision 1: Column type decision (UUID PKs/FKs, TEXT over VARCHAR, TIMESTAMPTZ)
ERD said: every entity has a `uuid id PK`, string attributes are marked `string`/`text`, and every timestamp attribute is marked `timestamp`.
Schema decided: every primary key is `UUID PRIMARY KEY DEFAULT gen_random_uuid()` (via the `pgcrypto` extension), every FK column is `UUID` matching the type of the key it references, string attributes are `TEXT` (not `VARCHAR(n)`), and every timestamp column is `TIMESTAMPTZ` (not `TIMESTAMP`).
Reason: `SERIAL`/`INTEGER` keys leak information (row counts, ordering) and don't merge safely across services or regions — UUIDs generated at insert time avoid both problems. Postgres `TEXT` has no performance penalty versus `VARCHAR(n)` and the ERD never specified a length cap, so adding one would be an invented constraint not in the source of truth. `TIMESTAMPTZ` stores an absolute instant with timezone context; plain `TIMESTAMP` silently assumes "whatever timezone the server/session happens to be in," which causes real bugs the moment agents or organizations span more than one timezone.

### Decision 2: ON DELETE decision (RESTRICT for audit trails, CASCADE for dependents, SET NULL for optional links)
ERD said: the diagram only expresses *that* a relationship exists (e.g. `Agent ||--o{ Ticket : "created_by"`), not *what happens on delete* — that behaviour has to be inferred from the meaning of each relationship.
Schema decided: `agents.org_id`, `tickets.org_id`, `tickets.created_by`, and `comments.author_id` all use `ON DELETE RESTRICT`. `tickets.assignee_id` uses `ON DELETE SET NULL`. `comments.ticket_id`, `tags.org_id`, `ticket_tags.ticket_id`, and `ticket_tags.tag_id` all use `ON DELETE CASCADE`. `ticket_tags.added_by` uses `ON DELETE RESTRICT`.
Reason: Each choice follows from whether the child row's existence still makes sense — or whether losing the link would destroy an audit trail — once the parent is gone. `created_by`/`author_id`/`added_by` are audit records (who did this); silently deleting them by cascading, or silently nulling them, would erase accountability, so a delete on the parent agent is *rejected* (RESTRICT) until the historical rows are dealt with explicitly. A comment or a tag-association has no independent meaning without its ticket, so those cascade. `assignee_id` is different: an unassigned ticket is still a perfectly valid ticket, so deleting the assigned agent should just detach the assignment (SET NULL) rather than block the delete or destroy the ticket.

### Decision 3: Default value decision (`created_at DEFAULT NOW()` vs. nullable timestamps with no default)
ERD said: `created_at` appears on every entity with no "nullable" annotation, while `resolved_at` (Ticket) and `deactivated_at` (Agent) are explicitly marked `"nullable"`.
Schema decided: every `created_at` column is `TIMESTAMPTZ NOT NULL DEFAULT NOW()`, while `resolved_at` and `deactivated_at` are plain nullable `TIMESTAMPTZ` columns with no default and no NOT NULL.
Reason: `created_at` records a fact that is always true the instant a row is inserted — it should never require the application to remember to set it, and it should never be missing, so `NOT NULL DEFAULT NOW()` is both correct and removes a whole class of "forgot to set created_at" bugs. `resolved_at`/`deactivated_at` represent events that may never happen (a ticket that's still open, an agent who's still active) — giving them a default would fabricate a false timestamp, so they stay nullable with no default, and the application sets them explicitly the moment the real event occurs.

---

## Rejected Table Shape

### Shape: `tickets.tags TEXT[]` (tags stored as a raw array column on tickets)
What it was: the broken starter schema had `ALTER TABLE tickets ADD COLUMN tags TEXT[];` — storing a ticket's tags as a plain array of strings directly on the ticket row, instead of the `Tag` and `TicketTag` entities shown in the ERD.
Why rejected: the ERD models tags as their own first-class entity (`Tag`, with `org_id`, `name`, `color_hex`) connected to tickets through a many-to-many join table (`TicketTag`, which also records `added_by`/`added_at`). A bare array column throws all of that away — it can't enforce that a tag belongs to the right organization, it can't record who applied a tag or when, and it can't guarantee the tag name is spelled consistently (e.g. `"billing"` vs `"Billing"` vs `"BILLING"` living side-by-side across tickets with no shared source of truth).
What would break: querying "every ticket with the tag `billing`" would require scanning and unnesting the array on every ticket row instead of a simple indexed join; renaming a tag org-wide (e.g. fixing a typo) would require updating the array on every ticket instead of one row in `tags`; there would be no way to know which agent added a given tag or when (`added_by`/`added_at` from the ERD simply have nowhere to live); and nothing would stop one organization's tickets from referencing another organization's tag name, since a raw string has no foreign key to enforce that boundary. The two-table `tags` + `ticket_tags` design replaces all of this with a normal, indexable, auditable many-to-many relationship.

---

## How the Schema Was Verified

```bash
npm run db:reset   # drops/recreates helpdesk_test and applies migrations/001_initial_schema.sql
npm test           # runs the 36 pgTAP assertions in tests/schema.test.sql
```

All 36 assertions pass against the repaired `migrations/001_initial_schema.sql`.

---

## Submission

Branch: `schema-repair`

```bash
git checkout -b schema-repair
git add migrations/001_initial_schema.sql README.md
git commit -m "fix: repair helpdesk schema to match ERD"
git push origin schema-repair
```
