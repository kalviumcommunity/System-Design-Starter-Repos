# Incident Retrieval Schema Repair

Fixes `migrations/001_retrieval_schema.sql` so it matches the retrieval spec.

## Run the tests

Needs PostgreSQL, pgvector, pgTAP, and `pg_prove`.

```bash
npm run db:reset
npm test
```

## Retrieval-Model Decisions

### Decision 1: Embedding storage
Spec said: Each chunk is embedded into a 1,536-dimension vector and searched by similarity.
Schema decided: `embedding vector(1536) NOT NULL` on `incident_chunks`, with an HNSW index using `vector_cosine_ops`.
Reason: A `TEXT` column cannot be compared by distance or use an ANN index, so every search would have to parse and compare every row. The fixed length also rejects a vector from a model with a different dimension, because distances between different models mean nothing.

### Decision 2: ON DELETE
Spec said: A chunk has no meaning without its incident.
Schema decided: `incident_id BIGINT NOT NULL REFERENCES incidents(id) ON DELETE CASCADE`, plus a B-tree index on `incident_id`.
Reason: Chunks are derived data and `incidents` is the source of truth. Without the cascade, a deleted incident either leaves orphan vectors that cite a record that no longer exists, or has its delete blocked until someone removes the chunks by hand. The index keeps "all chunks of this incident" fast for cascades and re-embedding.

### Decision 3: Filter metadata
Spec said: Chunks are searched by similarity with relational filters, and `team_id` and `severity` are denormalised filter metadata.
Schema decided: `team_id BIGINT NOT NULL` and `severity TEXT NOT NULL` are copied onto every chunk.
Reason: The search runs every time a responder opens an incident, and it filters and ranks in one query with no join to `incidents`. The cost is drift: if an incident's team or severity changes, its chunks must be updated in the same step, or filtered search will be quietly wrong. The schema does not enforce this, so the write path must.

## Rejected Shape

### Shape: `incidents.embedding` (one embedding per incident)
What it was: A single `embedding TEXT` column added directly to `incidents`.
Why rejected: An incident's long description has to be split into chunks, each with its own vector. One column cannot hold a one-to-many relationship, and as `TEXT` it cannot be searched by similarity at all.
What would break: With a long, multi-paragraph description forced into one vector, symptoms, timeline, root cause, and resolution all blur into one averaged point, so a question about the root cause matches weakly and the right incident can rank below a shorter, less relevant one. Text past the embedding model's input limit would have to be cut off, so that part could never be found. A match also returns the whole incident instead of the relevant paragraph, which fills the assistant's prompt with unrelated text and makes the summary harder to ground.
