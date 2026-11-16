
# Helpdesk Schema Repair

This project implements the Helpdesk ER diagram using PostgreSQL.

## ERD-to-Schema Decisions

### Decision 1: UUID identifiers and foreign keys

ERD said: Every entity has a UUID primary key, and relationships connect entities through UUID foreign keys.

Schema decided: All primary-key and foreign-key columns use UUID. Each primary key defaults to gen_random_uuid().

Reason: UUID types preserve the identifiers and relationships specified by the ERD and avoid SERIAL/INTEGER mismatches.

### Decision 2: ON DELETE behaviour

ERD said: The relationships identify required references and optional ticket assignment. The task specifies deletion behaviour for every foreign key.

Schema decided: Organization and audit references use RESTRICT. Ticket assignment uses SET NULL. Comments and ticket-tag associations use CASCADE. Tags cascade with their organization.

Reason: This preserves audit history, allows tickets to remain when an assignee is deleted, and removes dependent records when their parent is deleted.

### Decision 3: Timestamp defaults and time zones

ERD said: Entities contain timestamp attributes, including creation timestamps.

Schema decided: Timestamp columns use TIMESTAMPTZ. Creation timestamps use NOT NULL DEFAULT NOW(). Optional lifecycle timestamps remain nullable.

Reason: Time-zone-aware timestamps provide consistent time records across deployments.

## Rejected Table Shape

### Shape: tickets.tags TEXT[]

What it was: A text array column on tickets intended to store tags attached to a ticket.

Why rejected: The ERD models tags as a separate entity and ticket-to-tag assignment as a many-to-many relationship.

What would break: An array would not provide foreign-key integrity, would duplicate tag information, and would make association metadata such as added_by and added_at difficult to represent.

The schema instead uses tags and the junction table ticket_tags.
