# Incident Retrieval Schema Repair

This PR fixes `migrations/001_retrieval_schema.sql` to correctly implement the
retrieval spec for the "similar past incidents" AI feature, and passes all 20
pgTAP tests in `tests/schema.test.sql`.

## Retrieval-Model Decisions

### Decision 1: Embedding storage type
Spec said: each chunk's text is embedded into a 1,536-dimension vector and
chunks are searched by similarity.
Schema decided: store `embedding` as `vector(1536) NOT NULL` using the
pgvector extension, instead of the draft's `TEXT` column.
Reason: similarity search depends on vector distance operators (cosine
distance) and ANN indexing (HNSW), neither of which exist for plain text.
Storing the embedding as `TEXT` (or JSON, or a `float8[]` array) would make
every similarity query a full table scan with no way to index it correctly,
and would require parsing the vector out of a string on every read.

### Decision 2: ON DELETE behaviour on the foreign key
Spec said: a chunk has no meaning without its parent incident.
Schema decided: `incident_id BIGINT NOT NULL REFERENCES incidents(id)
ON DELETE CASCADE`, replacing the draft's untyped, nullable FK with no
delete rule.
Reason: chunks are derived data, not authoritative records. If an incident
is deleted, its chunks should be deleted automatically. Without `ON DELETE
CASCADE`, deleting an incident would either be blocked by the FK or leave
orphaned chunks pointing at a row that no longer exists — both are worse
than cascading the delete.

### Decision 3: Denormalised filter metadata
Spec said: chunks are searched by similarity with relational filters
(hybrid retrieval).
Schema decided: add `team_id BIGINT NOT NULL` and `severity TEXT NOT NULL`
directly on `incident_chunks`, copied from the parent incident at write
time, instead of requiring a join back to `incidents` for every query.
Reason: the "similar incidents" query runs on every incident open and needs
to filter by team/severity alongside the vector similarity search. Joining
back to `incidents` on every retrieval call adds latency to a hot path;
denormalising the filter columns lets the ANN index and filters work
together directly on `incident_chunks`.

## Rejected Shape

### Shape: single `embedding` column on `incidents`
What it was: the draft added `ALTER TABLE incidents ADD COLUMN embedding
TEXT;` — one embedding vector per incident, stored directly on the
authoritative `incidents` table.
Why rejected: an incident's `description` can be long and multi-paragraph.
Compressing an entire multi-paragraph description into a single embedding
vector averages the meaning of every paragraph into one point in vector
space. If only one paragraph of a long incident actually matches a new
incident, that match gets diluted by the rest of the unrelated text and the
similarity score drops — the genuinely relevant incident may not surface in
the top 3 results at all.
What would break: retrieval granularity and recall. There would be no way
to identify *which part* of an incident was relevant, no way to re-embed
just a changed section, and long incidents would systematically retrieve
worse than short ones. Chunking each incident into smaller pieces, each
with its own embedding in `incident_chunks`, preserves per-section meaning
and lets similarity search match at the right granularity.
