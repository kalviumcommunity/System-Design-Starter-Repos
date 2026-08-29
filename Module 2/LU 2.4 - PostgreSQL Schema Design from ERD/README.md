# Helpdesk Schema Repair - LU 2.4

## ERD-to-Schema Decisions

### Decision 1: UUID primary keys

ERD said: All entity IDs are UUIDs.

Schema decided: All primary keys use `UUID PRIMARY KEY DEFAULT gen_random_uuid()`.

Reason: This matches the ERD and provides generated unique identifiers without relying on sequential integer IDs.

### Decision 2: ON DELETE behavior

ERD said: Relationships between entities require foreign keys.

Schema decided: Each foreign key uses an explicit ON DELETE action based on the relationship requirements, including RESTRICT, SET NULL, and CASCADE.

Reason: This preserves audit records where required, keeps tickets when an assignee is deleted, and removes dependent records when their parent entity is deleted.

### Decision 3: Timestamp defaults

ERD said: Entities contain timestamp fields such as created_at.

Schema decided: created_at fields use `TIMESTAMPTZ NOT NULL DEFAULT NOW()`.

Reason: TIMESTAMPTZ preserves timezone-aware timestamps, while DEFAULT NOW() automatically records creation time.

## Rejected Table Shape

### Shape: tags TEXT[] on tickets

What it was: The original schema stored tags directly on the tickets table as a `TEXT[]` array.

Why rejected: The ERD models tags as a separate Tag entity with a TicketTag association entity, representing a many-to-many relationship.

What would break: Using an array would bypass the Tag and TicketTag entities and would not correctly represent the many-to-many relationship defined by the ERD.