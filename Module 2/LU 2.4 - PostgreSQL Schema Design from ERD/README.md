# Helpdesk Schema Repair — LU 2.4 Assignment

## What This Is

You are a backend engineer on the Helpdesk team. A colleague wrote the first draft of the PostgreSQL schema in `migrations/001_initial_schema.sql`. It has **intentional errors** — wrong column types, missing constraints, wrong ON DELETE behaviour, and a rejected table shape that should have never been there.

Your job: **fix the schema so it correctly implements the ER diagram** from the assignment question. The ER diagram is the source of truth. The schema must match it exactly.

When you're done, all 36 pgTAP tests must pass.

---

## Prerequisites

Make sure you have the following installed before starting:

| Tool | Why | Check |
|------|-----|-------|
| PostgreSQL (v13+) | Runs the test database | `psql --version` |
| pgTAP | Test framework for schema validation | `pg_prove --version` |
| pg_prove | pgTAP test runner | comes with pgTAP |
| Node.js + npm | Runs the helper scripts | `node --version` |

### Installing pgTAP

**macOS (Homebrew):**
```bash
brew install pgtap
```

**Ubuntu / Debian:**
```bash
sudo apt-get install postgresql-15-pgtap
# replace 15 with your postgres version
```

**Windows (via pgxn):**
```bash
pgxn install pgtap
```

After installing, enable it in your database:
```sql
CREATE EXTENSION IF NOT EXISTS pgtap;
```

---

## Setup

### Step 1: Clone or fork the repo

```bash
git clone <repo-url>
cd helpdesk-schema-repair
```

### Step 2: Make sure PostgreSQL is running

```bash
# macOS (Homebrew)
brew services start postgresql

# Ubuntu
sudo service postgresql start

# Docker (if you prefer)
docker run --name helpdesk-pg -e POSTGRES_PASSWORD=postgres -p 5432:5432 -d postgres:15
```

### Step 3: Create the test database and apply the schema

```bash
npm run db:reset
```

This command does three things in sequence:
1. Drops the `helpdesk_test` database if it exists
2. Creates a fresh `helpdesk_test` database
3. Applies `migrations/001_initial_schema.sql` to it

> ⚠️ If you see a "role does not exist" error, your PostgreSQL user might need to be set. Run `psql -U postgres` first and make sure you can connect. Then update the `db:reset` script in `package.json` to add `-U postgres` to each psql command.

### Step 4: Run the tests

```bash
npm test
```

The first time you run this, **most tests will fail**. That's expected — the schema is broken. Your job is to fix it until all 36 pass.

---

## What the Tests Check

The 36 pgTAP tests verify:

| Category | Tests | What they check |
|----------|-------|-----------------|
| Table existence | 6 | All 6 tables exist (including the 2 you need to add) |
| Column types | 16 | UUIDs are UUID not INTEGER, timestamps are TIMESTAMPTZ not TIMESTAMP, booleans are BOOLEAN not TEXT |
| NOT NULL | 11 | Required fields are actually marked NOT NULL |
| Nullable | 3 | Optional fields are correctly nullable |
| Column absence | 1 | The rejected `tags TEXT[]` column is gone |
| UNIQUE | 1 | `agents.email` is UNIQUE |

---

## The File to Fix

**Only edit this file:**

```
migrations/001_initial_schema.sql
```

Every broken line has a `-- wrong:` comment explaining what the problem is. Read each comment carefully.

---

## Hints

Work table by table. Don't try to fix everything at once.

**Hint 1 — Types:**
The ERD uses conceptual types. Translate them:
- `uuid` → `UUID`
- `string` → `TEXT` (not VARCHAR)
- `text` → `TEXT`
- `boolean` → `BOOLEAN` (not TEXT)
- `timestamp` → `TIMESTAMPTZ` (not TIMESTAMP — timezone matters in production)

**Hint 2 — Primary Keys:**
Every `SERIAL PRIMARY KEY` should be `UUID PRIMARY KEY DEFAULT gen_random_uuid()`. Check if you need to enable the `pgcrypto` extension first.

**Hint 3 — NOT NULL:**
If the ERD shows a field without `"nullable"` in quotes, it is required. Add `NOT NULL`. Go through every field in every entity in the ERD.

**Hint 4 — CHECK constraints:**
If the ERD attribute note shows pipe-separated values like `"starter|pro|enterprise"`, that means a CHECK constraint with exactly those allowed values. Do not use an ENUM type — use `TEXT NOT NULL CHECK (column IN (...))`.

**Hint 5 — Foreign Keys:**
All FK columns in the broken schema are `INTEGER`. They should all be `UUID`. Also: every FK needs an explicit `ON DELETE` clause. Look at the assignment question for the correct ON DELETE behaviour per FK (the table is provided there).

