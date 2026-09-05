## Retrieval-Model Decisions

### Decision 1: Embedding storage type
Spec said: each chunk is embedded into a 1,536-dimension vector and searched by similarity.
Schema decided: `embedding vector(1536) NOT NULL` using the pgvector extension, not TEXT/JSON/float8[].
Reason: similarity search needs a native vector type so Postgres can build an ANN index (HNSW) over it.
Storing the vector as text or an array would make every similarity query a full sequential scan with
application-side math — it wouldn't be able to use `vector_cosine_ops` at all.

### Decision 2: ON DELETE behaviour on the FK
Spec said: incidents is the authoritative table; chunks are derived from an incident's description.
Schema decided: `incident_id BIGINT NOT NULL REFERENCES incidents(id) ON DELETE CASCADE`.
Reason: a chunk has no independent meaning once its incident is gone. Without CASCADE, deleting an
incident would either fail (FK violation) or leave orphaned chunks that could still surface in
similarity search results for an incident that no longer exists.

### Decision 3: Denormalised filter metadata
Spec said: chunks are searched by similarity with relational filters (hybrid retrieval).
Schema decided: `team_id BIGINT NOT NULL` and `severity TEXT NOT NULL` are duplicated onto
`incident_chunks` even though they already live on `incidents`.
Reason: hybrid retrieval filters (e.g. "similar P1 incidents on team X") need to run in the same query
as the vector search. Joining back to `incidents` per candidate row on every retrieval call would add
latency to a query that runs on every incident open; denormalising trades a small consistency-maintenance
cost for avoiding that join on the hot path.

## Rejected Shape

### Shape: single `incidents.embedding` column
What it was: a single TEXT `embedding` column bolted directly onto the `incidents` table — one embedding
per incident, computed from the whole description in one shot.
Why rejected: an incident's description is often a long, multi-paragraph write-up (timeline, root cause,
remediation steps, etc.). Collapsing all of that into one embedding vector averages together semantically
different content, so the vector represents "the incident in general" rather than any specific part of it.
What would break: retrieval granularity. A query about "the fix that worked" could match an incident whose
root-cause paragraph is similar but whose resolution isn't, because the single vector blends both. It also
blocks re-embedding at the right unit of work — any edit to the description forces recomputing one big
vector instead of just the changed chunk — and it makes it impossible to return "the paragraph that matched"
to ground the assistant's summary, only "the incident that matched."