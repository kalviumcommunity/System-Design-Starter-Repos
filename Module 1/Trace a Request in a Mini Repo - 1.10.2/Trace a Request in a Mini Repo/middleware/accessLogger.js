const notifier = require('../services/notifier');

// Access Logger Middleware
// Runs the handler first (next()), then logs access AFTER the response
// has actually been sent to the client, via the 'finish' event on res.
// Only logs successful (200) reads — not 401/403/404 failures.

function accessLogger(req, res, next) {
  res.on('finish', () => {
    if (res.statusCode === 200) {
      const reportId = parseInt(req.params.id, 10);
      const userId = req.user && req.user.user_id;

      notifier.sendAccessLog({
        user_id: userId,
        report_id: reportId,
        timestamp: new Date().toISOString(),
        action: 'accessed'
      }).catch((err) => {
        console.error('Notification failed:', err.message);
      });
    }
  });

  next();
}

module.exports = { accessLogger };
