-- migrations/001_retrieval_schema.sql (REPAIRED)
--
-- Retrieval store for incident similarity search. The authoritative records
-- live in `incidents`; `incident_chunks` is derived data: each incident's
-- description is split into chunks, each chunk is embedded into a 1,536-dim
-- vector, and chunks are searched by cosine similarity with relational filters
-- (hybrid retrieval).
--
-- The pgvector extension provides the `vector` type and the HNSW index.
-- Without it, the `vector(1536)` column type does not exist.
CREATE EXTENSION IF NOT EXISTS vector;

-- ---------------------------------------------------------------------------
-- incidents  (authoritative — shown for reference; unchanged from the spec)
-- ---------------------------------------------------------------------------
CREATE TABLE incidents (
  id          BIGSERIAL PRIMARY KEY,
  title       TEXT NOT NULL,
  description TEXT NOT NULL,                      -- the text that gets chunked + embedded
  team_id     BIGINT NOT NULL,
  severity    TEXT NOT NULL CHECK (severity IN ('P1', 'P2', 'P3', 'P4')),
  status      TEXT NOT NULL CHECK (status IN ('open', 'ack', 'resolved', 'closed')) DEFAULT 'open',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- incident_chunks  (the retrieval table)
-- ---------------------------------------------------------------------------
CREATE TABLE incident_chunks (
  id          BIGSERIAL PRIMARY KEY,
  -- A chunk has no meaning without its incident: cascade deletes.
  incident_id BIGINT NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
  chunk_text  TEXT NOT NULL,                      -- the source text that was embedded
  embedding   vector(1536) NOT NULL,              -- the embedding vector (pgvector type)
  team_id     BIGINT NOT NULL,                    -- denormalised filter metadata
  severity    TEXT NOT NULL,                      -- denormalised filter metadata
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
-- ANN index for "find the most similar chunks on every incident open".
-- HNSW with cosine distance matches how the embeddings are compared.
CREATE INDEX idx_incident_chunks_embedding
  ON incident_chunks USING hnsw (embedding vector_cosine_ops);

-- B-tree on the FK: serves re-embedding a single incident and cascade lookups.
CREATE INDEX idx_incident_chunks_incident_id
  ON incident_chunks (incident_id);
