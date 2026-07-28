# Testing Log

## BUG-001
- Date: 2026-07-28
- Area: Multi-alert escalation / alert countdown UI
- Root cause: The old single-alert data model only tracked one global alert and one global start time, so countdown state could not remain independent per alert when multiple alerts were active.
- Fix: Refactored `AlertService` to own a list of active alerts keyed by `alertId`, moved the alert UI to a shared bottom sheet with horizontal paging, and derived countdown state per alert from `startedAt` + wall clock.

## TEST-001
- Date: 2026-07-28
- Scope: Multi-alert bottom sheet behavior
- Verified:
  - Caution sheet can be dismissed with the vertical handle gesture.
  - Warning / critical sheets do not dismiss via drag or back gesture.
  - Horizontal swipe between stacked alerts preserves each alert's independent countdown based on its own `startedAt`.
  - A new alert arriving while the sheet is already open is appended and the PageView animates to the new page.

## BUG-002
- Date: 2026-07-28
- Area: Alert bottom sheet header presentation
- Root cause: The plain 6px severity strip did not match Waby's wave-based visual language and duplicated the per-page icon, making stacked alerts feel visually disjointed.
- Fix: Replaced the strip with a wave header, moved the severity pill and drag handle into the header, added a shared overlapping icon medallion, and cross-faded the header when paging between alert severities.

## TEST-002
- Date: 2026-07-28
- Scope: Alert bottom sheet wave header
- Verified:
  - Wave header renders with the correct severity color for buckle, heat, left-behind, and low-battery alerts.
  - The icon medallion overlaps the wave with a clean white outer ring.
  - Swiping between amber and red alerts cross-fades the header treatment instead of hard-swapping it.
  - Caution alerts still dismiss on drag, while warning / critical alerts still do not.

## BUG-003
- Date: 2026-07-28
- Area: Reminder preferences / stale connectivity wording
- Root cause: Settings labels no longer matched the actual caution-vs-danger alert model, and legacy connectivity wording implied unsupported local pairing.
- Fix: Renamed the reminder toggles to match their real behavior, added info dialogs that document the safety override, removed stale local-pairing wording, and narrowed the section name to `Access`.

## TEST-003
- Date: 2026-07-28
- Scope: Safety-override reminder preferences
- Verified:
  - With all three reminder toggles OFF, a heat test alert must still trigger sound, vibration, and push because safety warnings override preferences.
  - With all three reminder toggles OFF, a buckle reminder must not trigger sound, vibration, or push because caution reminders honor preferences.
  - The old local-pairing wording was removed from app code and repo rules; no dissertation draft under `docs/` needed manual follow-up for this pass.

## BUG-004
- Date: 2026-07-28
- Area: Alert escalation handoff when app is closed
- Root cause: Alert lifecycle only existed in the client process, so once the app was killed there was no durable server-side record for `pg_cron` to use when deciding whether to escalate to Telegram or suppress a resolved alert.
- Fix: Cached `family_id` in `AlertService`, persisted warning/critical activations to `alert_events`, marked rows as `resolved_at` on dismissal/clear, and claimed `escalated_at` before local Telegram delivery so the client and server do not double-fire.

## TEST-004
- Date: 2026-07-28
- Scope: `alert_events` lifecycle persistence
- Verification target:
  - A warning/critical alert inserts one `alert_events` row in Supabase with `family_id`, `child_id`, `alert_type`, `severity`, `message`, `total_seconds`, and `started_at`.
  - Acknowledging or clearing that alert sets `resolved_at` on the same row.
  - When the client countdown auto-fires, the same row gets `escalated_at` so server cron can see the escalation was already handled.
  - Test alerts remain client-only and do not create `alert_events` rows.

## TEST-005
- Date: 2026-07-28
- Requirement traced: Life-safety escalation independent of client app state
- Preconditions: `alert_events` table + `check_alert_escalations()` + `pg_cron` 30s schedule deployed; `service_role_key` in vault; family with linked Telegram contact
- Steps:
  1. Inserted a stale `alert_events` row (`started_at = now() - 60s`, `total_seconds = 30`)
  2. Waited <=30s for cron cycle
  3. Verified Telegram delivered to linked contact
  4. Queried `alert_events`; `escalated_at` populated
- Expected result: Telegram fires within 30s of insertion; `escalated_at` set atomically
- Actual result: Pass
- Evidence: pending - user to attach Telegram screenshot + `SELECT escalated_at` query result

## BUG-005
- Date: 2026-07-28
- Area: Low battery handling on Home vs alert modal
- Root cause: Low battery was still modeled like a modal alert even though it is advisory, not an immediate life-safety condition, so it competed with heat/left-behind alerts and produced the wrong UX priority.
- Fix: Kept low battery out of the modal alert flow, added a dismissible Home banner with persisted dismissal state, and made the banner reappear only after the battery drops another 5% from the dismissal point.

## TEST-006
- Date: 2026-07-28
- Scope: Low-battery Home banner behavior
- Verification target:
  - When live battery drops below 20%, the banner appears on Home without opening the alert sheet or firing sound/vibration/push.
  - Dismissing the banner hides it until the battery falls at least 5% below the dismissal point.
  - Lowering battery from 15% to 9% makes the banner reappear; lowering from 15% to 14% does not.
  - A realtime `UPDATE live SET battery = ...` change is reflected on Home within a second or two.

## BUG-006
- Date: 2026-07-28
- Area: Client-side critical alert timing model
- Root cause: The in-app escalation ladder had grown into four distinct beats, which added implementation complexity without giving the caregiver a clearer mental model of what changed between phases.
- Fix: Simplified the client flow to a deliberate 3-beat model: initial alert, escalated alert at 50% of the window, then Telegram/external help at expiry.

## TEST-007
- Date: 2026-07-28
- Scope: 3-beat escalation timing
- Verification target:
  - `0s`: sound starts and the alert sheet opens.
  - `15s` on a 30s heat timer: sound is clearly louder and the push notification appears.
  - `30s`: Telegram is delivered.
