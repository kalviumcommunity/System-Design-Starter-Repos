# Growlog — Trace & Fix

The handler in `handlers/getReport.js` was awaiting a notification call before sending its response — logic the sequence diagram never showed and which coupled report-fetching to logging. The fix moves `notifier.sendAccessLog` into a new `middleware/accessLogger.js` that fires on `res.on('finish')`, so it runs after the response is sent and only for successful (200) requests.
