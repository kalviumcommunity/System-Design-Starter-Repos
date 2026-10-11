# Raftly Fleet Dispatch Platform — System Promise

## 1. Scope (Surviving MVP)
- Real-time fleet location visibility via telematics coordinates (`GET /fleet/trucks`).
- Driver profiles displaying rating and recent incident logs (`GET /drivers/:id`).
- Driver approval workflow allowing direct dashboard authorization by the CEO (`POST /drivers/:id/approve`).
- Route deviation alert configuration and webhook ingestion for geofence breaches (`GET /alerts`, `POST /alerts/webhook`).

## 2. Out of Scope (Deferred Scope Creep)
- Driver-to-dispatcher instant chat subsystem (`/chat`).
- Offline synchronization and local data persistence (`/offline/sync`).
- Per-vehicle fuel cost tracking and analytics (`/fuel/costs`).
- Dark mode theme toggling (`/theme`).

## 3. Critical Unknowns
- **Mapping Provider**: Google Maps vs. Mapbox SDK selection, API costs, licensing, and rate limits.
- **Client Strategy**: Confirmation that mobile access means responsive web app, not dedicated iOS/Android apps for the 6-week deadline.
- **Service Level Agreements**: Explicit performance SLAs (telematics poll interval: 30s; latency: p95 < 200ms; uptime: 99.9%).

## 4. System Boundaries
- **Telematics Ingestion**: Truck coordinates updated via 30-second telematics polling interval.
- **Driver State Management**: Driver lifecycle transitions directly from pending to approved upon CEO approval.
- **Breach Ingestion**: Geofence alerts ingested synchronously via provider webhook.
