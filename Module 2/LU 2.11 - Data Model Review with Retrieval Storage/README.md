## Retrieval-Model Decisions

### Decision 1: Native vector embedding storage

Spec said: Each incident chunk must store its embedding as a 1,536-dimension vector.

Schema decided: `embedding vector(1536) NOT NULL`.

Reason: The pgvector `vector` type supports vector similarity operations and the required HNSW index. Storing embeddings as TEXT, JSON, or an array would prevent proper vector similarity search and ANN indexing.

### Decision 2: Cascade deletion for incident chunks

Spec said: Each retrieval chunk must reference its authoritative incident using `ON DELETE CASCADE`.

Schema decided: `incident_id BIGINT NOT NULL REFERENCES incidents(id) ON DELETE CASCADE`.

Reason: Incident chunks are derived data and have no meaning without their source incident. When an incident is deleted, its chunks should also be deleted automatically so that orphaned vectors cannot appear in retrieval results.

### Decision 3: Denormalised filter metadata

Spec said: Retrieval must support filtering by team and severity.

Schema decided: `team_id BIGINT NOT NULL` and `severity TEXT NOT NULL` are stored in `incident_chunks`.

Reason: Storing these filter fields directly on each chunk allows hybrid retrieval to combine vector similarity with team and severity filters efficiently without requiring an additional join.

## Rejected Shape

### Shape: Single `embedding` column on `incidents`

What it was: An `embedding` column directly on the `incidents` table containing one embedding vector for the entire incident.

Why rejected: A long incident can contain multiple pieces of information such as symptoms, investigation details, root cause, and resolution. One embedding for the entire incident blurs these different meanings and provides poor retrieval granularity. The correct model is to split the incident into smaller chunks and create one embedding for each chunk.

What would break: A query about a specific part of a long incident may fail to retrieve the relevant information because the single embedding represents the combined meaning of the entire incident. Long text may also exceed embedding input limits, causing information to be truncated. Chunk-level retrieval would therefore be lost.
