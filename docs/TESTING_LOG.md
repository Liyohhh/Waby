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

## TEST-008
- Date: 2026-07-28
- Scope: Tier-2 in-app perceptibility
- Verification target:
  - `0s`: phone uses the slow double-pulse vibration, foreground audio starts at the lower tier-1 volume, and the alert sheet opens without the `ESCALATED` chip.
  - `15s` on a 30s heat timer: audio jumps to the louder tier-2 level, vibration switches to the rapid-burst pattern, and the red `ESCALATED` chip fades in on the sheet.
  - The foreground/background arbitration still prevents duplicate in-app plus notification sound while the app is open.

## BUG-007
- Date: 2026-07-28
- Area: Graded escalation presentation
- Root cause: Heat and left-behind alerts entered the UI already red/high-severity, so the caregiver could not perceive a clear transition from reminder to danger escalation inside the same alert.
- Fix: Derived severity from `alertType + tier`, so heat and left-behind now begin yellow/caution, cross-fade to red at 50% of the timer, and keep Telegram as the final 100% escalation point. Buckle remains caution-only and is the only dismissible alert.

## TEST-009
- Date: 2026-07-28
- Scope: Examiner-facing graded escalation demo
- Verification target:
  - `T=0s`: yellow sheet slides up, caution pill shows, soft caution audio starts, gentle vibration begins, countdown starts at 30, and the sheet cannot be dismissed.
  - `T=15s`: sheet cross-fades from yellow to red over ~600ms, a distinct triple-tap escalation burst is felt, the louder escalated sound replaces the caution sound, and the pill changes from `CAUTION` to `CRITICAL` / `WARNING`.
  - `T=30s`: Telegram is delivered; the sheet stays in the escalated state until Acknowledge is tapped.

## BUG-008
- Date: 2026-07-28
- Area: Three-tier yellow → orange → red escalation
- Root cause: The prior two-step caution→danger model collapsed the warning phase into a single red jump, so caregivers never saw a distinct intermediate escalation state with its own colour and sound.
- Fix: Split the window into thirds (33% / 66% / 100%), mapped tiers to caution/warning/critical with yellow/orange/red colours and matching audio assets, and fired feedback + haptic bursts on every tier transition.

## TEST-010
- Date: 2026-07-28
- Scope: Primary examiner-facing three-tier escalation demo
- Verification target:
  - `T=0s`: yellow sheet, soft caution chime, gentle vibration, sheet locked for heat, countdown from 30.
  - `T=10s`: 600ms yellow→orange cross-fade, triple-tap haptic burst, warning tone replaces chime and loops, pill reads WARNING.
  - `T=20s`: 600ms orange→red cross-fade, longer/faster haptic burst, critical siren replaces warning tone, pill reads CRITICAL, countdown label swaps to "NOTIFYING FAMILY IN", number grows ~15%.
  - `T=30s`: Telegram delivered; sheet stays red until Acknowledge.

## BUG-009
- Date: 2026-07-28
- Area: Alert countdown ring / remaining time display
- Root cause: `_CountdownRing` painted remaining time once at build time, and `AlertService` only emits the active-alert stream on tier/state changes — so between escalations the sheet never rebuilt and the countdown number/ring froze.
- Fix: Converted `_CountdownRing` to a StatefulWidget with a 200ms wall-clock timer that recomputes remaining time from `startedAt` + `totalSeconds` independently of stream emissions.

## TEST-011
- Date: 2026-07-28
- Scope: Countdown motion on alert sheet
- Verification target:
  - On a heat test alert, the countdown number decreases every second without waiting for a tier transition.
  - The ring progress depletes smoothly in sync with wall-clock remaining time.
  - Countdown keeps moving across yellow → orange → red tier changes for the same `alertId`.

## BUG-010
- Date: 2026-07-29
- Area: Alert sheet colour stuck grey while sound escalates
- Root cause: On tier 2/3 transitions, `_tick()` awaited `Vibration.vibrate(pattern: burst, repeat: -1)`. The infinite-repeat Future never completed, so `_emit()` at the end of `_tick` never ran. Sound still fired (before the hang); the open sheet kept the initial tier-1 grey snapshot. Console only showed a late `[ALERT-UI] stream tick count=0` on dismiss.
- Fix: `_emit()` immediately when `tracked.tier` changes; escalation haptic is `unawaited(Vibration.vibrate(pattern: burst))` with no `repeat: -1`, so the tick loop cannot hang on the vibration plugin.

