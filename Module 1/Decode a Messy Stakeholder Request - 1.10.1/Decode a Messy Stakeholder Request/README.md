# Raftly — Bonus Exercise Provided Repo

## What's in Here

- **`requirements-request.md`** (in `../`) — the raw PM Slack message. Read this first.
- **`index.js`** — an Express server that implements everything the PM asked for. Some routes belong. Some don't.
- **`tests/routes.test.js`** — scaffold test file. You complete this.
- **`package.json`** — dependencies (express, jest, supertest).

---

## Your Four Deliverables (branch: `decode-and-repair`)

1. **`sort-note.md`** — 4-bucket categorised list, **under 80 words**. Use this template:

```
Scope: [item], [item], ...
Creep: [item] — one-line reason; [item] — one-line reason
Assumptions: [item] — what needs clarifying
Questions: [item] — why it blocks design
```

One line per item. Cite exact phrases from the PM message.

2. **`index.js`** — delete the scope-creep routes. The 5 MVP routes must remain.
3. **`tests/routes.test.js`** — fill in the test assertions. `npm test` must pass.
4. **`README.md`** — 1-2 sentences on what signals told you something was scope vs. creep.

---

## Getting Started

```bash
npm install
node index.js          # start the server
npm test               # run the tests (they will fail until you fix index.js and complete the tests)
```

Read `requirements-request.md` before touching any code — that message is the source of truth for which routes belong and which don't.

---

## Approach and Scope Signals

Core scope was identified by definitive operational commitments necessary for real-time dispatch and driver management (telematics map tracking, driver ratings, incident logs, CEO approvals, and geofence breach alerts). Scope creep was signaled by speculative language ("maybe", "I think", "would be nice") introducing unvetted subsystems (chat, offline sync, fuel analytics, dark mode) outside the bounded 6-week MVP.
