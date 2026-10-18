-- tests/schema.test.sql — pgTAP tests for the incident retrieval schema.
-- Requires the migration applied and the pgtap extension installed.
BEGIN;
SELECT plan(20);

-- ---- Tables exist ----------------------------------------------------------
SELECT has_table('incidents');
SELECT has_table('incident_chunks');

-- ---- Rejected shape removed ------------------------------------------------
SELECT hasnt_column('incidents', 'embedding',
  'rejected incidents.embedding column removed');

-- ---- incident_chunks.id is bigint (BIGSERIAL) ------------------------------
SELECT col_type_is('incident_chunks', 'id', 'bigint');
SELECT col_has_default('incident_chunks', 'id',
  'incident_chunks.id has a sequence default (BIGSERIAL)');

-- ---- incident_id is bigint, NOT NULL, FK with CASCADE ----------------------
SELECT col_type_is('incident_chunks', 'incident_id', 'bigint');
SELECT col_not_null('incident_chunks', 'incident_id');
SELECT fk_ok('incident_chunks', 'incident_id', 'incidents', 'id');
SELECT is(
  (SELECT confdeltype FROM pg_constraint
     WHERE conname = 'incident_chunks_incident_id_fkey'),
  'c'::"char", 'incident_id ON DELETE CASCADE');

-- ---- embedding is vector(1536) NOT NULL ------------------------------------
SELECT col_type_is('incident_chunks', 'embedding', 'vector(1536)');
SELECT col_not_null('incident_chunks', 'embedding');
SELECT is(
  (SELECT atttypmod FROM pg_attribute
     WHERE attrelid = 'incident_chunks'::regclass AND attname = 'embedding'),
  1536, 'embedding has 1536 dimensions');

-- ---- chunk_text NOT NULL ---------------------------------------------------
SELECT col_type_is('incident_chunks', 'chunk_text', 'text');
SELECT col_not_null('incident_chunks', 'chunk_text');

-- ---- denormalised filter metadata present, correct type, NOT NULL ----------
SELECT col_type_is('incident_chunks', 'team_id', 'bigint');
SELECT col_not_null('incident_chunks', 'team_id');
SELECT col_not_null('incident_chunks', 'severity');

-- ---- created_at is timestamptz NOT NULL ------------------------------------
SELECT col_type_is('incident_chunks', 'created_at', 'timestamp with time zone');

-- ---- required indexes exist ------------------------------------------------
SELECT has_index('incident_chunks', 'idx_incident_chunks_embedding',
  'HNSW ANN index on embedding exists');
SELECT has_index('incident_chunks', 'idx_incident_chunks_incident_id',
  'B-tree index on incident_id exists');

SELECT * FROM finish();
ROLLBACK;
