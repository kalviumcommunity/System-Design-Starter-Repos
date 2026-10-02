# Incident Retrieval Schema Repair

## Retrieval-Model Decisions

### Decision 1: Vector embedding storage
Spec said: Store each chunk embedding as a 1,536-dimension pgvector vector.

Schema decided: `embedding vector(1536) NOT NULL`

Reason: pgvector provides the correct vector type and supports efficient similarity search using the required HNSW index.

### Decision 2: ON DELETE CASCADE
Spec said: `incident_chunks.incident_id` must reference `incidents.id` with `ON DELETE CASCADE`.

Schema decided: `incident_id BIGINT NOT NULL REFERENCES incidents(id) ON DELETE CASCADE`

Reason: Chunks are derived data and have no meaning without their authoritative incident, so deleting an incident should automatically remove its chunks.

### Decision 3: Filter metadata / denormalisation
Spec said: Store `team_id` and `severity` on `incident_chunks` as denormalised filter metadata.

Schema decided: `team_id BIGINT NOT NULL` and `severity TEXT NOT NULL`

Reason: Keeping these values with each chunk allows similarity retrieval to apply relational filters efficiently without depending on the authoritative incident row during every retrieval query.

## Rejected Shape

### Shape: Single embedding column on `incidents`
What it was: A single `embedding TEXT` column added directly to the `incidents` table.

Why rejected: One incident can contain long, multi-paragraph text that needs to be split into multiple chunks, with each chunk having its own embedding.

What would break: Retrieval granularity would be lost because the entire incident would be represented by one vector, making it impossible to retrieve the most relevant individual chunk accurately.