# Helpdesk Schema Repair — LU 2.4 Assignment

Production-ready PostgreSQL schema repair for the Helpdesk platform, implementing the Helpdesk ER diagram with strict data integrity, foreign key cascades, check constraints, and normalized relations.

## Run Tests

```bash
# 1. Reset database and run schema migration
npm run db:reset

# 2. Run pgTAP schema tests
npm test
```

### Test Results

```text
> helpdesk-schema-repair@1.0.0 test
> pg_prove -d helpdesk_test tests/schema.test.sql

tests/schema.test.sql .. ok
All tests successful.
Files=1, Tests=36,  0 wallclock secs ( 0.01 usr +  0.00 sys =  0.01 CPU)
Result: PASS
```

All 36 pgTAP tests pass.

---

## ERD-to-Schema Decisions

### Decision 1: Column type for timestamps
ERD said: `created_at`, `resolved_at`, `deactivated_at`, and `added_at` are `timestamp`.
Schema decided: `TIMESTAMPTZ` for all timestamp columns, not `TIMESTAMP`.
Reason: A plain `TIMESTAMP` stores a clock reading without a time zone, so users in different geographic locations cannot tell which exact moment was recorded. `TIMESTAMPTZ` records the unambiguous UTC instant and displays it localized to each agent and customer's time zone. This is essential for accurate audit logs, SLA calculations, and computing duration between `created_at` and `resolved_at`.

### Decision 2: ON DELETE behavior on Ticket Agent links
ERD said: `created_by` is required and `assignee_id` is optional on `Ticket`. The diagram is silent on what happens when a referenced agent is deleted.
Schema decided: `created_by` uses `ON DELETE RESTRICT`, whereas `assignee_id` uses `ON DELETE SET NULL`.
Reason: `created_by` is an audit record identifying who opened the ticket; refusing the delete (`RESTRICT`) protects historical accountability. `assignee_id` represents current operational assignment; if that agent account is deleted, resetting the foreign key to NULL (`SET NULL`) keeps the ticket alive and routes it back to the unassigned queue for reassignment.

### Decision 3: Default value for ticket status
ERD said: `status` has allowed values `open|pending|resolved|closed`. The diagram does not specify what value a newly created ticket starts with.
Schema decided: `status TEXT NOT NULL CHECK (status IN ('open', 'pending', 'resolved', 'closed')) DEFAULT 'open'`.
Reason: If default values exist only in application code, batch scripts, background jobs, or direct database inserts can bypass them and produce inconsistent rows. Defining `DEFAULT 'open'` in the schema guarantees that every new ticket starts in the `open` state regardless of which tool or query creates the record.

---

## Rejected Table Shape

### Shape: `tickets.tags TEXT[]` (tags stored as an array on the ticket)
What it was: A `tags TEXT[]` column on the `tickets` table storing tag names as an array of strings in each ticket row.
Why rejected: Ticket to Tag is a many-to-many relationship, and an array column fails to resolve it properly. A string inside an array lacks entity identity, making it impossible to store tag metadata (such as `color_hex` or tenant isolation via `org_id`). It also cannot record attribution metadata for the join, such as who applied the tag (`added_by`) or when (`added_at`). Resolving this into separate `tags` and `ticket_tags` tables properly models the domain entities and relationship.
What would break: Renaming a tag would require a full table scan updating every ticket containing that string. Typos and case mismatches (e.g., "billing" vs "Billing") would proliferate because array elements cannot enforce foreign keys against a master list. Furthermore, searching, filtering, and indexing tickets by tag across millions of rows becomes inefficient and breaks normalization rules.
