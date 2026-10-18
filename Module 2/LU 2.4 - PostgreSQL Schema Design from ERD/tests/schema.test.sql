-- tests/schema.test.sql — pgTAP schema tests for the Helpdesk schema.
-- Run against a database that has the migration applied and pgtap installed.
BEGIN;
SELECT plan(50);

-- ---- Tables exist (and the two new ones) ----------------------------------
SELECT has_table('organizations');
SELECT has_table('agents');
SELECT has_table('tickets');
SELECT has_table('comments');
SELECT has_table('tags');
SELECT has_table('ticket_tags');

-- ---- tickets.tags array must be gone --------------------------------------
SELECT hasnt_column('tickets', 'tags', 'tickets.tags TEXT[] rejected shape removed');

-- ---- Primary keys are UUID -------------------------------------------------
SELECT col_type_is('organizations', 'id', 'uuid');
SELECT col_type_is('agents',        'id', 'uuid');
SELECT col_type_is('tickets',       'id', 'uuid');
SELECT col_type_is('comments',      'id', 'uuid');
SELECT col_type_is('tags',          'id', 'uuid');
SELECT col_type_is('ticket_tags',   'id', 'uuid');
SELECT col_has_default('organizations', 'id', 'organizations.id has a default (gen_random_uuid)');

-- ---- Timestamps are timestamptz -------------------------------------------
SELECT col_type_is('organizations', 'created_at', 'timestamp with time zone');
SELECT col_type_is('tickets',       'created_at', 'timestamp with time zone');
SELECT col_type_is('comments',      'created_at', 'timestamp with time zone');

-- ---- NOT NULL where the ERD requires it -----------------------------------
SELECT col_not_null('organizations', 'name');
SELECT col_not_null('organizations', 'plan');
SELECT col_not_null('agents', 'name');
SELECT col_not_null('agents', 'email');
SELECT col_not_null('agents', 'org_id');
SELECT col_not_null('tickets', 'subject');
SELECT col_not_null('tickets', 'org_id');
SELECT col_not_null('tickets', 'created_by');
SELECT col_not_null('comments', 'body');
SELECT col_not_null('comments', 'ticket_id');
SELECT col_not_null('comments', 'author_id');

-- ---- assignee_id is nullable ----------------------------------------------
SELECT col_is_null('tickets', 'assignee_id', 'tickets.assignee_id is nullable');

-- ---- email is UNIQUE -------------------------------------------------------
SELECT col_is_unique('agents', 'email');

-- ---- internal is a real boolean -------------------------------------------
SELECT col_type_is('comments', 'internal', 'boolean');
SELECT col_has_default('comments', 'internal', 'comments.internal has a default (false)');

-- ---- FK types are uuid -----------------------------------------------------
SELECT col_type_is('tickets',  'org_id',     'uuid');
SELECT col_type_is('comments', 'ticket_id',  'uuid');
SELECT col_type_is('ticket_tags', 'tag_id',  'uuid');

-- ---- CHECK constraints reject bad enum values -----------------------------
SELECT throws_ok(
  $$ INSERT INTO organizations (name, plan) VALUES ('X', 'gold') $$,
  '23514', NULL, 'plan CHECK rejects invalid value');
SELECT throws_ok(
  $$ INSERT INTO agents (name,email,role,org_id)
     VALUES ('X','x@x.com','root', gen_random_uuid()) $$,
  NULL, NULL, 'role CHECK / FK rejects invalid role');

-- ---- FK ON DELETE actions --------------------------------------------------
-- fk_ok confirms the FK exists; the delete-behaviour is asserted via pg_constraint.
SELECT fk_ok('agents', 'org_id', 'organizations', 'id');
SELECT fk_ok('tickets', 'org_id', 'organizations', 'id');
SELECT fk_ok('tickets', 'created_by', 'agents', 'id');
SELECT fk_ok('tickets', 'assignee_id', 'agents', 'id');
SELECT fk_ok('comments', 'ticket_id', 'tickets', 'id');
SELECT fk_ok('comments', 'author_id', 'agents', 'id');
SELECT fk_ok('tags', 'org_id', 'organizations', 'id');
SELECT fk_ok('ticket_tags', 'ticket_id', 'tickets', 'id');
SELECT fk_ok('ticket_tags', 'tag_id', 'tags', 'id');
SELECT fk_ok('ticket_tags', 'added_by', 'agents', 'id');

-- Confirm specific ON DELETE actions via the catalog.
SELECT is(
  (SELECT confdeltype FROM pg_constraint WHERE conname='tickets_assignee_id_fkey'),
  'n'::"char", 'tickets.assignee_id ON DELETE SET NULL');
SELECT is(
  (SELECT confdeltype FROM pg_constraint WHERE conname='comments_ticket_id_fkey'),
  'c'::"char", 'comments.ticket_id ON DELETE CASCADE');
SELECT is(
  (SELECT confdeltype FROM pg_constraint WHERE conname='tickets_created_by_fkey'),
  'r'::"char", 'tickets.created_by ON DELETE RESTRICT');

SELECT * FROM finish();
ROLLBACK;
