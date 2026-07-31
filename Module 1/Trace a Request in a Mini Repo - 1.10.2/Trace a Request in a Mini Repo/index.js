const express = require('express');
const { authenticate } = require('./middleware/auth');
const { accessLogger } = require('./middleware/accessLogger');
const reportHandler = require('./handlers/getReport');
const { v4: uuidv4 } = require('uuid');

const app = express();

// Mock in-memory databases
global.mockDB = {
  reports: new Map([
    [1, { id: 1, title: 'Q1 Revenue', data: 'Revenue: $500k', owner_id: 'user-1' }],
    [2, { id: 2, title: 'Q1 Engagement', data: 'Engagement: 42%', owner_id: 'user-2' }],
  ]),
  notificationLog: []
};

global.mockCache = {
  sessions: new Map([
    ['token-valid-123', { user_id: 'user-1', email: 'alice@growlog.io' }],
    ['token-valid-456', { user_id: 'user-2', email: 'bob@growlog.io' }]
  ])
};

app.use(express.json());

// Route for GET /reports/:id
// Entry point: uses middleware, then handler
app.get('/reports/:id', authenticate, accessLogger, reportHandler);

// Simple health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

module.exports = app;

const PORT = process.env.PORT || 3000;
if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Growlog API listening on port ${PORT}`);
    console.log(`Try: curl -H "Authorization: Bearer token-valid-123" http://localhost:3000/reports/1`);
  });
}
