# Incident Retrieval Schema Repair — LU 2.11 Assignment

## Retrieval-Model Decisions

### Decision 1: Embedding Storage Decision

**Spec said:** Each incident chunk must store an embedding with exactly 1,536 dimensions using the pgvector vector type.

**Schema decided:** The `embedding` column uses `vector(1536) NOT NULL`.

**Reason:** pgvector supports vector similarity search using operators such as cosine distance. The fixed dimension ensures that every stored embedding has exactly 1,536 dimensions and can be searched efficiently using the HNSW index.

### Decision 2: ON DELETE CASCADE Decision

**Spec said:** Each chunk must reference an existing incident using a BIGINT foreign key with `ON DELETE CASCADE`.

**Schema decided:** `incident_id BIGINT NOT NULL REFERENCES incidents(id) ON DELETE CASCADE`.

**Reason:** A chunk has no meaning without its original incident. When an incident is deleted, all its related chunks are automatically deleted. This prevents orphan records and maintains referential integrity.

### Decision 3: Filter-Metadata Denormalisation Decision

**Spec said:** Each chunk must contain `team_id` and `severity` as denormalised filter metadata.

**Schema decided:** Added `team_id BIGINT NOT NULL` and `severity TEXT NOT NULL` to the `incident_chunks` table.

**Reason:** These columns support hybrid retrieval. The system can combine vector similarity search with relational filters, such as retrieving similar incidents from the same team and severity, without needing to retrieve the original incident record for every filter.

## Rejected Shape

### Shape: Single Embedding Column on incidents

**What it was:** A single `embedding TEXT` column added directly to the `incidents` table.

**Why rejected:** An incident description can contain multiple paragraphs and different topics. It should be split into smaller chunks, with a separate embedding generated for each chunk.

**What would break:** A single embedding loses chunk-level retrieval granularity. The system cannot independently retrieve the most relevant paragraph or section from a long incident description. As a result, the AI assistant may receive less relevant context instead of the specific information needed to draft a grounded summary.
