# Incident Retrieval — Schema Repair

The migration in `migrations/001_retrieval_schema.sql` was repaired to correctly
implement the retrieval spec: the pgvector extension is enabled, `incident_chunks`
stores embeddings as a real `vector(1536)` type, the FK back to `incidents` has
the correct type and `ON DELETE CASCADE`, the denormalised filter columns are
present, both required indexes (HNSW ANN + B-tree) exist, and the rejected
single-`embedding`-on-`incidents` column is gone.

## Retrieval-Model Decisions

### Decision 1: Embedding storage — `vector(1536) NOT NULL`, not TEXT
Spec said: each chunk is embedded into a 1,536-dimension vector and searched by
similarity (pgvector `vector` type).
Schema decided: `embedding vector(1536) NOT NULL`, with `CREATE EXTENSION IF NOT
EXISTS vector;` at the top of the migration.
Reason: the broken schema stored the embedding as `TEXT`. Stored as text (or
JSON, or `float8[]`), the database cannot compute vector distance, cannot build
an ANN index, and every "find similar" query would have to parse strings in
application code. A true `vector(1536)` column lets Postgres compute cosine
distance with the `<=>` operator and back it with an HNSW index, which is the
whole point of the retrieval store.

### Decision 2: ON DELETE — `incident_id ... ON DELETE CASCADE`
Spec said: `incident_chunks` is derived data; the authoritative record is the
incident, and "a chunk has no meaning without its incident".
Schema decided: `incident_id BIGINT NOT NULL REFERENCES incidents(id) ON DELETE
CASCADE`.
Reason: chunks are a derived, regenerable projection of an incident's
description. When an incident is deleted, its chunks are orphaned embeddings that
can only pollute retrieval (they'd surface as "similar past incidents" that no
longer exist). CASCADE keeps the retrieval store consistent with the source of
truth automatically. (The FK is also `BIGINT`, matching `incidents.id`'s
`BIGSERIAL`, so the reference is type-correct — not `INTEGER`.)

### Decision 3: Filter metadata — denormalise `team_id` and `severity` onto the chunk
Spec said: chunks are searched by similarity *with relational filters* (hybrid
retrieval), and `team_id`/`severity` are denormalised filter metadata.
Schema decided: copy `team_id BIGINT NOT NULL` and `severity TEXT NOT NULL` onto
each `incident_chunks` row, even though they also live on the parent incident.
Reason: the retrieval query filters and ranks in one statement
(`WHERE team_id = ? ORDER BY embedding <=> ? LIMIT 3`). Keeping the filter
columns on the chunk row avoids a join back to `incidents` on every search and
lets the planner apply the filter alongside the ANN scan. The small duplication
is a deliberate denormalisation for read performance on the hot retrieval path;
the chunk is a derived record anyway, rebuilt whenever the incident is
re-embedded, so the copies stay in sync by construction.

## Rejected Shape

### Shape: a single `embedding` column on `incidents` (`ALTER TABLE incidents ADD COLUMN embedding TEXT`)
What it was: one embedding per incident, stored directly on the `incidents` row,
instead of many chunk embeddings in `incident_chunks`.
Why rejected: an incident's `description` is long and multi-paragraph. Forcing it
into **one** embedding vector destroys retrieval granularity — the entire
incident collapses to a single averaged point in vector space, so distinct
sub-topics (symptom, root cause, resolution) blur into one blurry centroid.
What would break: (1) **Chunking is impossible** — you can't embed a 2,000-word
incident as one 1,536-dim vector without losing most of its meaning; long text
must be split into chunks that each get their own vector. (2) **Retrieval
granularity collapses** — a search for "disk full on primary" can't match the one
relevant paragraph; it only ever matches the whole-incident average, so recall
drops and the three "most similar past incidents" become noisy. (3) You also
can't store the per-chunk `chunk_text` needed to show *which part* of a past
incident matched, which is exactly what the assistant needs to draft a grounded
summary. The correct model is one row per chunk in `incident_chunks`, each with
its own `vector(1536)` and the source `chunk_text`.

## Running the tests
```bash
npm install
npm run db:reset   # drops & recreates incident_retrieval_test, runs the migration, loads pgtap
npm test           # runs the 20 pgTAP schema tests — all must pass
```

The fastest local setup is the official pgvector image:
`docker run --name incident-pg -e POSTGRES_PASSWORD=postgres -p 5432:5432 -d pgvector/pgvector:pg16`
