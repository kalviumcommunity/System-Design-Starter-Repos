# Incident Retrieval Schema Repair

This project implements retrieval storage for an incident-management
platform using PostgreSQL and pgvector.

## Retrieval-Model Decisions

### Decision 1: Vector Embedding Storage

Spec said: Each incident chunk must store a 1,536-dimension embedding.

Schema decided: The `incident_chunks` table uses
`embedding vector(1536) NOT NULL`.

Reason: pgvector supports similarity searches directly on embeddings.
Storing vectors per chunk allows long incident descriptions to be
split into smaller searchable units.

### Decision 2: ON DELETE CASCADE

Spec said: Every chunk must reference an existing incident and must
be removed when its incident is deleted.

Schema decided: `incident_id BIGINT NOT NULL REFERENCES incidents(id)
ON DELETE CASCADE`.

Reason: Chunks are derived data and have no independent meaning
without their source incident. CASCADE prevents orphaned chunks.

### Decision 3: Filter Metadata Denormalisation

Spec said: Retrieval must support relational filtering by team and
severity.

Schema decided: `team_id BIGINT NOT NULL` and `severity TEXT NOT NULL`
are stored in each chunk.

Reason: Copied metadata allows similarity searches to filter by team
and severity without joining the incidents table for every search.
The values must be kept synchronized with the source incident.

## Rejected Shape

### Shape: Single Embedding Column on incidents

What it was: A single `embedding TEXT` column added directly to
the incidents table.

Why rejected: An incident description can contain multiple
paragraphs and different topics. One embedding cannot preserve
the retrieval granularity provided by multiple independently
embedded chunks.

What would break: Chunk-level similarity search would be impossible.
Relevant passages could not be retrieved independently, reducing
search precision and making grounded incident summaries less useful.
