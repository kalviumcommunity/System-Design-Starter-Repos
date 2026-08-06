# Retrieval Schema Repair

## Retrieval-Model Decisions

### Decision 1: Embedding storage decision

Spec said:
Each text chunk should store its own embedding as `vector(1536)`.

Schema decided:
Stored embeddings in `incident_chunks.embedding` using the `vector(1536)` type.

Reason:
Each incident is split into multiple chunks, and every chunk needs its own embedding for accurate vector similarity search.

---

### Decision 2: ON DELETE decision

Spec said:
Chunks have no meaning without their parent incident.

Schema decided:
Used

```sql
REFERENCES incidents(id) ON DELETE CASCADE
```

Reason:
Deleting an incident automatically removes its associated chunks, preventing orphaned retrieval data.

---

### Decision 3: Filter metadata / denormalisation decision

Spec said:
Store `team_id` and `severity` in `incident_chunks`.

Schema decided:
Added `team_id BIGINT NOT NULL` and `severity TEXT NOT NULL`.

Reason:
These fields allow relational filtering alongside vector similarity search without joining back to the incidents table.

## Rejected Shape

### Shape: Single embedding column on incidents

What it was:
A single `embedding` column was added directly to the `incidents` table.

Why rejected:
Incident descriptions can be long and must be split into multiple chunks before embedding.

What would break:
A single embedding loses chunk-level retrieval granularity. Different sections of a long incident cannot be matched independently, reducing retrieval accuracy and preventing effective chunk-based similarity search.