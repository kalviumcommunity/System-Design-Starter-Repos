Entry:      index.js:28 — GET /reports/:id matched, id param extracted.
Middleware: middleware/auth.js:5 — validates Bearer token, attaches req.user.
Handler:    handlers/getReport.js:5 — fetches report, checks ownership, returns JSON.
Response:   200 / 401 / 403 / 404

Drift:      handlers/getReport.js:40 (original) — handler called notifier.sendAccessLog before responding.
Consequence: Logging failures could delay or break report responses, coupling an unrelated concern to the read path.
LU violated: LU 1.5 — Single Responsibility
