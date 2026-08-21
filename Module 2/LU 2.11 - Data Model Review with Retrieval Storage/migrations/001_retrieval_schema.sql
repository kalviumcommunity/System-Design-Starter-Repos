-- migrations/001_retrieval_schema.sql
--
-- Incident retrieval storage for the "similar past incidents" AI feature.
--
-- incidents       = authoritative records (source of truth)
-- incident_chunks = derived data: each incident's description is split into chunks,
--                   each chunk embedded into a 1,536-dimension vector, and searched
--                   by cosine similarity with relational filters (hybrid retrieval).

-- The vector(n) type and the HNSW access method come from pgvector.
-- Without this, vector(1536) below does not exist.
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE incidents (
  id          BIGSERIAL PRIMARY KEY,
  title       TEXT NOT NULL,
  description TEXT NOT NULL,
  team_id     BIGINT NOT NULL,
  severity    TEXT NOT NULL CHECK (severity IN ('P1','P2','P3','P4')),
  status      TEXT NOT NULL CHECK (status IN ('open','ack','resolved','closed')) DEFAULT 'open',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE incident_chunks (
  id          BIGSERIAL PRIMARY KEY,

  -- A chunk has no meaning without its incident: same width as incidents.id,
  -- always present, and deleted with its parent.
  incident_id BIGINT NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,

  -- The exact source text that was embedded, kept so retrieved hits can be
  -- shown to the responder and re-embedded without re-deriving the split.
  chunk_text  TEXT NOT NULL,

  -- The embedding itself: a real pgvector value, not TEXT/JSON/float8[].
  embedding   vector(1536) NOT NULL,

  -- Denormalised filter metadata, copied from the parent incident so that
  -- similarity search can be filtered without joining back to incidents.
  team_id     BIGINT NOT NULL,
  severity    TEXT NOT NULL,

  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ANN index serving the retrieval query run on every incident open:
-- "three most similar past incidents", ordered by cosine distance (<=>).
CREATE INDEX idx_incident_chunks_embedding
  ON incident_chunks
  USING hnsw (embedding vector_cosine_ops);

-- B-tree index serving re-embedding ("every chunk for incident N") and the
-- ON DELETE CASCADE lookup when an incident is removed.
CREATE INDEX idx_incident_chunks_incident_id
  ON incident_chunks (incident_id);

-- NOTE: there is deliberately no incidents.embedding column. One embedding per
-- incident cannot represent a long, multi-paragraph description; embeddings live
-- per-chunk in incident_chunks. See README.md, "Rejected Shape".
