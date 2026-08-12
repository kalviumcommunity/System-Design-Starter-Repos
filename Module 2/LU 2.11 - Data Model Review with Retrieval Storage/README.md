## Retrieval-Model Decisions

### Decision 1: Vector embedding storage

Spec said: Each incident chunk must store its embedding as a 1,536-dimension pgvector vector.

Schema decided: The `incident_chunks.embedding` column uses `vector(1536) NOT NULL`.

Reason: pgvector provides a native vector type that supports efficient similarity search and allows the required HNSW ANN index with `vector_cosine_ops`. Storing embeddings as text would prevent proper vector similarity operations and indexing.

### Decision 2: Cascade deletion for incident chunks

Spec said: `incident_chunks.incident_id` must reference `incidents(id)` with `ON DELETE CASCADE`.

Schema decided: `incident_id` is defined as `BIGINT NOT NULL REFERENCES incidents(id) ON DELETE CASCADE`.

Reason: Incident chunks are derived data and have no independent meaning without their source incident. When an authoritative incident is deleted, its chunks should be removed automatically so orphaned retrieval data cannot remain.

### Decision 3: Denormalised filter metadata

Spec said: Each chunk must contain `team_id` and `severity` as filter metadata.

Schema decided: `incident_chunks` stores `team_id BIGINT NOT NULL` and `severity TEXT NOT NULL`.

Reason: Retrieval uses vector similarity together with relational filters. Keeping these values on each chunk allows filtering by team and severity directly during retrieval without requiring an additional join to the authoritative `incidents` table.

## Rejected Shape

### Shape: Single embedding column on `incidents`

What it was: The rejected design added one `embedding TEXT` column directly to the `incidents` table, attempting to represent an entire incident with a single embedding.

Why rejected: An incident can contain a long, multi-paragraph description that needs to be split into multiple chunks before embedding. A single incident-level embedding loses the chunk-level retrieval granularity required to identify the most relevant portions of an incident.

What would break: Chunking and retrieval granularity would be lost. The system could not independently compare multiple chunks from the same incident, making similarity retrieval less precise and preventing the retrieval model from returning the most relevant pieces of incident text and their resolutions.
