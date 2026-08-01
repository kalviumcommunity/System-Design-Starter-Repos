const express = require('express');
const app = express();

app.use(express.json());

const tasks = new Map([
  [42, {
    id: 42,
    task_ref: 'TSK-2024-001',
    title: 'Fix login form validation',
    assigned_user_id: 7,
    created_by_user_id_fk: 5,
    internal_priority_score: 87.3,
    project_id: 12,
    internal_db_version: 'v2.1.3',
    status: 'open'
  }]
]);

app.patch('/tasks/:id/complete', (req, res) => {
  const taskId = parseInt(req.params.id, 10);
  const task = tasks.get(taskId);

  if (!task) {
    return res.status(404).json({ error: 'Task not found' });
  }

  task.status = 'completed';
  task.completed_at = new Date().toISOString();

  // Versioning: legacy clients (X-API-Version: 1.0) still get the response,
  // but are told via the Deprecation header that this version is going away.
  const apiVersion = req.header('X-API-Version');
  if (apiVersion === '1.0') {
    res.set('Deprecation', 'true');
  }

  // Only public fields go out on the wire — internal DB/FK fields
  // (created_by_user_id_fk, internal_priority_score, internal_db_version)
  // are never included in the response.
  res.status(200).json({
    id: task.id,
    task_ref: task.task_ref,
    title: task.title,
    assigned_user_id: task.assigned_user_id,
    project_id: task.project_id,
    completed_at: task.completed_at
  });
});

module.exports = app;

const PORT = process.env.PORT || 3000;
if (require.main === module) {
  app.listen(PORT, () => console.log(`Helios API listening on port ${PORT}`));
}
