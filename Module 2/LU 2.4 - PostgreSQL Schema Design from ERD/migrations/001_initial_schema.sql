-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Organizations
CREATE TABLE organizations (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name       TEXT NOT NULL,
    plan       TEXT NOT NULL
               CHECK (plan IN ('starter', 'pro', 'enterprise')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Agents
CREATE TABLE agents (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT NOT NULL,
    email           TEXT NOT NULL UNIQUE,
    role            TEXT NOT NULL
                    CHECK (role IN ('agent', 'supervisor', 'admin')),
    org_id          UUID NOT NULL
                    REFERENCES organizations(id)
                    ON DELETE RESTRICT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deactivated_at  TIMESTAMPTZ
);

-- Tickets
CREATE TABLE tickets (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subject      TEXT NOT NULL,
    body         TEXT,
    priority     TEXT NOT NULL
                 CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    status       TEXT NOT NULL
                 CHECK (status IN ('open', 'pending', 'resolved', 'closed'))
                 DEFAULT 'open',
    org_id       UUID NOT NULL
                 REFERENCES organizations(id)
                 ON DELETE RESTRICT,
    created_by   UUID NOT NULL
                 REFERENCES agents(id)
                 ON DELETE RESTRICT,
    assignee_id  UUID
                 REFERENCES agents(id)
                 ON DELETE SET NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at  TIMESTAMPTZ
);

-- Comments
CREATE TABLE comments (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id   UUID NOT NULL
                REFERENCES tickets(id)
                ON DELETE CASCADE,
    author_id   UUID NOT NULL
                REFERENCES agents(id)
                ON DELETE RESTRICT,
    body        TEXT NOT NULL,
    internal    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tags
CREATE TABLE tags (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id      UUID NOT NULL
                REFERENCES organizations(id)
                ON DELETE CASCADE,
    name        TEXT NOT NULL,
    color_hex   TEXT
);

-- Ticket Tags
CREATE TABLE ticket_tags (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id   UUID NOT NULL
                REFERENCES tickets(id)
                ON DELETE CASCADE,
    tag_id      UUID NOT NULL
                REFERENCES tags(id)
                ON DELETE CASCADE,
    added_by    UUID NOT NULL
                REFERENCES agents(id)
                ON DELETE RESTRICT,
    added_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
