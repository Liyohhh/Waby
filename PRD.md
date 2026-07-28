# Waby — Product Requirements Document (PRD)

| | |
|---|---|
| **Product** | Waby |
| **Type** | Smart baby car seat safety monitoring system |
| **Platform** | Flutter mobile app (Android primary) + ESP32 seat module + Supabase backend |
| **Context** | Final-year BIT project (solo build; prioritise working safety path over polish) |
| **Version** | 1.0.0+1 |
| **Package** | Pubspec name `waby`; launcher / display name **Waby** on Android, iOS, web, desktop |
| **Repo note** | Folder may still be `seatcare_app`; **all user-facing branding is Waby** (no “SeatCare” in UI or launcher) |
| **Document status** | Reflects the current implemented app (not aspirational backlog only) |
| **Last updated** | 2026-07-27 |

---

## 1. Vision & problem

### 1.1 Problem
Every year, children are injured or die after being left alone in vehicles, often when caregivers are distracted or assume someone else will take the child. Heat inside a parked car rises quickly; an unbuckled infant can also be at risk during travel. Existing consumer solutions are fragmented (weight pads, phone reminders) and often lack escalating multi-party notification.

### 1.2 Vision
**Waby** is a caregiver-facing safety companion for an instrumented baby car seat. The seat module continuously senses presence, buckle state, temperature, caregiver proximity, and battery. The mobile app shows live status and runs an **escalating alert ladder** that ends in notifying emergency contacts via Telegram when the caregiver does not respond in time.

### 1.3 Success criteria (project)
- Live seat telemetry visible in-app within seconds of ESP32 updates.
- Authoritative danger cases (left-behind, heat) cannot be silently ignored by the product logic.
- Family-scoped data: members share devices/children; emergency contacts receive alerts without needing app accounts.
- Demo path exists for examiners (`waby.demo@waby.app`).
- App identity is consistently **Waby** (launcher name, in-app copy, notification channel titles).

---

## 2. Goals & non-goals

### 2.1 Goals
1. Monitor infant presence and seat safety indicators in near-realtime.
2. Escalate critical conditions: phone notification → on-screen countdown → Telegram to emergency contacts.
3. Let caregivers manage family membership (join code) separately from emergency contact (Telegram) recipients.
4. Support child profiles (name, DOB, weight, height, photo) linked to a seat device.
5. Persist alert events in logs for demonstration / evidence.
6. Keep caregiver identity consistent: nickname + avatar sync across Home, Settings, and Family “(me)”.

### 2.2 Non-goals (current scope)
- Production multi-tenant SaaS, billing, or App Store polish beyond a working demo.
- Per-device live telemetry rows (current `live` feed is a **single shared row** `id = 1`).
- Real Bluetooth pairing handshake (Connect flow is **simulated**; real data path is Wi‑Fi → Supabase).
- App control of on-seat LED/buzzer (those are firmware-side).
- Email-based emergency alerts (implementation is **Telegram** via `@WabyBabyBot`).
- Fully wired admin multi-user dashboard (screens exist as mock; main auth flow does not route there).
- Playing bundled alert MP3s yet (assets registered; Audible Warning toggle remains local UI until wired).

---

## 3. Users & personas

| Persona | Needs | How Waby serves them |
|---------|--------|----------------------|
| **Primary caregiver** | Live status, alerts, own profile & child records | Account owner or family member; Home + Settings + Profile |
| **Family member** | Shared view of children/devices after joining | Joins via **Family Join Code**; same family-scoped RLS data |
| **Emergency contact (next-of-kin)** | Receive urgent alerts without installing the app | Added as `contacts` row; links Telegram with a **link code** to `@WabyBabyBot` |
| **Examiner / demo** | Predictable SAFE + WARNING children | Demo account with seeded family, children, contact |

---

## 4. Product principles

