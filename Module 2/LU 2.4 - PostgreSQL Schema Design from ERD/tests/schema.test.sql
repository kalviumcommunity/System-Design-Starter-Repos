-- tests/extra_checks.sql
-- SUPPLEMENTARY pgTAP checks — run IN ADDITION to the provided tests/schema.test.sql,
-- never instead of it. These validate each constraint DIRECTLY and in isolation.
--
-- Two gaps this file closes (from review of an earlier version):
--   1. The role CHECK is tested against a REAL org row, so a failure can only be
--      the CHECK constraint firing — not an incidental foreign-key violation.
--   2. ALL TEN foreign-key ON DELETE actions are asserted, not just three.
--
-- Run:  psql -d helpdesk_test -c "CREATE EXTENSION IF NOT EXISTS pgtap;"
--       pg_prove -d helpdesk_test tests/schema.test.sql tests/extra_checks.sql
BEGIN;
SELECT plan(15);

-- ---------------------------------------------------------------------------
-- Seed a real org + agent so CHECK tests are not confounded by FK failures.
-- ---------------------------------------------------------------------------
INSERT INTO organizations (id, name, plan)
  VALUES ('00000000-0000-0000-0000-000000000001', 'Acme', 'pro');
INSERT INTO agents (id, name, email, role, org_id)
  VALUES ('00000000-0000-0000-0000-00000000000a', 'Al', 'al@acme.test', 'agent',
          '00000000-0000-0000-0000-000000000001');

-- ---- CHECK constraints tested in isolation (valid FK, so only the CHECK can fail) ----
-- role CHECK: bad role against a REAL org_id -> must raise 23514 (check_violation),
-- NOT 23503 (foreign_key_violation).
SELECT throws_ok(
  $$ INSERT INTO agents (name, email, role, org_id)
     VALUES ('Bad', 'bad@acme.test', 'superuser',
             '00000000-0000-0000-0000-000000000001') $$,
  '23514', NULL, 'agents.role CHECK rejects an invalid role (not an FK error)');

-- plan CHECK
SELECT throws_ok(
  $$ INSERT INTO organizations (name, plan) VALUES ('X', 'gold') $$,
  '23514', NULL, 'organizations.plan CHECK rejects an invalid plan');

-- priority + status CHECK on tickets (seed valid org + creator already exist)
SELECT throws_ok(
  $$ INSERT INTO tickets (subject, priority, status, org_id, created_by)
     VALUES ('t', 'blocker', 'open',
             '00000000-0000-0000-0000-000000000001',
             '00000000-0000-0000-0000-00000000000a') $$,
  '23514', NULL, 'tickets.priority CHECK rejects an invalid priority');
SELECT throws_ok(
  $$ INSERT INTO tickets (subject, priority, status, org_id, created_by)
     VALUES ('t', 'high', 'archived',
             '00000000-0000-0000-0000-000000000001',
             '00000000-0000-0000-0000-00000000000a') $$,
  '23514', NULL, 'tickets.status CHECK rejects an invalid status');

-- A valid role against the real org MUST succeed (positive control: proves the
-- previous failures were the CHECK, not the FK).
SELECT lives_ok(
  $$ INSERT INTO agents (name, email, role, org_id)
     VALUES ('Ok', 'ok@acme.test', 'supervisor',
             '00000000-0000-0000-0000-000000000001') $$,
  'a valid role against a real org inserts fine (FK path is good)');

-- ---------------------------------------------------------------------------
-- ALL TEN ON DELETE actions, asserted directly from the catalog.
-- confdeltype: 'r' = RESTRICT, 'c' = CASCADE, 'n' = SET NULL.
-- ---------------------------------------------------------------------------
SELECT is((SELECT confdeltype FROM pg_constraint WHERE conname = 'agents_org_id_fkey'),
          'r'::"char", 'agents.org_id ON DELETE RESTRICT');
SELECT is((SELECT confdeltype FROM pg_constraint WHERE conname = 'tickets_org_id_fkey'),
          'r'::"char", 'tickets.org_id ON DELETE RESTRICT');
SELECT is((SELECT confdeltype FROM pg_constraint WHERE conname = 'tickets_created_by_fkey'),
          'r'::"char", 'tickets.created_by ON DELETE RESTRICT');
SELECT is((SELECT confdeltype FROM pg_constraint WHERE conname = 'tickets_assignee_id_fkey'),
          'n'::"char", 'tickets.assignee_id ON DELETE SET NULL');
SELECT is((SELECT confdeltype FROM pg_constraint WHERE conname = 'comments_ticket_id_fkey'),
          'c'::"char", 'comments.ticket_id ON DELETE CASCADE');
SELECT is((SELECT confdeltype FROM pg_constraint WHERE conname = 'comments_author_id_fkey'),
          'r'::"char", 'comments.author_id ON DELETE RESTRICT');
SELECT is((SELECT confdeltype FROM pg_constraint WHERE conname = 'tags_org_id_fkey'),
          'c'::"char", 'tags.org_id ON DELETE CASCADE');
SELECT is((SELECT confdeltype FROM pg_constraint WHERE conname = 'ticket_tags_ticket_id_fkey'),
          'c'::"char", 'ticket_tags.ticket_id ON DELETE CASCADE');
SELECT is((SELECT confdeltype FROM pg_constraint WHERE conname = 'ticket_tags_tag_id_fkey'),
          'c'::"char", 'ticket_tags.tag_id ON DELETE CASCADE');
SELECT is((SELECT confdeltype FROM pg_constraint WHERE conname = 'ticket_tags_added_by_fkey'),
          'r'::"char", 'ticket_tags.added_by ON DELETE RESTRICT');

SELECT * FROM finish();
ROLLBACK;
