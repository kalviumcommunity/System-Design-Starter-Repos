# Helpdesk Schema — Repair Notes

## ERD-to-Schema Decisions

### Decision 1: Primary/foreign key type
ERD said: every entity's `id` is a `uuid`, and every FK (`org_id`, `created_by`, `assignee_id`, `ticket_id`, `author_id`, `tag_id`, `added_by`) points at one of those `uuid` ids.
Schema decided: all primary keys are `UUID PRIMARY KEY DEFAULT gen_random_uuid()`, and every FK column is typed `UUID` to match.
Reason: the original draft used `SERIAL`/`INTEGER`, which doesn't match the ERD's declared type and would silently break every join once real UUID-based rows existed. Matching types end-to-end also avoids exposing sequential, guessable IDs across an API.

### Decision 2: ON DELETE behaviour per relationship
ERD said: relationships are drawn as either mandatory (`||`) or optional (`o|`) on the "one" side, but doesn't itself encode delete semantics — that has to be inferred from what each relationship *means*.
Schema decided: audit-style links (`tickets.created_by`, `comments.author_id`, `ticket_tags.added_by`) and ownership links where the child must never outlive an active parent (`agents.org_id`, `tickets.org_id`) use `ON DELETE RESTRICT`. Ownership links where the child is meaningless without the parent (`comments.ticket_id`, `ticket_tags.ticket_id`, `ticket_tags.tag_id`, `tags.org_id`) use `ON DELETE CASCADE`. The one optional FK, `tickets.assignee_id`, uses `ON DELETE SET NULL` so a ticket survives its assignee being removed.
Reason: RESTRICT protects records that have legal/audit value (who filed a ticket, who wrote a comment) from silently disappearing. CASCADE is used only where the child row has no independent meaning once its parent is gone. SET NULL matches the ERD's optional (`o|`) cardinality on Agent–Ticket assignment — the ticket should keep existing, just unassigned.

### Decision 3: Default values and enum enforcement
ERD said: fields like `plan`, `role`, `priority`, and `status` are documented as pipe-separated value lists (e.g. `"starter|pro|enterprise"`) rather than a formal enum type, and `created_at` fields are just typed `timestamp`.
Schema decided: those value lists became `CHECK (col IN (...))` constraints instead of a native Postgres `ENUM` type, all timestamps are `TIMESTAMPTZ`, and every `created_at` gets `NOT NULL DEFAULT NOW()`.
Reason: `CHECK` constraints give the same guarantee as an enum but are far cheaper to extend later (no `ALTER TYPE ... ADD VALUE` migration dance) — appropriate since these are business-status fields likely to gain values (e.g. a new plan tier). `TIMESTAMPTZ` avoids timezone ambiguity in a multi-org SaaS product, and defaulting `created_at` server-side removes the risk of an app forgetting to set it.

## Rejected Table Shape

### Shape: `tickets.tags TEXT[]`
What it was: the broken draft added `tags TEXT[]` directly onto the `tickets` table — storing tag names as a raw text array on the ticket row instead of using the `Tag` and `TicketTag` entities from the ERD.
Why rejected: the ERD explicitly models tags as their own entity (`Tag`, with `org_id`, `name`, `color_hex`) connected to tickets through a join entity (`TicketTag`, with `added_by`/`added_at` audit fields). A `TEXT[]` column collapses that into an unstructured, ungoverned list.
What would break: tags could no longer be scoped/validated per-organization (any string could be typed on any ticket, including duplicates or typos of an existing tag's name); there'd be no `color_hex` or shared identity for a tag, so renaming or recoloring a tag would mean rewriting it across every ticket array individually; and there'd be no way to record *who* applied a tag or *when*, which the ERD requires via `TicketTag.added_by`/`added_at`. It would also make "all tickets with tag X" queries an unindexable array scan instead of a simple join. The fixed schema removes this column entirely and replaces it with the `tags` and `ticket_tags` tables.
