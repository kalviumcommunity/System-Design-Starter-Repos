# Growlog — Trace and Fix

`handlers/getReport.js` was calling `notifier.sendAccessLog(...)` directly inside the request handler, before sending the response — a step the original sequence diagram never showed and one that violates single-responsibility by mixing report retrieval with access logging.

Fixed by moving the notification call into a new `middleware/accessLogger.js`, which runs after `res.on('finish')` fires (i.e. after the response is already sent) and only logs on `200 OK`, matching the diagram and decoupling the two concerns.