1. **Safety over silence** — empty seat stays calm; danger cases escalate. Do not treat decorative UI toggles as permission to suppress detection unless explicitly wired.
2. **Acknowledge resets grace, not detection** — clearing an alert does not disable future monitoring.
3. **Members ≠ emergency contacts** — app access and Telegram recipients are separate concepts.
4. **Family-scoped data** — after auth, user must create or join a family before main app use.
5. **Brand = Waby** — navy/teal calm UI; launcher and all user-facing copy say Waby (never SeatCare).
6. **One identity** — nickname preferred for display; account avatar shared across Home header, Settings profile card, and Family “(me)” row.

---

## 5. System architecture

```
ESP32 (Wi‑Fi sensors + local LED/buzzer)
        │
        ▼
Supabase (Auth, Postgres + Realtime, Storage, Edge Functions)
        │
        ├── live          → LiveService → Home UI + AlertService
        ├── children / devices / contacts / profiles / families / logs
        ├── Storage bucket: avatars
        └── Edge Functions: send-telegram-alert, delete-account
        │
        ▼
Flutter app (StreamBuilders, local notifications, AlertScreen)
```

### 5.1 Tech stack

| Layer | Technology |
|-------|------------|
| Mobile | Flutter / Dart SDK ^3.11.1 (`pubspec` package name: `waby`) |
| Backend | Supabase (`supabase_flutter`) |
| Auth | Supabase Auth (email/password) |
| Realtime | Supabase Realtime streams on tables |
| Notifications | `flutter_local_notifications` (channel `waby_alerts`) |
| Images | `image_picker` + `image_cropper` (circular crop) |
| Assets | `assets/images/` (brand + UI), `assets/sounds/` (alert MP3s registered) |
| Firmware | ESP32 (Arduino/C++) — documented; not in this repo |
| Historical note | Early design used Firebase Realtime DB; **current app is Supabase** |

### 5.2 App folder conventions
```
lib/
  core/       theme, auth gate, app start, app state, constants, demo
  models/     Child, Contact, SeatStatus
  services/   business logic (auth, family, live, alert, …)
  screens/    full-page UI
  widgets/    reusable UI (SignedAvatar, StatusPill, InviteFamilySheet, …)
assets/
  images/     logo, illustrations
  sounds/     alert_caution.mp3, alert_critical.mp3, alert_warning.mp3
```
- Colours/fonts from `lib/core/theme.dart` (`AppColors`) — avoid hard-coded colours in widgets.
- Live data via `StreamBuilder`.
- Business logic in `services/`, not widgets.
- Shared avatar path in `AppState.avatarPath` for live UI sync after Profile edits.

---

## 6. Functional requirements

### 6.1 Authentication & onboarding

| ID | Requirement | Priority |
|----|-------------|----------|
| AUTH-1 | User can register with full name, nickname, phone, email, password (≥6), relation, country | Must |
| AUTH-2 | Registration upserts a `profiles` row tied to auth user id | Must |
| AUTH-3 | User can sign in with email/password | Must |
| AUTH-4 | Splash (~1.4s) routes to session recovery or Login | Must |
| AUTH-5 | After auth, if no `family_id`, show Create/Join family; else Main | Must |
| AUTH-6 | Display / greeting name prefers nickname → full name → `"there"` | Must |
| AUTH-7 | User can edit profile fields and avatar | Must |
| AUTH-8 | User can sign out | Must |
| AUTH-9 | User can delete account via `delete-account` edge function (type `DELETE` confirm) | Must |
| AUTH-10 | Demo credentials seed demo family/children/contact on sign-in | Should |
| AUTH-11 | Launcher / OS display name is **Waby** (Android `android:label`, iOS `CFBundleDisplayName`, etc.) | Must |

**Demo account**
- Email: `waby.demo@waby.app`
- Password: `WabyDemo123!`
- Family invite code (seeded): `BT-8942`

### 6.2 Family membership

