-- Helpdesk Schema — REPAIRED VERSION
-- Every fix below is annotated with WHY, not just WHAT, so the reasoning
-- is visible for the README decisions and for future readers of this file.
-- Reference: the ER diagram in the assignment-question.md

-- Setup: enable UUID generation.
-- gen_random_uuid() lives in pgcrypto on PG < 13. (PG 13+ also ships it
-- natively, but enabling pgcrypto is harmless and keeps this portable.)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================
-- Organizations
-- =============================================================
CREATE TABLE organizations (
  -- UUID instead of SERIAL: UUIDs are safe to generate on the client,
  -- don't leak sequential row counts, and merge cleanly across
  -- distributed systems/multi-region setups without collision.
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Every entity's non-nullable attributes in the ERD get NOT NULL.
  -- TEXT instead of VARCHAR(n): Postgres TEXT has no performance
  -- penalty vs VARCHAR, and an arbitrary length cap isn't in the ERD.
  name       TEXT NOT NULL,
  -- The ERD's "starter|pro|enterprise" annotation is a closed set of
  -- values -> enforce it at the DB layer with a CHECK, not just in app code.
  plan       TEXT NOT NULL CHECK (plan IN ('starter', 'pro', 'enterprise')),
  -- TIMESTAMPTZ (not TIMESTAMP) stores an absolute point in time with
  -- timezone awareness — required for any system with users in >1 timezone.
  -- DEFAULT NOW() means callers never have to pass created_at explicitly.
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================
-- Agents
-- =============================================================
CREATE TABLE agents (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name           TEXT NOT NULL,
  -- UNIQUE because email is how an agent logs in / is identified —
  -- two agent rows sharing an email would be a broken login system.
  email          TEXT NOT NULL UNIQUE,
  role           TEXT NOT NULL CHECK (role IN ('agent', 'supervisor', 'admin')),
  -- FK type MUST match the PK it references (uuid -> uuid).
  -- ON DELETE RESTRICT: you cannot delete an organization while it still
  -- has agents attached to it — forces an explicit off-boarding step first.
  org_id         UUID NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- deactivated_at has no NOT NULL and no DEFAULT: it is legitimately
  -- absent for every agent until the day they're deactivated.
  deactivated_at TIMESTAMPTZ
);

-- =============================================================
-- Tickets
-- =============================================================
CREATE TABLE tickets (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subject      TEXT NOT NULL,
  body         TEXT,                          -- nullable is correct per ERD
  priority     TEXT NOT NULL CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
  status       TEXT NOT NULL DEFAULT 'open'
               CHECK (status IN ('open', 'pending', 'resolved', 'closed')),
  org_id       UUID NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  -- created_by is an audit trail (who filed the ticket) — RESTRICT means
  -- an agent can't be deleted while they still "own" the historical record.
  created_by   UUID NOT NULL REFERENCES agents(id) ON DELETE RESTRICT,
  -- assignee_id is nullable (an unassigned ticket is valid) and uses
  -- SET NULL: if the assigned agent is deleted, the ticket doesn't die
  -- or block the delete — it just becomes unassigned again.
  assignee_id  UUID REFERENCES agents(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_at  TIMESTAMPTZ                    -- nullable: not resolved yet
);

-- =============================================================
-- Comments
-- =============================================================
CREATE TABLE comments (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- CASCADE: a comment has no meaning without its parent ticket, so when
  -- a ticket is deleted its comments should go with it automatically.
  ticket_id  UUID NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
  -- RESTRICT: same audit-trail logic as tickets.created_by — you must not
  -- be able to delete an agent and silently orphan/lose who wrote a comment.
  author_id  UUID NOT NULL REFERENCES agents(id) ON DELETE RESTRICT,
  body       TEXT NOT NULL,
  -- BOOLEAN, not TEXT 'false'/'true' strings — the DB can enforce the type
  -- and app code never has to string-compare truthiness.
  internal   BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================
-- Tags  (fixes the rejected `tickets.tags TEXT[]` shape below)
-- =============================================================
-- A bare array column can't be queried efficiently ("find all tickets with
-- tag X" needs a full scan / GIN index workaround), can't enforce that a
-- tag belongs to the right org, and allows the same tag name to be spelled
-- differently on every ticket. A real many-to-many relationship (Tag +
-- TicketTag join table) fixes all three problems and matches the ERD.
CREATE TABLE tags (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Tags are owned by an org, so deleting the org should take its tags
  -- with it — there is nothing else that references a tag's identity.
  org_id    UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name      TEXT NOT NULL,
  color_hex TEXT NOT NULL
);

-- =============================================================
-- TicketTag (the join table implementing the Ticket <-> Tag M:N)
-- =============================================================
CREATE TABLE ticket_tags (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- CASCADE both FKs: a tag *association* is meaningless once either the
  -- ticket or the tag it points to is gone — nothing to "keep" here.
  ticket_id UUID NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
  tag_id    UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  -- added_by is an audit trail again (who applied this tag) -> RESTRICT.
  added_by  UUID NOT NULL REFERENCES agents(id) ON DELETE RESTRICT,
  added_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

