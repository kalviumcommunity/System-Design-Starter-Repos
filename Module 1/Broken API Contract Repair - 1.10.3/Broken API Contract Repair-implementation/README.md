# Helios — Broken Contract Repair

I compared `contract.yaml` and `index.js` line-by-line against HTTP method semantics, information-hiding, and API-evolution principles from LU 1.7/1.8, which surfaced a mutating `GET`, three internal/DB-only fields leaking into the public response, and no versioning mechanism to signal that leak's eventual removal. See `defence-note.md` for the fix and rejected alternative per violation.