| ID | Requirement | Priority |
|----|-------------|----------|
| FAM-1 | User can create a family (RPC `create_family`) and become owner | Must |
| FAM-2 | User can join with invite code (RPC `join_family`); codes normalised trim/uppercase | Must |
| FAM-3 | Family Join Code visible on Family page for sharing | Must |
| FAM-4 | Owner can remove members; members can leave family | Must |
| FAM-5 | If removed from family (realtime), show dialog and return to family picker | Must |
| FAM-6 | Family members list is read-only on Family tab; management in Settings | Should |
| FAM-7 | Member display prefers nickname → full name → email | Must |
| FAM-8 | Members query includes `avatar_path`; current user “(me)” avatar matches Settings/Profile (`AppState.avatarPath` fallback) | Must |

### 6.3 Emergency contacts (Telegram recipients)

| ID | Requirement | Priority |
|----|-------------|----------|
| EC-1 | Add emergency contact: name, phone, relation (does **not** create app user) | Must |
| EC-2 | List contacts with Linked / Not linked badge (`telegram_chat_id`) | Must |
| EC-3 | Unlinked contacts show `link_code` + copy + instruction to message `@WabyBabyBot` | Must |
| EC-4 | Owner can remove emergency contacts | Must |
| EC-5 | Add entry point lives under Emergency Contacts (not Family Members invite) | Must |

### 6.4 Devices & children

| ID | Requirement | Priority |
|----|-------------|----------|
| DEV-1 | Caregiver can “Add Device” from Home (pairing UI may be simulated) | Must |
| DEV-2 | Creating a device also creates a child profile (name required; DOB 1 month–12 years) | Must |
| DEV-3 | Optional weight ≤ 60 kg, height ≤ 200 cm, optional photo | Should |
| DEV-4 | Edit child: name, DOB, weight, height, photo (camera/gallery/remove) | Must |
| DEV-5 | Delete child profile deletes device (`deleteDevice`); DB cascades child row | Must |
| DEV-6 | Home shows one card per child with live status overlays | Must |

### 6.5 Live monitoring

| ID | Requirement | Priority |
|----|-------------|----------|
| LIVE-1 | App streams `live` row and maps to `SeatStatus` | Must |
| LIVE-2 | Home shows temperature, presence-derived status, buckle, near/far, battery | Must |
| LIVE-3 | Empty seat (`!present`) shows calm “SEAT EMPTY” / no baby — not red warning | Must |
| LIVE-4 | Severity priority: left-behind > heat > buckle caution > low battery > safe | Must |

**Live fields**

| Field | DB key | Meaning |
|-------|--------|---------|
| temperature | `temperature` | Seat temp °C |
| present | `present` | Infant weight/presence |
| buckled | `buckled` | Buckle latched |
| distanceNear | `distance_near` | Caregiver near seat |
| battery | `battery` | Device battery % |
| updatedAt | `updated_at` | Last update |

### 6.6 Alert & escalation (authoritative)

#### Detection rules (must not be weakened)

| Condition | Severity | AlertReason | Notes |
|-----------|----------|-------------|-------|
| `!present` | Safe / empty UI | `none` | No left-behind / heat / buckle alarms |
| `present && !distanceNear` | Warning | `leftBehind` | **Highest priority**; buckle irrelevant |
| `present && temperature > 30°C` | Warning | `heat` | Heat alarm |
| `present && !buckled && distanceNear` | Caution | `buckleReminder` | Gentle only |
| `battery < 20` | Caution | `lowBattery` | Caution only |

#### Grace (before tiered alert)

| Condition | Grace |
|-----------|-------|
| Heat | 15 seconds |
| Left-behind | 2 minutes |
| Buckle / low battery | None (one-shot notification + log) |

#### Configurable escalation window
- Stored as `profiles.alert_timer_seconds` (default **60**, UI range **30–90**).
- Left-behind total window = full timer.
- Heat total window = **half** of timer, clamped **15–90s**.

#### Critical tiers