**Hint 6 — The Rejected Shape:**
There's an `ALTER TABLE` at the bottom of the broken schema adding `tags TEXT[]` to tickets. This is the wrong design. Remove that line entirely. Then add two new tables: `tags` and `ticket_tags`. Their columns are in the ER diagram.

**Hint 7 — Timestamps:**
All `created_at` columns should have `NOT NULL DEFAULT NOW()`. All nullable timestamp columns (`resolved_at`, `deactivated_at`) should have no DEFAULT and no NOT NULL.

---

## Workflow

The recommended loop while fixing:

```bash
# 1. Edit the schema
nano migrations/001_initial_schema.sql   # or use your editor

# 2. Reset the database (re-applies the schema from scratch)
npm run db:reset

# 3. Run the tests and see how many pass
npm test

# 4. Repeat until all 36 pass
```

Each time you run `db:reset`, the database is wiped and recreated from your current schema file. This means each run is a clean slate — no leftover state.

---

## Common Errors

**`ERROR: type "uuid" does not exist`**
→ Add `CREATE EXTENSION IF NOT EXISTS "pgcrypto";` at the top of your SQL file.

**`ERROR: function gen_random_uuid() does not exist`**
→ Same fix — pgcrypto extension is not enabled.

**`ERROR: column "tags" of relation "tickets" does not exist` (when running tests)**
→ You still have the `ALTER TABLE tickets ADD COLUMN tags TEXT[]` line. Remove it.

**`ERROR: there is no unique constraint matching given keys for referenced table`**
→ A FK references a column that is not a primary key or unique. Check your FK definitions.

**`pg_prove: command not found`**
→ pgTAP is not installed or not on your PATH. See prerequisites above.

**`psql: error: connection to server failed`**
→ PostgreSQL is not running. Start it with `brew services start postgresql` (macOS) or `sudo service postgresql start` (Linux).

---

## Submission

Once all 36 tests pass:

1. Commit your changes to a branch called `schema-repair`:
```bash
git checkout -b schema-repair
git add migrations/001_initial_schema.sql README.md
git commit -m "fix: repair helpdesk schema to match ERD"
```

2. Update `README.md` (this file) with exactly **3 ERD-to-schema decisions** and **1 rejected table shape** using this format:

---

## ERD-to-Schema Decisions

### Decision 1: Column Type Decision (TEXT + CHECK, UUID, and TIMESTAMPTZ)
**ERD said:**
- `plan` has values `"starter|pro|enterprise"`
- `role` has values `"agent|supervisor|admin"`
- `priority` has values `"low|medium|high|urgent"`
- `status` has values `"open|pending|resolved|closed"`
- Primary keys are `uuid`
- Timestamps are `timestamp` (`created_at`, `resolved_at`, `deactivated_at`, `added_at`)

**Schema decided:**
- Used `TEXT` with explicit `CHECK` constraints (e.g., `CHECK (status IN ('open','pending','resolved','closed'))`) rather than PostgreSQL native `ENUM` types (`CREATE TYPE ... AS ENUM`).
- Used `TIMESTAMPTZ` (`timestamp with time zone`) for all timestamp columns instead of `TIMESTAMP` without time zone.
- Used `UUID` with `DEFAULT gen_random_uuid()` for all primary and foreign keys instead of `SERIAL`/`INTEGER`.

**Reason:**
- In customer support systems, domain statuses, priorities, and roles evolve as the platform matures (e.g., adding "escalated", "pending_customer", or "tier2_agent"). With `TEXT + CHECK`, adding a new value or modifying status transitions requires only a simple constraint update (`ALTER TABLE ... DROP CONSTRAINT ... ADD CONSTRAINT ...`), avoiding the catalog table locks associated with `ALTER TYPE ... ADD VALUE` on PostgreSQL `ENUM` types.
- In PostgreSQL, `TEXT` and `VARCHAR(n)` have identical performance. `TEXT` with a `CHECK` constraint conveys clean semantics without arbitrary length limits.
- `TIMESTAMPTZ` stores timestamps normalized to UTC and converts to the client's session timezone on read. Plain `TIMESTAMP` discards timezone information; when agents, supervisors, and customers across different time zones file and triage tickets, plain `TIMESTAMP` produces ambiguous audit records.
- `UUID` primary keys prevent enumeration attacks on external APIs (preventing competitors or malicious users from guessing ticket or agent counts) and allow client-side ID generation before INSERT.

### Decision 2: ON DELETE Referential Integrity Behaviors
**ERD said:**
- `Agent ||--o{ Ticket : "created_by"` (every ticket requires a creating agent)
- `Agent o|--o{ Ticket : "assigned to"` (tickets may optionally be assigned to an agent)
- `Organization ||--o{ Agent : "has agents"` (organizations have agents)
- `Organization ||--o{ Ticket : "owns"` (organizations own tickets)
- `Ticket ||--o{ Comment : "has comments"` (tickets have comments)
- `Ticket ||--o{ TicketTag : "tagged with"` and `Tag ||--o{ TicketTag : "applied to"`

