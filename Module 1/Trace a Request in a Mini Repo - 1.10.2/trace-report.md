Entry: index.js:29 — route matches GET /reports/:id, params.id extracted
Middleware: middleware/auth.js:5-34 — checks Bearer token against mockCache.sessions, attaches req.user
Handler: handlers/getReport.js:5-39 — fetches report, checks ownership, returns JSON
Response: 200 / 401 / 403 / 404
Drift: handlers/getReport.js (former line 40) — handler called notifier.sendAccessLog before responding
Consequence: notification delay/failure blocks or slows the client response; handler carries two responsibilities
LU violated: LU 1.5 — single-responsibility handler design
