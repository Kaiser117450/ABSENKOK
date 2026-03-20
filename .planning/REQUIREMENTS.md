# Milestone v6.0 Requirements

## 1. Multi-Device Health
- [ ] **HEALTH-01**: System generates and persists a unique Device ID per installation (UUIDv4).
- [ ] **HEALTH-02**: Kiosk syncs heartbeat metrics to a dedicated `kiosk_devices` table instead of `outlets`.
- [ ] **HEALTH-03**: Admin Dashboard displays health status for all connected devices within an outlet.
- [ ] **HEALTH-04**: Admins can manually unlink/remove retired devices from the dashboard.
- [ ] **HEALTH-05**: Admins can assign custom nicknames to devices (e.g., "Kiosk Pintu Depan").

## 2. Multi-Outlet Control Center
- [ ] **ADMIN-01**: Admin Central Dashboard aggregates and displays health/status for ALL outlets in one view.
- [ ] **ADMIN-02**: Admin Central Dashboard displays aggregate firm-wide daily attendance rate.

## Traceability
- **HEALTH-01** → Phase 31
- **HEALTH-02** → Phase 31
- **HEALTH-03** → Phase 32
- **HEALTH-04** → Phase 32
- **HEALTH-05** → Phase 32
- **ADMIN-01**  → Phase 33
- **ADMIN-02**  → Phase 33
