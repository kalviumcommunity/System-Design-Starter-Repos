# Repair Note — 4-Bucket Requirements Sort

## 1. Legitimate Scope
- `"see all trucks in real-time on a map"` — Core fleet tracking dashboard capability.
- `"driver ratings and incident history"` — Essential driver quality monitoring metrics.
- `"approve each new driver directly from the dashboard"` — Replacing slow Jira process for CEO authorization workflow.
- `"push notifications when trucks go off-route"` — Critical operational route breach and geofence alerting.

## 2. Scope Creep
- `"driver-to-dispatcher chat"` — Unnecessary real-time communication subsystem; adds massive messaging infrastructure outside core dispatch tracking.
- `"work offline too"` — Contradicts the real-time telematics tracking premise; introduces high data-synchronization complexity unsuitable for a 6-week MVP.
- `"track fuel costs per vehicle"` — Secondary financial and accounting metric unnecessary for real-time dispatch and driver authorization.
- `"dark mode"` — Non-essential cosmetic styling offering zero operational utility for MVP delivery.

## 3. Assumptions
- `"must work on mobile"` — Assumes responsive web dashboard rather than building separate native iOS and Android applications in 6 weeks.
- `"really fast and reliable"` — Unquantified non-functional requirement; requires explicit latency (p95 < 200ms) and availability (99.9% uptime) targets.

## 4. Open Questions
- `"Google Maps or Mapbox"` — Critical design blocker: Which mapping SDK, licensing model, rate limits, and map tile rendering stack to integrate.