**Schema decided:**
- `ON DELETE RESTRICT` for `tickets.created_by`, `agents.org_id`, `tickets.org_id`, `comments.author_id`, and `ticket_tags.added_by`.
- `ON DELETE SET NULL` for `tickets.assignee_id`.
- `ON DELETE CASCADE` for `comments.ticket_id`, `tags.org_id`, `ticket_tags.ticket_id`, and `ticket_tags.tag_id`.

**Reason:**
- `RESTRICT` enforces business audit trails: Support tickets and comments are auditable records. Deleting an agent account must never delete tickets they created or comments they authored. `RESTRICT` prevents accidental deletion of agents or organizations that own active tickets and requires soft deactivation (`deactivated_at`) instead.
- `SET NULL` on `assignee_id` ensures operational continuity: If an assigned agent is deleted or deactivated, the ticket remains intact in the system and becomes unassigned (`NULL`), allowing other agents in the queue to pick it up.
- `CASCADE` cleans up dependent child entities: Comments and tag associations (`ticket_tags`) have no standalone identity or meaning without their parent ticket. Deleting a ticket cleanly deletes its comments and applied tags without leaving orphaned records.

### Decision 3: Schema-Level Default Values
**ERD said:**
- Ticket status starts as `"open"`.
- Comment `internal` visibility is a boolean flag visible to agents only.
- Creation timestamps and UUID identifiers are generated upon insertion.

**Schema decided:**
- Implemented default clauses directly in the SQL table definitions:
  - `status TEXT NOT NULL CHECK (...) DEFAULT 'open'`
  - `internal BOOLEAN NOT NULL DEFAULT FALSE`
  - `created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`
  - `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`

**Reason:**
- Enforcing defaults in the database schema guarantees system invariants independent of application code. If default values live only in application frameworks (e.g. ORM models or API handlers), direct SQL operations, background workers, admin migrations, or batch data loading scripts can bypass application logic and insert rows with `NULL` or invalid states. Database-level `DEFAULT` clauses guarantee that every row starts in a valid, predictable state regardless of the ingestion path.

## Rejected Table Shape

### Shape: Storing Tags as an Array Column on Tickets (`tickets.tags TEXT[]`)
**What it was:**
- The broken initial draft used `ALTER TABLE tickets ADD COLUMN tags TEXT[];` to store a list of tag strings directly on the `tickets` table row.

**Why rejected:**
- Tags represent independent domain entities with their own lifecycle and attributes (such as `name`, `color_hex`, and organization scoping `org_id`).
- An array column denormalizes a Many-to-Many (M:N) relationship into a flat column, losing referential integrity and database-enforced foreign key relationships.
- It prevents atomic cross-entity updates: renaming a tag (e.g., from `"billing"` to `"finance-billing"`) would require locking and scanning the entire `tickets` table to rewrite string arrays across thousands of rows instead of updating a single row in a `tags` table.
- It cannot capture relationship metadata: in customer support, auditing who tagged a ticket (`added_by`) and when it was tagged (`added_at`) is critical for compliance and reporting.

**What would break:**
- **Referential integrity breaks:** Any arbitrary or misspelled string can be inserted into the array; deleting a tag does not clean up tickets holding that string.
- **Tenant isolation breaks:** An agent could add a tag string intended for another organization because array values cannot reference `organizations(id)` via foreign keys.
- **Query performance degrades:** Filtering tickets by tag requires array containment operators (`@>`) or unnesting rather than indexed foreign key JOINs.
- **Auditability is lost:** There is no place in a `TEXT[]` array to store `added_by` and `added_at`, discarding accountability.
- **Chosen implementation:** Created an independent `tags` entity and a dedicated `ticket_tags` associative table with foreign keys to `tickets`, `tags`, and `agents`, protected by `UNIQUE (ticket_id, tag_id)` and appropriate `ON DELETE` rules.

---

3. Push and open a PR:
```bash
git push origin schema-repair
```

4. In the PR description, paste your `npm test` output showing all 36 tests passing.

---

## What You May Not Do

- Change the ER diagram (it is the source of truth)
- Add columns that don't exist in the ER diagram
- Skip `ON DELETE` on any FK — every FK must have an explicit `ON DELETE` clause
- Use `SERIAL` or `INTEGER` for any PK or FK column
- Leave the `tags TEXT[]` array column on the tickets table
- Use ENUM type instead of TEXT + CHECK

---

## Project Structure

```
helpdesk-schema-repair/
├── migrations/
│   └── 001_initial_schema.sql   ← the broken schema — only file you edit
├── tests/
│   └── schema.test.sql          ← 36 pgTAP tests — do not edit
├── README.md                    ← this file — update with your decisions
└── package.json                 ← npm scripts — do not edit
```
