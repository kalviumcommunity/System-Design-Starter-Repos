# AI Integration Proof Slice — Severity Suggestion

## What this project does

This proof slice demonstrates a safe AI-assisted workflow for incident severity handling. An AI model can suggest a severity, but the application only uses the suggestion if it passes validation. If the response is invalid or unavailable, the workflow falls back to manual review instead of changing the real incident data.

The flow is intentionally simple and focuses on four important safeguards:

- a clear boundary between the model and the real incident record
- validation of the AI output before use
- a fallback path when the model fails
- human approval before any real change is applied

## Current behavior

The script in [index.js](index.js) now:

- builds a safe context for the model using only non-sensitive fields
- validates that the suggested severity is one of the allowed values and that a reason is provided
- returns a manual-review fallback when the model output is missing or invalid
- keeps the real incident severity unchanged until human approval

## Run it

```bash
node index.js
```

No install or API key is required. The model is simulated locally in [index.js](index.js).

## Test modes

Change the `MODE` constant near the top of [index.js](index.js) to try each path:

- `valid` — returns a good response and proceeds with the human-approval flow
- `badEnum` — returns an invalid severity and triggers the fallback
- `failed` — returns no response and triggers the fallback

## Expected outcomes

- With `MODE = 'valid'`, the app suggests a severity and the real severity changes only after approval.
- With `MODE = 'badEnum'` or `MODE = 'failed'`, the app ends in `MANUAL_REVIEW` and leaves the real severity unchanged.
