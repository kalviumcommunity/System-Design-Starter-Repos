# Incident Retrieval Schema Repair — LU 2.11 Assignment

## Retrieval-Model Decisions

### Decision 1: Embedding storage decision
Spec said: Each incident chunk must store a 1,536-dimension embedding using the pgvector `vector(1536)` type.

Schema decided: `embedding vector(1536) NOT NULL`.

Reason: A native vector type enables cosine-distance operators and the HNSW ANN index. Storing embeddings as `TEXT` or `float8[]` would prevent native vector similarity search, prevent the required ANN index, and fail to enforce the embedding dimension.

### Decision 2: ON DELETE decision
Spec said: `incident_chunks.incident_id` must reference the authoritative `incidents` row with `ON DELETE CASCADE`.

Schema decided: `incident_id BIGINT NOT NULL REFERENCES incidents(id) ON DELETE CASCADE`.

Reason: Chunks are derived data and have no meaning without their incident. When an incident is deleted, its chunks must disappear automatically rather than becoming orphaned vectors.

### Decision 3: Filter-metadata / denormalisation decision
Spec said: Retrieval combines vector similarity with relational filters such as team and severity.

Schema decided: Copy `team_id BIGINT NOT NULL` and `severity TEXT NOT NULL` onto every chunk.

Reason: Keeping the filter metadata on the retrieval row allows hybrid retrieval to apply similarity ranking and structured filters in one query without an additional join. This is deliberate denormalisation justified by the retrieval access pattern.

## Rejected Shape

### Shape: Single embedding column on `incidents`
What it was: An `embedding TEXT` column directly on the authoritative `incidents` table, with one embedding representing the entire incident.

Why rejected: A long incident can contain multiple distinct pieces of information such as symptoms, investigation details, root cause, and resolution. Compressing all of that into one embedding blurs the meaning and reduces retrieval granularity. It can also hit embedding input-length limits and lose information through truncation.

What would break: A precise query about one part of a long incident could match weakly because the single vector represents the combined meaning of the entire record. The correct model is one row per chunk in `incident_chunks`, with each chunk receiving its own embedding and tracing back to the source incident through `incident_id`.
