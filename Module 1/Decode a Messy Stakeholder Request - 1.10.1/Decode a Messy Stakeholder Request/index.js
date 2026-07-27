const express = require('express');
const app = express();

app.use(express.json());

// 1. List all active truck locations (updated every 30 sec by telematics)
app.get('/fleet/trucks', (req, res) => {
  res.json({
    trucks: [
      { id: 'T-001', lat: 37.77, lng: -122.41, driver: 'Alice Mehta', updated_at: new Date().toISOString() },
      { id: 'T-002', lat: 37.79, lng: -122.43, driver: 'Bob Rajan', updated_at: new Date().toISOString() }
    ]
  });
});

// 2. Get a driver's profile: rating + last 3 incidents
app.get('/drivers/:id', (req, res) => {
  res.json({
    id: req.params.id,
    name: 'Alice Mehta',
    rating: 4.7,
    incidents: [
      { date: '2024-03-01', type: 'Late delivery', status: 'resolved' }
    ]
  });
});

// 3. Approve a pending new driver
app.post('/drivers/:id/approve', (req, res) => {
  res.json({
    id: req.params.id,
    status: 'approved',
    approved_at: new Date().toISOString()
  });
});

// 4. Get off-route alert configuration (geofence settings)
app.get('/alerts', (req, res) => {
  res.json({
    geofence_radius_km: 2,
    notification_target: 'dispatcher',
    check_interval_seconds: 30
  });
});

// 5. Receive geofence breach webhook from telematics provider
app.post('/alerts/webhook', (req, res) => {
  const { truck_id, breach_type } = req.body;
  res.json({ received: true, truck_id, breach_type, logged_at: new Date().toISOString() });
});


module.exports = app;
