## ERD-to-Schema Decisions

### Decision 1: UUID primary keys
ERD said: Every entity uses UUID identifiers.
Schema decided: All PKs and related FKs use `UUID DEFAULT gen_random_uuid()`.
Reason: Prevents predictable IDs and keeps relationships type-safe.

### Decision 2: Ticket assignee deletion
ERD said: A ticket may have an optional assignee.
Schema decided: `assignee_id REFERENCES agents(id) ON DELETE SET NULL`.
Reason: Deleting an agent should not delete the ticket; it should become unassigned.

### Decision 3: Timestamp defaults
ERD said: Entities contain `created_at` timestamps.
Schema decided: `TIMESTAMPTZ NOT NULL DEFAULT NOW()` was used.
Reason: Ensures timezone-aware creation timestamps are always recorded automatically.

## Rejected Table Shape

### Shape: `tickets.tags TEXT[]`
What it was: An array column storing tag names directly on the ticket.
Why rejected: The ERD defines a many-to-many relationship between Ticket and Tag.
What would break: Tags could not store metadata such as organization ownership, color, or who added the tag, leading to inconsistent tagging and duplicate values.
