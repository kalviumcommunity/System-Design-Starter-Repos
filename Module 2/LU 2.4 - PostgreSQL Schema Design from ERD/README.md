# Helpdesk Schema Repair

## ERD-to-Schema Decisions

### Decision 1: UUID Primary Keys

ERD said: Organization, Agent, Ticket, Comment, Tag, and TicketTag IDs are UUIDs.

Schema decided: All primary keys use `UUID PRIMARY KEY DEFAULT gen_random_uuid()`.

Reason: The ERD explicitly defines the entity IDs as UUIDs, so the schema must use UUID rather than SERIAL or INTEGER.

### Decision 2: ON DELETE Behaviour

ERD said: `Ticket.created_by` is a required foreign key to `Agent`.

Schema decided: `created_by UUID NOT NULL REFERENCES agents(id) ON DELETE RESTRICT`.

Reason: The ticket must retain its creator for audit purposes. Deleting an agent who created tickets must therefore be prevented rather than deleting or orphaning those tickets.

### Decision 3: Default Value for Ticket Status

ERD said: A new ticket starts with status `open`.

Schema decided: `status TEXT NOT NULL CHECK (status IN ('open', 'pending', 'resolved', 'closed')) DEFAULT 'open'`.

Reason: The default is enforced at the database level, so tickets inserted through the application, scripts, or directly through PostgreSQL all receive `open` when no status is supplied.

## Rejected Table Shape

### Shape: `tickets.tags TEXT[]`

What it was: Tags were stored directly on each ticket as an array of text values.

Why rejected: The ER diagram defines `Tag` and `TicketTag` as separate entities representing a many-to-many relationship between tickets and tags.

What would break: An array would remove tag identity and referential integrity. Tags could not be independently referenced or managed through foreign keys. The design was therefore replaced with separate `tags` and `ticket_tags` tables.
