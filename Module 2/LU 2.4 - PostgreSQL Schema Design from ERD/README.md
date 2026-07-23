# Helpdesk Schema Repair

## ERD-to-Schema Decisions

### Decision 1: Column Type Decision

**ERD said:**
All primary keys and foreign keys use the `uuid` type, and timestamp fields are represented as `timestamp`.

**Schema decided:**

* All primary keys were implemented as `UUID PRIMARY KEY DEFAULT gen_random_uuid()`.
* All foreign keys use the `UUID` type.
* All timestamp columns were implemented as `TIMESTAMPTZ`.

**Reason:**
Using UUIDs provides globally unique identifiers and keeps all foreign key types consistent with their referenced primary keys. `TIMESTAMPTZ` stores timezone-aware timestamps, making the schema more suitable for production systems.

---

### Decision 2: ON DELETE Decision

**ERD said:**
Relationships between tables require specific delete behaviors to preserve data integrity.

**Schema decided:**

* `agents.org_id` → `organizations(id)` uses `ON DELETE RESTRICT`
* `tickets.org_id` → `organizations(id)` uses `ON DELETE RESTRICT`
* `tickets.created_by` → `agents(id)` uses `ON DELETE RESTRICT`
* `tickets.assignee_id` → `agents(id)` uses `ON DELETE SET NULL`
* `comments.ticket_id` → `tickets(id)` uses `ON DELETE CASCADE`
* `comments.author_id` → `agents(id)` uses `ON DELETE RESTRICT`
* `tags.org_id` → `organizations(id)` uses `ON DELETE CASCADE`
* `ticket_tags.ticket_id` → `tickets(id)` uses `ON DELETE CASCADE`
* `ticket_tags.tag_id` → `tags(id)` uses `ON DELETE CASCADE`
* `ticket_tags.added_by` → `agents(id)` uses `ON DELETE RESTRICT`

**Reason:**
These delete rules preserve audit information where required, automatically remove dependent records when appropriate, and prevent orphaned data.

---

### Decision 3: Default Value Decision

**ERD said:**
Each `created_at` field represents the time the record was created.

**Schema decided:**
All `created_at` columns were implemented as:

`TIMESTAMPTZ NOT NULL DEFAULT NOW()`

Optional timestamp fields (`resolved_at` and `deactivated_at`) remain nullable and have no default value.

**Reason:**
This automatically records creation time while allowing optional timestamps to remain empty until the corresponding event occurs.

---

## Rejected Table Shape

### Shape: `tickets.tags TEXT[]`

**What it was:**
The original schema stored ticket tags as a `TEXT[]` array inside the `tickets` table.

**Why rejected:**
The ER diagram models tags as a many-to-many relationship using separate `tags` and `ticket_tags` tables. An array column does not correctly represent this relationship.

**What would break:**
Keeping tags as an array would prevent proper foreign key constraints, make tag reuse across multiple tickets difficult, and violate the normalized schema defined by the ER diagram.
