## Retrieval-Model Decisions

### Decision 1: Embedding storage decision
Spec said: The retrieval schema should store semantic vectors alongside chunked incident text so a similarity search can rank past incidents.
Schema decided: `incident_chunks.embedding` is a native `vector(1536)` column, not a text blob.
Reason: The retrieval system needs true cosine-distance comparisons and HNSW indexing. A text-encoded vector cannot be searched efficiently or compared with the vector operators the feature expects, so a native pgvector column is required for ANN recall and ranking.

### Decision 2: ON DELETE decision
Spec said: Child chunk records must stay tied to their parent incident and the schema must define explicit delete behaviour.
Schema decided: `incident_chunks.incident_id BIGINT NOT NULL REFERENCES incidents(id) ON DELETE CASCADE`.
Reason: A chunk has no meaning without its incident, and deleting the parent incident should automatically remove the derived retrieval records. This keeps the retrieval index consistent and prevents orphaned embeddings from surviving after a record is removed.

### Decision 3: Filter-metadata / denormalisation decision
Spec said: The retrieval layer should support hybrid search with filtering on the incident context, not just vector similarity.
Schema decided: `incident_chunks` includes `team_id BIGINT NOT NULL` and `severity TEXT NOT NULL` as denormalised filter metadata.
Reason: Filtering by team or severity is a common access pattern. Copying those values into each chunk avoids expensive joins during retrieval and keeps the similarity search path fast enough for an interactive responder workflow.

## Rejected Shape

### Shape: incidents.embedding
What it was: A single `embedding` column directly on the `incidents` table, with one vector meant to represent the whole incident description.
Why rejected: A long, multi-paragraph incident description is not a single semantic unit. Retrieval quality is better when text is chunked into multiple segments, each with its own vector, because different parts of the same incident may have different meanings and different relevance.
What would break: When one incident is forced into one embedding, chunking and retrieval granularity collapse. A single vector cannot capture multiple issue segments, key facts, or the relevant context for a query, so the system would over-merge unrelated passages, lose precision, and make the similarity search return weak or misleading matches.