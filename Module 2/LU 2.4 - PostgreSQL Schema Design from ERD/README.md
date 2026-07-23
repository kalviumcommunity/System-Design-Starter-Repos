# Helpdesk Schema Repair — LU 2.4 Assignment

## ERD-to-Schema Decisions

### Decision 1: UUID-based identity
ERD said: Every entity should use UUID primary keys.
Schema decided: Each table uses `UUID PRIMARY KEY DEFAULT gen_random_uuid()`.
Reason: UUIDs are the required production-safe identifier format for this assignment and avoid integer-based key collisions.

### Decision 2: Referential integrity for relationships
ERD said: Child records should remain linked to their parent entities.
Schema decided: The schema uses explicit foreign keys with `ON DELETE` behavior, including `CASCADE` for dependent rows and `SET NULL` for the optional assignee relationship.
Reason: This keeps the data model consistent and prevents orphaned rows or accidental loss of relationship context.

### Decision 3: Audit and constrained status fields
ERD said: Creation timestamps and state fields should be represented precisely.
Schema decided: Audit columns use `TIMESTAMPTZ NOT NULL DEFAULT NOW()`, while nullable timestamps remain nullable, and status or priority values are constrained with `CHECK` clauses.
Reason: Timezone-aware timestamps are correct for production systems, and the check constraints prevent invalid values from entering the schema.

## Rejected Table Shape

### Shape: `tickets.tags TEXT[]`
What it was: A denormalized array column on `tickets` to store tags.
Why rejected: It breaks first normal form, makes tag lookup and filtering inefficient, and duplicates tag data inside each ticket row.
What would break: Tag-based reporting and updates would be harder to maintain, data integrity would be weaker, and the schema would be harder to evolve.

## Testing

The final schema is designed to pass the pgTAP suite in [tests/schema.test.sql](tests/schema.test.sql) via:

```bash
npm test
```
