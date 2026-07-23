## ERD-to-Schema Decisions

### Decision 1: UUID column types
ERD said: Primary and foreign key fields are `uuid`.
Schema decided: Use `UUID` columns with `DEFAULT gen_random_uuid()` for primary keys.
Reason: UUID keys avoid sequence-based IDs and match the ERD exactly.

### Decision 2: ON DELETE behavior for ticket ownership
ERD said: Tickets belong to an organization and a creator agent, while assignee is optional.
Schema decided: `org_id` and `created_by` use `ON DELETE RESTRICT`, and `assignee_id` uses `ON DELETE SET NULL`.
Reason: The audit trail must be preserved, but an assignment can be removed safely when an agent leaves.

### Decision 3: Timestamp defaults
ERD said: Created timestamps are present on each core entity.
Schema decided: All `created_at` columns use `TIMESTAMPTZ NOT NULL DEFAULT NOW()`.
Reason: Creation time should be captured automatically and stored with timezone awareness.

## Rejected Table Shape

### Shape: tickets.tags TEXT[]
What it was: A single array column on `tickets` that tried to store tag assignments inline.
Why rejected: Tags are a many-to-many relationship and need separate `tags` and `ticket_tags` tables.
What would break: Tag ownership, auditing, and referential integrity would all be impossible to enforce cleanly.
