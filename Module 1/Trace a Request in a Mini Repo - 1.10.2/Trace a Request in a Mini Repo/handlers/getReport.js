// Handler for GET /reports/:id
// Fetches the report, checks ownership, and returns the response.
// Access logging is handled by middleware/accessLogger.js, not here.

async function getReport(req, res) {
  const reportId = parseInt(req.params.id, 10);
  const userId = req.user.user_id;

  // Step 1: Fetch report from database
  const report = global.mockDB.reports.get(reportId);

  if (!report) {
    return res.status(404).json({
      error: {
        code: 'not_found',
        message: `Report ${reportId} not found`
      }
    });
  }

  // Step 2: Check ownership
  if (report.owner_id !== userId) {
    return res.status(403).json({
      error: {
        code: 'forbidden',
        message: 'You do not have access to this report'
      }
    });
  }

  // Step 3: Return the report
  res.status(200).json({
    id: report.id,
    title: report.title,
    data: report.data,
    accessed_by: req.user.email,
    accessed_at: new Date().toISOString()
  });
}

module.exports = getReport;