## TEST-012
- Date: 2026-07-29
- Scope: Left-behind / heat sheet colour tracks tier with sound
- Result: Pass (device)
- Verification performed:
  - Tier 1 (~0–33%): grey header + soft caution sound.
  - Tier 2 (~33–66%): header/icon/ring/ack button shift to yellow-orange with warning sound (no stuck grey).
  - Tier 3 (~66–100%): shift to red with critical sound; pill reads CRITICAL.
  - Acknowledge still dismisses and stops feedback.

## BUG-011
- Date: 2026-07-29
- Area: Heat escalation / heat + left-behind co-occurrence
- Root cause: Heat used the same 33%/66% time ramp as left-behind, so a heat alert started grey/soft and waited before critical. When heat and left-behind both ran, left-behind still waited out its full timer before telegram auto-fire.
- Fix: `_tierFor` returns tier 3 immediately for heat; `_activate` seeds heat at tier/lastFiredTier 3; `_TrackedAlert.totalSeconds` is mutable; when left-behind co-occurs with heat for the same child, remaining grace collapses to elapsed so tier/countdown/telegram treat it as maxed out.

## TEST-013
- Date: 2026-07-29
- Scope: Immediate heat critical + heat/left-behind collapse
- Verification target:
  - Heat-only test alert: red/critical sheet + critical sound from first frame (no grey→orange ramp).
  - Left-behind alone: still grey → yellow-orange → red over the timer thirds.
  - Heat + left-behind together: left-behind countdown/tier/telegram path collapses immediately (no full left-behind wait).

## BUG-012
- Date: 2026-07-29
- Area: Post-login routing for admin users
- Root cause: `routeAfterAuth` always sent signed-in users through the family-id check to `ExistingOrNewFamilyScreen` / `MainScreen`, so admin accounts never reached `AdminMainScreen` even though the screen existed.
- Fix: After auth, call `AuthService().getUserRole()`; if `role == 'admin'`, navigate to `AdminMainScreen`, otherwise keep the existing family-picker / main flow.

## TEST-014
- Date: 2026-07-29
- Scope: Admin vs caregiver post-login destination
- Verification target:
  - Sign in with an admin-role profile → lands on Admin Panel (`AdminMainScreen`).
  - Sign in with a normal caregiver profile that has a family → lands on `MainScreen`.
  - Sign in with a normal profile with no family → lands on `ExistingOrNewFamilyScreen`.

## BUG-013
- Date: 2026-07-29
- Area: Add/edit child height validation
- Root cause: Height fields only rejected `<= 0` or `> 200`, so unrealistically small values under infant scale could be saved.
- Fix: Require height in the range 24–200 cm on both Home add-child and Contacts edit-child forms; error copy: "Enter a height from 24 to 200 cm".

## TEST-015
- Date: 2026-07-29
- Scope: Child height minimum 24 cm
- Verification target:
  - Add/edit child with height 23 → validation error, cannot save.
  - Height 24 or 200 → accepts (within other required fields).
  - Empty height still optional (null allowed).

## BUG-014
- Date: 2026-07-29
- Area: Country picker order
- Root cause: `kCountryOptions` was ordered by region preference (Malaysia first), not A–Z, so the picker was hard to scan.
- Fix: Sorted `kCountryOptions` alphabetically in `lib/core/constants.dart` (used by register + profile).

## TEST-016
- Date: 2026-07-29
- Scope: Country list alphabetical
- Verification target:
  - Register and Profile country pickers show Australia … Vietnam in A–Z order.
  - Existing saved country still selects correctly if it remains in the list.

## BUG-015
- Date: 2026-07-29
- Area: Child profile gender data
- Root cause: Child records only stored name, DOB, height, weight, and photo, so caregivers could not record Boy/Girl and child profile surfaces had no place to show it.
- Fix: Added nullable `gender` across the child model and Supabase write paths, created a Boy/Girl selector for add/edit child forms, surfaced gender in Home/Contacts child displays, updated demo seeds, and added a SQL migration for `children.gender`.

## TEST-017
- Date: 2026-07-29
- Scope: Boy/Girl child profile option
- Verification target:
  - Add Child form defaults to Boy and lets the user switch between Boy and Girl before saving.
  - Edit Child form loads the saved value and updates it correctly.
  - Home and Contacts child profile surfaces show the saved Boy/Girl value alongside the child details.
  - Existing rows with null gender still load without crashing.
