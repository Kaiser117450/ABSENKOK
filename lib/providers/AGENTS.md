# AGENTS.md

> Parent: [../AGENTS.md](../AGENTS.md)

## Purpose

Riverpod state management layer. Centralized application state for session, authentication mode, loading state, and outlet selection.

## Key Files

| File | Description |
|---|---|
| `app_provider.dart` | `AppProvider` — manages session state, admin/kiosk mode, loading state, outlet selection, NFC status |

## For AI Agents

### Critical: ANR Prevention

- **`loadSession()`** MUST set `isLoading: false` in a `finally` block — never leave loading state stuck or the app hangs permanently.
- `app.dart` has a **5-second safety timeout** that calls `forceUnblockLoading()` as a last resort if loading never completes.
- Uses **`SharedPreferences`** for kiosk session persistence. **NEVER** use `FlutterSecureStorage` — it causes ANR on certain devices.

### State Shape

- `isLoading` — true during session load, blocks UI rendering.
- `isAdmin` — admin mode vs kiosk mode toggle.
- `currentOutlet` — selected outlet for kiosk operation.
- `kioskSession` — active kiosk session data (persisted via SharedPreferences).
- Session load flow: SharedPreferences read -> Supabase auth check -> state hydration -> `isLoading: false`.
