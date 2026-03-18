# REQUIREMENTS.md — v3.1 Biometric Login + Badge Polish + Release

## v3.1 Requirements

### Biometric Login (AUTH)
- [x] **AUTH-01**: Admin/kepala gerai can unlock the app using fingerprint or face recognition after first successful login
- [x] **AUTH-02**: App falls back to email/password form if biometric fails, is cancelled, or is unavailable
- [x] **AUTH-03**: User can toggle "Remember me" to enable/disable biometric login on the device
- [x] **AUTH-04**: App auto-detects biometric capability and skips biometric setup if no sensor is available

### Badge Color Picker (BADGE)
- [ ] **BADGE-01**: Admin can pick badge border color using a visual color wheel/grid instead of typing hex
- [ ] **BADGE-02**: Admin can pick both color1 and color2 for gradient badge styles
- [ ] **BADGE-03**: Admin sees a live badge preview while selecting colors

### Production Release (REL)
- [ ] **REL-01**: Build production-ready release APK with obfuscation and ProGuard
- [ ] **REL-02**: Publish APK to GitHub Releases with version tag v3.1

## Future Requirements (Deferred)
- Preset color palette (12-16 curated brand colors) — nice-to-have for future
- Schedule grid tap-to-cycle shift (GRID-D1)
- Schedule grid copy-week (GRID-D2)
- Schedule grid today-column highlight (GRID-D3)
- Time-off request approval workflow
- Keterlambatan (late arrival) automatic flagging
- Overtime tracking
- Push notification for missing clock-out
- Attendance rate card on admin dashboard

## Out of Scope
- iOS build — Android-only kiosk, no iOS target
- PIN code login — biometric covers fast re-auth
- Cloud-synced biometric — device-local only, standard Android biometric API
- Color picker preset palette — deferred, visual picker is sufficient

## Traceability

| REQ-ID | Phase | Status |
|--------|-------|--------|
| AUTH-01 | Phase 20 | Complete |
| AUTH-02 | Phase 20 | Complete |
| AUTH-03 | Phase 20 | Complete |
| AUTH-04 | Phase 20 | Complete |
| BADGE-01 | Phase 21 | Pending |
| BADGE-02 | Phase 21 | Pending |
| BADGE-03 | Phase 21 | Pending |
| REL-01 | Phase 22 | Pending |
| REL-02 | Phase 22 | Pending |
