# Helpdesk Schema Repair

## ERD-to-Schema Decisions

### Decision 1: Column type decision
ERD said: identifiers and relationships should be modeled as UUID values.
Schema decided: every primary key and foreign key uses UUID with `DEFAULT gen_random_uuid()`.
Reason: UUIDs are a better fit for distributed identifiers and match the ER diagram exactly.

### Decision 2: ON DELETE decision
ERD said: relationships must preserve business meaning when referenced records are removed.
Schema decided: organization and agent references use `RESTRICT`, ticket comments cascade with the parent ticket, and tag associations cascade with tickets or tags.
Reason: this prevents accidental data loss for audit-critical references while removing dependent rows when the parent ticket or tag is deleted.

### Decision 3: Default value decision
ERD said: created timestamps should be captured automatically for new records.
Schema decided: all `created_at` columns use `TIMESTAMPTZ NOT NULL DEFAULT NOW()`.
Reason: this makes inserts consistent and preserves timezone-aware timestamps in production.

## Rejected Table Shape

### Shape: tickets.tags array
What it was: a `TEXT[]` column on the `tickets` table to store tags.
Why rejected: the ER diagram models tags as a separate entity with a many-to-many relationship, so an array column would hide the relationship and make validation harder.
What would break: it would prevent proper tag lifecycle management, uniqueness rules, and join-based reporting across tickets and tags.

- Use ENUM type instead of TEXT + CHECK

---

## Project Structure

```
helpdesk-schema-repair/
├── migrations/
│   └── 001_initial_schema.sql   ← the broken schema — only file you edit
├── tests/
│   └── schema.test.sql          ← 36 pgTAP tests — do not edit
├── README.md                    ← this file — update with your decisions
└── package.json                 ← npm scripts — do not edit
```
