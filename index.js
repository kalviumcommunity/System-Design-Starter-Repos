/**
 * LU32 — AI Integration Proof Slice (STARTER)
 * ------------------------------------------------------------
 * The AI SUGGESTS an incident severity. Your code CHECKS the answer.
 * If the answer is bad, a FALLBACK keeps things working.
 * The real severity only changes when a human APPROVES.
 *
 * Run it:  node index.js
 * No install, no API key. The "model" is a fake function below.
 *
 * You only fill in 3 tiny functions. Everything else is done for you.
 */

// ── The data (your "database"). The AI must NOT change `currentSeverity`. ──
const incident = {
  id: 'INC-482',
  title: 'Checkout latency spike after deploy v18.4',
  currentSeverity: 'MEDIUM',
  service: 'payments',
  reporterEmail: 'oncall@acme.example',   // private — do NOT send to the model
  internalToken: 'tok_secret_do_not_send' // private — do NOT send to the model
};
const timeline = [
  'Deploy v18.4 completed for payments',
  'Error rate rising in payments-checkout',
  'Retry queue depth increasing'
];

const SEVERITIES = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];

// ── A fake "model". Change MODE to try each case. ──
// 'valid'  -> a good answer
// 'badEnum'-> an unknown severity ("URGENT")
// 'failed' -> the model failed (returns null)
const MODE = 'valid';
function fakeModel() {
  if (MODE === 'failed') return null;
  if (MODE === 'badEnum') return { suggestedSeverity: 'URGENT', reason: 'errors rising' };
  return { suggestedSeverity: 'HIGH', reason: 'errors rising after v18.4' };
}

// ============================================================
// TASK 1 — What is the model allowed to see?
// Return an object with only the safe fields (no secrets).
// ============================================================
function buildContext() {
  return {
    id: incident.id,
    title: incident.title,
    currentSeverity: incident.currentSeverity,
    service: incident.service,
    timeline: [...timeline]
  };
}

// ============================================================
// TASK 2 — Is the answer safe to use?
// Return true only if suggestedSeverity is one of SEVERITIES
// AND there is a non-empty reason.
// ============================================================
function isValid(answer) {
  if (!answer || typeof answer !== 'object') return false;
  if (!SEVERITIES.includes(answer.suggestedSeverity)) return false;
  return typeof answer.reason === 'string' && answer.reason.trim().length > 0;
}

// ============================================================
// TASK 3 — What does the user see when the model fails or is invalid?
// Return a short message so the workflow still makes sense.
// ============================================================
function fallback() {
  return {
    status: 'MANUAL_REVIEW',
    message: `AI severity suggestion unavailable for ${incident.id}. Severity stays ${incident.currentSeverity} — set it manually.`
  };
}

// ── Given to you: runs one request start to finish. ──
function run() {
  console.log('Context sent to model:', buildContext());

  const answer = fakeModel();

  if (!answer || !isValid(answer)) {
    console.log('Result:', fallback());
    return;
  }

  console.log('AI suggests:', answer.suggestedSeverity, '(not applied yet)');
  console.log('Real severity is still:', incident.currentSeverity);

  // A human approves — the only place the real value changes:
  incident.currentSeverity = answer.suggestedSeverity;
  console.log('After human approval:', incident.currentSeverity);
}

run();
