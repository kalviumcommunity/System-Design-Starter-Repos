const notifier = require('../services/notifier');

// Access logging middleware for GET /reports/:id
// Runs the handler first (next()), then fires the access log AFTER the
// response has been sent to the client, via the 'finish' event.
// Only logs successful (200) accesses — 401/403/404 are not "accessed".

function accessLogger(req, res, next) {
  res.on('finish', () => {
    if (res.statusCode === 200) {
      const reportId = parseInt(req.params.id, 10);
      const userId = req.user && req.user.user_id;

      notifier
        .sendAccessLog({
          user_id: userId,
          report_id: reportId,
          timestamp: new Date().toISOString(),
          action: 'accessed'
        })
        .catch((err) => {
          console.error('Notification failed:', err.message);
        });
    }
  });

  next();
}

module.exports = { accessLogger };
