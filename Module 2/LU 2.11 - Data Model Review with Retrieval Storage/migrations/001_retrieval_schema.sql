-- Incident retrieval storage for the "similar past incidents" AI feature.

-- The vector(n) type and the HNSW index come from the pgvector extension.
CREATE EXTENSION IF NOT EXISTS vector;

-- Authoritative records. Chunks are derived from these.
CREATE TABLE incidents (
  id          BIGSERIAL PRIMARY KEY,
  title       TEXT NOT NULL,
  description TEXT NOT NULL,
  team_id     BIGINT NOT NULL,
  severity    TEXT NOT NULL CHECK (severity IN ('P1','P2','P3','P4')),
  status      TEXT NOT NULL CHECK (status IN ('open','ack','resolved','closed')) DEFAULT 'open',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- One incident has many chunks, and each chunk has its own vector.
CREATE TABLE incident_chunks (
  id          BIGSERIAL PRIMARY KEY,
  incident_id BIGINT NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
  chunk_text  TEXT NOT NULL,          -- the source text that was embedded
  embedding   vector(1536) NOT NULL,
  team_id     BIGINT NOT NULL,        -- copied filter column
  severity    TEXT NOT NULL,          -- copied filter column
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Serves the "similar incidents" search that runs on every incident open.
CREATE INDEX idx_incident_chunks_embedding
  ON incident_chunks USING hnsw (embedding vector_cosine_ops);

-- Serves re-embedding and cascade deletes, which find all chunks of one incident.
CREATE INDEX idx_incident_chunks_incident_id
  ON incident_chunks (incident_id);
