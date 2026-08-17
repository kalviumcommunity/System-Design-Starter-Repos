## ERD-to-Schema Decisions

### Decision 1: UUID instead of SERIAL for IDs
ERD said: Entity IDs are represented as UUID values.

Schema decided: Primary key and foreign key columns use UUID, with primary keys using `DEFAULT gen_random_uuid()`.

Reason: This matches the ERD and provides unique identifiers without using sequential integer IDs.

### Decision 2: ON DELETE behavior for ticket assignee
ERD said: `Ticket.assignee_id` is a nullable relationship to `Agent`.

Schema decided: `assignee_id` uses `ON DELETE SET NULL`.

Reason: If an assigned agent is removed, the ticket should remain available but become unassigned.

### Decision 3: Default value for ticket status
ERD said: A ticket has a status with allowed values including `open`.

Schema decided: The `status` column uses `DEFAULT 'open'`.

Reason: A newly created ticket should automatically start with the `open` status when no status is explicitly provided.

## Rejected Table Shape

### Shape: `tags TEXT[]` column on tickets
What it was: The original schema stored tags directly inside the `tickets` table using a `TEXT[]` array.

Why rejected: The ERD represents tags as a separate entity and requires a relationship between tickets and tags.

What would break: The database would not correctly represent the ticket-to-tag relationship and would make individual tag management and relationship queries more difficult.