| Tier | Window fraction | Behaviour |
|------|-----------------|-----------|
| 1 | Heat first ~20%; left-behind first ~25% | Local push “Waby Warning” + open AlertScreen |
| 2 | Until ~50% | Second push: urgent / still unresolved |
| 3 | Second half | Countdown ring on AlertScreen (“family members will be notified in…”) |
| 4 | End of window | Edge function `send-telegram-alert` with `event`, `message`, `family_id`; store `lastNotifiedCount` from response `sent` |

**Telegram event names:** `left_behind`, `heat_alarm`, `buckle_reminder`, `low_battery`.

**Post-Telegram UX**
- If `sent > 0`: “Contact Notified” with count.
- If `sent == 0`: explain no linked emergency contacts; point to Family page.

**Acknowledge**
- Clears active escalation.
- If condition still true, a **new grace period** begins (no instant re-fire).
- Critical AlertScreen is non-dismissible via back (`PopScope canPop: false`) until Acknowledge.

| ID | Requirement | Priority |
|----|-------------|----------|
| ALT-1 | Implement detection rules above exactly | Must |
| ALT-2 | Escalate critical alerts through tiers 1–4 | Must |
| ALT-3 | Caution reasons one-shot only (no Telegram ladder) | Must |
| ALT-4 | Persist alert timer setting and apply in AlertService | Must |
| ALT-5 | Log events to `logs` | Must |
| ALT-6 | Telegram / log failures must not crash alert UI | Must |
| ALT-7 | Provide test notification + test alert entry points in Settings | Should |

### 6.7 Photos & avatars

| ID | Requirement | Priority |
|----|-------------|----------|
| PIC-1 | Upload profile/child photos to private Storage bucket `avatars` | Must |
| PIC-2 | Path pattern `{family_id}/{entityType}/{entityId}.jpg` | Must |
| PIC-3 | Circular crop before upload | Should |
| PIC-4 | Display via signed URLs (cache + invalidate on change) | Must |
| PIC-5 | Profile avatar live-updates Home header and Family “(me)” via `AppState.avatarPath` | Must |
| PIC-6 | Support remove photo (null path) | Must |

### 6.8 Settings

| Control | Required behaviour |
|---------|-------------------|
| Auto-alert timer 30–90s | **Persist** to profile; refresh AlertService |
| Send test notification | Real local notification |
| Test alert screens | Fire test critical/caution paths |
| Family Management | Members + emergency contacts CRUD as above |
| Far distance 1–5 m | UI only (not sent to device) unless later wired |
| App Alerts / Vibration / Audible Warning | Local preference UI; must not override safety detection unless product explicitly wires them |
| Privacy & Data / Help & Support | Informational screens |
| Sign out / Delete account | Fully wired |

**Settings layout (UX)**
- Page background light grey `#F4F6F9` (same surface as Profile / Privacy / Help).
- Rows grouped in white cards (radius 16, soft navy shadow) with navy Poppins section labels — visual parity with Home/Family cards.
- Sections: Notifications · Distance Setting · Connectivity & Access · Support & Safety · auth actions.

---

## 7. Hardware mapping

| Sensor / output | Maps to | App behaviour |
|-----------------|---------|---------------|
| FSR (weight/presence) | `present` | Empty → idle; occupied → evaluate other rules |
| Auto-detect buckle | `buckled` | Caution when present + near + unbuckled |
| DHT11 temperature | `temperature` | Warning when present && > 30°C |
| Caregiver proximity | `distance_near` | Far + present → left-behind |
| Battery | `battery` | Caution when < 20% |
| GPS NEO-6M | (firmware / future L3 enrichment) | Child detail currently shows **mock** coords in UI |
| LED + buzzer | On-device alarm | Firmware; app does not drive them |

---

## 8. Data model (Supabase)

> Inferred from the Flutter client. RLS scopes rows to the caller’s family.

### 8.1 Tables

