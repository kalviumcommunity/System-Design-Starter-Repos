# Incident Retrieval Schema Repair

## Retrieval-Model Decisions

### Decision 1: Embedding storage decision

Spec said: Each incident chunk must have a 1,536-dimension embedding stored using the pgvector `vector(1536)` type.

Schema decided: The `incident_chunks.embedding` column uses `vector(1536) NOT NULL`.

Reason: pgvector provides native vector storage and supports efficient similarity search through the required HNSW index. Storing embeddings as `TEXT`, JSON, or arrays would not provide the required vector-search behavior.

### Decision 2: ON DELETE decision

Spec said: `incident_chunks.incident_id` must reference `incidents(id)` with `ON DELETE CASCADE`.

Schema decided: `incident_id BIGINT NOT NULL REFERENCES incidents(id) ON DELETE CASCADE`.

Reason: Incident chunks are derived data and have no independent meaning without their authoritative incident. When an incident is deleted, its chunks must automatically be removed to prevent orphaned retrieval data.

### Decision 3: Filter-metadata / denormalisation decision

Spec said: `incident_chunks` must contain `team_id BIGINT NOT NULL` and `severity TEXT NOT NULL` as denormalised filter metadata.

Schema decided: The chunk table stores both `team_id` and `severity` directly.

Reason: Retrieval can first apply relational filters such as team and severity while searching the chunk vectors. Keeping this metadata on the retrieval rows avoids requiring every similarity-search query to join back to `incidents`, making hybrid retrieval more efficient.

## Rejected Shape

### Shape: Single embedding on `incidents`

What it was: The original schema added an `embedding TEXT` column directly to the `incidents` table.

Why rejected: A long incident description can contain multiple paragraphs and different pieces of information. The retrieval model requires the description to be split into multiple chunks, with each chunk having its own embedding.

What would break: A single embedding would collapse the entire incident into one vector, losing chunk-level retrieval granularity. The system could no longer retrieve the most relevant passage from a long incident; instead, it would only retrieve the incident as one large semantic unit. This would reduce the quality of similarity search and make grounded resolution retrieval less precise.

```
```
