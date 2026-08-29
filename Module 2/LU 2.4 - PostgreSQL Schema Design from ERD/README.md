## ERD-to-Schema Decisions

### Decision 1: UUID column types for identifiers

ERD said: Entity IDs and foreign keys are represented as `uuid`.

Schema decided: All primary keys use `UUID PRIMARY KEY DEFAULT gen_random_uuid()`, and all foreign key columns use `UUID`.

Reason: This keeps primary keys and their related foreign keys type-compatible and follows the ERD's identifier type. It also avoids using auto-incrementing integer IDs where the ERD explicitly requires UUIDs.

### Decision 2: ON DELETE behaviour for foreign keys

ERD said: The relationships between entities define how records depend on one another.

Schema decided: Foreign keys use explicit `ON DELETE` actions: `RESTRICT` for audit/ownership relationships, `SET NULL` for ticket assignees, and `CASCADE` for dependent records such as comments, tags, and ticket-tag associations.

Reason: This preserves important audit records while allowing dependent data to be removed automatically when its parent has no independent meaning. For example, deleting an agent cannot remove the agent who created a ticket, while deleting a ticket can safely remove its comments.

### Decision 3: Defaults for timestamps and ticket status

ERD said: Entities contain `created_at` timestamps, and tickets have a default status of `open`.

Schema decided: `created_at` and `added_at` use `TIMESTAMPTZ NOT NULL DEFAULT NOW()`, while `tickets.status` uses `TEXT NOT NULL DEFAULT 'open'` with its required status CHECK constraint.

Reason: Database defaults ensure records receive creation timestamps automatically and ensure newly created tickets start in the ERD-defined `open` state without requiring the application to provide these values explicitly.

## Rejected Table Shape

### Shape: `tickets.tags TEXT[]`

What it was: The broken schema stored ticket tags directly as a `TEXT[]` array column on the `tickets` table.

Why rejected: The ERD models tags as a separate `Tag` entity and represents the many-to-many relationship between tickets and tags using the `TicketTag` entity.

What would break: Keeping the array would duplicate the relationship represented by the ERD, make tag records difficult to manage independently, and prevent the schema from correctly representing the many-to-many relationship between tickets and tags. The array column was therefore removed and replaced with the `tags` and `ticket_tags` tables.
