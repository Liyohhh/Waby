# Waby — Integration API

| | |
|---|---|
| **Supabase project** | `pvafygrloelptlmnhfog` |
| **Surfaces** | Firmware REST · Edge Functions · App Realtime / RPC |
| **Last updated** | 2026-08-09 |

Companion: `docs/DATABASE.md` (tables, RLS, RPCs).

---

## 1. Firmware → Supabase (`live`)

**Source:** `Project_1_draft_v3.ino` → `sendLiveUpdate()`.

| Item | Value |
|------|--------|
| Method | `PATCH` |
| Path | `/rest/v1/live?id=eq.1` (`LIVE_ROW_ID`) |
| Cadence | ~1 Hz (loop pushes when `millis() - lastLivePushMs >= 1000`) |
| Auth headers | `apikey` + `Authorization: Bearer` (firmware key) |
| Content-Type | `application/json` |
| Prefer | `return=minimal` |

### JSON body fields

| Field | When sent | Notes from firmware |
|-------|-----------|---------------------|
| `temperature` | Always | `0.0` if `!tempValid`; else last good DHT reading (1 decimal) |
| `present` | Always | `true` / `false` from hysteretic presence |
| `buckled` | Always | Buckle LOW = locked |
| `distance_near` | Always | Currently hardcoded `true` (proximity placeholder) |
| `car_moving` | Always | GPS speed above motion threshold |
| `battery` | Always | Calibrated 0–100 % |
| `latitude` | Always | `0.0` if no GPS fix |
| `longitude` | Always | `0.0` if no GPS fix |
| `gps_accuracy_m` | If `gps.hdop.isValid()` | `hdop.value() / 100.0` |
| `place_name` | If reverse-geocode cache ready | Double-quotes escaped to `'` |

### Prefer / HTTP 204 gotcha

With `Prefer: return=minimal`, a successful PATCH that matches **zero rows** still returns **HTTP 204**. Serial `Supabase PATCH HTTP 204` does **not** prove `id = 1` was updated — only that the request was accepted. Verify against the `live` row in the dashboard or the Flutter stream.

---

## 2. Edge Functions

### `send-telegram-alert`

Invoked from `AlertService._escalate()` when the escalation window ends (and by the server-side `check_alert_escalations` path).

**Request body** (fields omitted when null/empty in the Dart client):

| Key | Type | Source |
|-----|------|--------|
| `event` | string | `left_behind` / `heat_alarm` / `buckle_reminder` / `low_battery` |
| `family_id` | string | Caller's family |
| `child_name` | string | Active alert child |
| `car_name` | string? | Active car name |
| `car_plate` | string? | Active car plate |
| `temperature_c` | number? | From `live.temperature` when reason is heat |
| `latitude` | number? | From `live` |
| `longitude` | number? | From `live` |
| `gps_accuracy_m` | number? | From `live` |
| `place_name` | string? | From `live` |
| `last_seen` | string? | `live.updated_at` |
| `message` | string | Alert message |

**Response:** `{ sent: <int> }` — count of Telegram deliveries; stored as `lastNotifiedCount` on the active alert.

Failures are non-fatal in the app (caught; UI still usable).

### `telegram-webhook`

Bot webhook for emergency-contact linking.

- Contact sends their `link_code` to `@WabyBabyBot`.
- Webhook binds `contacts.telegram_chat_id`.
- Already-linked contacts receive a reassurance reply (no duplicate bind).

### Other

| Function | Purpose |
|----------|---------|
| `delete-account` | Account deletion (Settings confirm `DELETE`) |

---

## 3. App ↔ Supabase

### Realtime — `live`

**Source:** `LiveService.liveStream()`.

```
from('live').stream(primaryKey: ['id']).eq('id', 1)
  → SeatStatus.fromMap(row) | SeatStatus.empty()
```

Consumed by Home UI and `AlertService` (presence, heat, buckle, battery, GPS fields).

### Alert persistence

| Table | Client action |
|-------|----------------|
| `logs` | `INSERT` `{ event, value }` on alert activity |
| `alert_events` | `INSERT` on activate; `UPDATE escalated_at` / `resolved_at` as the ladder progresses |

### Family RPCs

Documented in `docs/DATABASE.md`. Client entry points in `FamilyService`:

| Method | RPC |
|--------|-----|
| `createFamily` | `create_family` |
| `lookupFamilyByCode` | `lookup_family_by_code` |
| `joinFamily` | `join_family` |
| `setActiveCar` | `set_active_car` |
| `leaveFamily` | `leave_family` |
| `removeFamilyMember` | `remove_family_member` |

### CRUD (RLS-scoped)

| Service | Tables |
|---------|--------|
| `ContactService` | `contacts` |
| `CarService` | `cars` |
| `DeviceService` / child services | `devices`, `children` |
| Profile / Settings | `profiles` |

---

## Maintenance notes

When `sendLiveUpdate()` body fields, Edge Function payloads, or service call contracts change, update this document in the same change.
