const request = require('supertest');
const app = require('../index');

describe('MVP routes — must return 200', () => {
  test('GET /fleet/trucks returns 200', async () => {
    const res = await request(app).get('/fleet/trucks');
    expect(res.status).toBe(200);
  });

  test('GET /drivers/1 returns 200', async () => {
    const res = await request(app).get('/drivers/1');
    expect(res.status).toBe(200);
  });

  test('POST /drivers/1/approve returns 200', async () => {
    const res = await request(app)
      .post('/drivers/1/approve')
      .send({});

    expect(res.status).toBe(200);
  });

  test('GET /alerts returns 200', async () => {
    const res = await request(app).get('/alerts');
    expect(res.status).toBe(200);
  });

  test('POST /alerts/webhook returns 200', async () => {
    const res = await request(app)
      .post('/alerts/webhook')
      .send({
        truck_id: 'T-001',
        breach_type: 'geofence'
      });

    expect(res.status).toBe(200);
  });
});

describe('Scope-creep routes — must return 404 after deletion', () => {
  test('GET /chat returns 404', async () => {
    const res = await request(app).get('/chat');
    expect(res.status).toBe(404);
  });

  test('GET /fuel/costs returns 404', async () => {
    const res = await request(app).get('/fuel/costs');
    expect(res.status).toBe(404);
  });

  test('GET /offline/sync returns 404', async () => {
    const res = await request(app).get('/offline/sync');
    expect(res.status).toBe(404);
  });

  test('GET /theme returns 404', async () => {
    const res = await request(app).get('/theme');
    expect(res.status).toBe(404);
  });
});