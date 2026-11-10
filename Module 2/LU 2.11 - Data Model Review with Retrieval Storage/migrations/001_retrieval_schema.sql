
-- migrations/001_retrieval_schema.sql
-- Incident Retrieval Schema Repair
-- LU 2.11 Assignment

-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;


-- Authoritative incidents table
CREATE TABLE incidents (
  id          BIGSERIAL PRIMARY KEY,
  title       TEXT NOT NULL,
  description TEXT NOT NULL,
  team_id     BIGINT NOT NULL,
  severity    TEXT NOT NULL CHECK (severity IN ('P1','P2','P3','P4')),
  status      TEXT NOT NULL CHECK (status IN ('open','ack','resolved','closed')) DEFAULT 'open',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- Retrieval storage: one row per incident text chunk
CREATE TABLE incident_chunks (
  id          BIGSERIAL PRIMARY KEY,
  incident_id BIGINT NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
  chunk_text  TEXT NOT NULL,
  embedding   vector(1536) NOT NULL,
  team_id     BIGINT NOT NULL,
  severity    TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- HNSW Approximate Nearest Neighbour index
-- Used for cosine similarity search
CREATE INDEX idx_incident_chunks_embedding
ON incident_chunks
USING hnsw (embedding vector_cosine_ops);


-- B-tree index for incident_id lookups
CREATE INDEX idx_incident_chunks_incident_id
ON incident_chunks (incident_id);