| Table | Purpose | Notable columns |
|-------|---------|-----------------|
| `profiles` | Caregiver account profile | `full_name`, `nickname`, `phone`, `relation`, `country`, `email`, `family_id`, `avatar_path`, `alert_timer_seconds`, `role` |
| `families` | Family unit | `invite_code`, `created_by`, name via RPC |
| `devices` | Seat devices | `name`, `photo_path`, `user_id`, `family_id` |
| `children` | Child profiles | `device_id`, `name`, `dob`, `weight_kg`, `height_cm`, `photo_path` |
| `contacts` | Emergency contacts | `name`, `phone`, `relation`, `link_code`, `telegram_chat_id`, `family_id` |
| `live` | Current sensor snapshot | `id` (=1), `temperature`, `present`, `buckled`, `distance_near`, `battery`, `updated_at` |
| `logs` | Alert event evidence | `event`, `value` (+ timestamps / family via RLS) |

### 8.2 Storage
- Bucket: `avatars` (private)
- Signed URL expiry: ~3600s in client

### 8.3 Edge functions & RPCs
- Functions: `send-telegram-alert`, `delete-account`
- RPCs: `create_family`, `join_family`, `remove_family_member`, `leave_family`

### 8.4 Known limitation
`live` is **global single-row** for the demo/project. Multi-device independent telemetry is out of current scope.

---

## 9. Information architecture & screens

### 9.1 Navigation
Bottom nav (3 tabs): **Home** · **Family** · **Settings**

### 9.2 Screen catalogue

| Screen | Purpose |
|--------|---------|
| App Start (splash) | Brand splash; route by session |
| Login | Email/password |
| Register | Create account + profile |
| Existing or New Family | Create family or enter join code |
| Main | Tab shell; alert listener; removed-from-family watch |
| Home | Live dashboard, greeting + avatar, add device, child cards (gradient wave headers) |
| Family (`ContactsScreen`) | Children (edit/delete), members (RO + synced “(me)” avatar), emergency contacts + link codes, join code |
| Settings | White-card sections: timer, tests, family management, privacy/help, auth actions |
| Profile | Edit caregiver details + avatar (updates `AppState.avatarPath`) |
| Alert | Full-screen escalating alert / countdown / notified state |
| Privacy & Data | Static privacy copy |
| Help & Support | FAQ / support |
| Admin / Admin Main | Mock admin dashboard (not in primary auth route) |

### 9.3 Key sheets
- Add Device / Connect seat
- Add Child form (within device flow)
- Child detail / Edit child
- Family Management
- Add Emergency Contact (`InviteFamilySheet`)

---

## 10. UX & design requirements

| Area | Spec |
|------|------|
| Brand | Waby butterfly (navy wings + blue dot); calm, rounded, friendly |
| Typography | Poppins via `google_fonts` |
| Colour source | `lib/core/theme.dart` — Primary navy `#0F2D54`, accent `#3B74BC`, wave header `#008FB4`→`#7AD0E4`, SAFE `#56B337`, CAUTION `#F2A33C`, WARNING `#C2291D` |
| Surfaces | Page grey `#F4F6F9` on Settings / Profile / Privacy / Help; white cards radius 16 with soft shadow |
| Patterns | Wave headers, status pills, child cards tinted by severity, navy primary buttons, section labels in navy Poppins w600 / 13 |
| Alert UI | Full-screen critical treatment; large responsive countdown ring (~78% width, clamp 260–320); non-poppable until Acknowledge |
| Empty seat | Never use warning-red styling |
| Launcher | Display name **Waby** on all target platforms |

---

## 11. Non-functional requirements

| ID | Requirement |
|----|-------------|
| NFR-1 | Prefer realtime updates (StreamBuilder) over polling for live/children/contacts |
| NFR-2 | Alert path must remain usable if Telegram or logging fails |
| NFR-3 | Auth/family bootstrap should timeout gracefully (e.g. family lookup) and not hang forever |
| NFR-4 | Images compressed (quality ~85, max ~1024) before upload |
| NFR-5 | Android notifications permission requested as part of alert init |
| NFR-6 | Null-safe Dart; `flutter analyze` clean for release candidates |
| NFR-7 | Bundled assets declared in `pubspec.yaml` (`assets/images/`, `assets/sounds/`) |

