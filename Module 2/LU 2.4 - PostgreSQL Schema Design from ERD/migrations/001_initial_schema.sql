CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  plan TEXT NOT NULL CHECK (
    plan IN ('starter', 'pro', 'enterprise')
  ),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE agents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  role TEXT NOT NULL CHECK (
    role IN ('agent', 'supervisor', 'admin')
  ),
  org_id UUID NOT NULL
    REFERENCES organizations(id)
    ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deactivated_at TIMESTAMPTZ
);

CREATE TABLE tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subject TEXT NOT NULL,
  body TEXT,
  priority TEXT NOT NULL CHECK (
    priority IN ('low', 'medium', 'high', 'urgent')
  ),
  status TEXT NOT NULL DEFAULT 'open' CHECK (
    status IN ('open', 'pending', 'resolved', 'closed')
  ),
  org_id UUID NOT NULL
    REFERENCES organizations(id)
    ON DELETE RESTRICT,
  created_by UUID NOT NULL
    REFERENCES agents(id)
    ON DELETE RESTRICT,
  assignee_id UUID
    REFERENCES agents(id)
    ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_at TIMESTAMPTZ
);

CREATE TABLE comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id UUID NOT NULL
    REFERENCES tickets(id)
    ON DELETE CASCADE,
  author_id UUID NOT NULL
    REFERENCES agents(id)
    ON DELETE RESTRICT,
  body TEXT NOT NULL,
  internal BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL
    REFERENCES organizations(id)
    ON DELETE CASCADE,
  name TEXT NOT NULL,
  color_hex TEXT NOT NULL
);

CREATE TABLE ticket_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id UUID NOT NULL
    REFERENCES tickets(id)
    ON DELETE CASCADE,
  tag_id UUID NOT NULL
    REFERENCES tags(id)
    ON DELETE CASCADE,
  added_by UUID NOT NULL
    REFERENCES agents(id)
    ON DELETE RESTRICT,
  added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (ticket_id, tag_id)
);

CREATE OR REPLACE FUNCTION check_ticket_tag_same_org()
RETURNS TRIGGER AS $$
DECLARE
  ticket_org_id UUID;
  tag_org_id UUID;
BEGIN
  SELECT org_id
  INTO ticket_org_id
  FROM tickets
  WHERE id = NEW.ticket_id;

  SELECT org_id
  INTO tag_org_id
  FROM tags
  WHERE id = NEW.tag_id;

  IF ticket_org_id <> tag_org_id THEN
    RAISE EXCEPTION
      'Ticket and tag must belong to the same organization';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER enforce_ticket_tag_same_org
BEFORE INSERT OR UPDATE ON ticket_tags
FOR EACH ROW
EXECUTE FUNCTION check_ticket_tag_same_org();