---

## 12. Safety policy (acceptance invariants)

These are **product acceptance tests**, not suggestions:

1. No presence → no left-behind / heat / buckle critical path.
2. Presence + caregiver far → left-behind warning **regardless of buckle**.
3. Presence + temperature > 30°C → heat warning.
4. Presence + near + unbuckled → buckle **caution** only (no Telegram ladder).
5. Battery < 20% → caution only.
6. Critical path: grace → L1 push → L2 urgent → L3 countdown → Telegram.
7. Acknowledge clears current escalation but does not disable future detection.
8. Logging/Telegram errors are non-fatal.
9. UI-only settings must not silently disable danger detection unless a future PRD revision explicitly wires and documents that behaviour.

---

## 13. Demo & testing requirements

| Item | Detail |
|------|--------|
| Demo login | `waby.demo@waby.app` / `WabyDemo123!` |
| Seeded children | Jason Tan (SAFE overlay), Nur Alysha (WARNING overlay) when demo display applies |
| Seeded contact | Ahmad Tan (Father) |
| Settings | “Send Test Notification” and “Test Alert Screens” for examiner walkthrough |
| Logs | One row per alert event for viva / evidence |
| Brand check | Home-screen launcher shows **Waby**; in-app titles/notifications say Waby |

---

## 14. Explicit mocks & technical debt (document honestly)

| Area | Current state |
|------|----------------|
| Device pairing | Simulated delay (~1.5s); no real BT/Wi‑Fi handshake in app |
| Live telemetry | Single `live` row (`id = 1`) shared across UI |
| Far-distance slider | Local UI only |
| Vibration / Audible Warning toggles | Local UI only |
| Alert sound assets | `assets/sounds/alert_{caution,critical,warning}.mp3` registered in pubspec; **not yet played** by AlertService |
| Child detail temperature / GPS / graph | Partially mock (e.g. fixed temp/coords; graph illustrative) |
| Admin screens | Present but not in main auth routing |
| Privacy copy | May still mention email-style alerts; runtime is Telegram |
| Firmware | Separate from this repo |
| Cursor project-overview rule | May still mention Firebase; prefer this PRD + README for stack |

---

## 15. Out-of-scope future enhancements (backlog ideas)

Not required for current delivery, but natural next steps:

- Per-device `live` rows keyed by `device_id`
- Real pairing / device claiming with ESP32 identity
- Wire Audible Warning / Vibration to play `assets/sounds/` (and/or firmware) intentionally
- Wire distance preference toggles to firmware or alert service intentionally
- Include GPS coordinates in Telegram payload
- Multi-child independent alert contexts
- Production admin tooling and audit trails
- iOS release hardening parity with Android

---

## 16. Glossary

| Term | Meaning |
|------|---------|
| **Family member** | App user who shares family-scoped data via join code |
| **Emergency contact** | Telegram recipient; no app login required |
| **Link code** | Code a contact sends to `@WabyBabyBot` to bind `telegram_chat_id` |
| **Left-behind** | Infant present and caregiver far |
| **Heat alarm** | Infant present and temperature above threshold |
| **Grace** | Quiet wait before escalating a critical condition |
| **Tier** | Stage in the critical escalation ladder |
| **(me)** | Current signed-in user row on Family members list |

---

## 17. Document control

| Field | Value |
|-------|-------|
| Source of truth | Implemented Flutter app + Supabase client usage |
| Related brand rules | `.cursor/rules/design-system.mdc`, `lib/core/theme.dart` |
| Historical note | `.cursor/rules/project-overview.mdc` may still mention Firebase; prefer this PRD + README for stack |
| Owner | Project author (solo FYP) |
| Revision | 2026-07-27 — branding Waby launcher-wide; Settings card UX; avatar/nickname sync; sound assets registered |

---

*End of PRD — Waby v1*
