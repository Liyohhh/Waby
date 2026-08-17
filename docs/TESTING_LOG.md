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

## BUG-016
- Date: 2026-07-29
- Area: Home child card gender theme
- Root cause: Home `_ChildCard` header used one blue gradient for all non-warning children, so Boy/Girl was only text and not reflected in the card chrome.
- Fix: Pass `gender` into `_ChildCard` and theme Girl cards soft pastel pink (`#F5B4CD` → `#FCEAF2`, avatar `#FCEAF2`) and Boy cards soft pastel blue (`#7FD0E4` → `#D7F1F8`, avatar `#D7F1F8`) when not in warning. Warning red still wins over gender decoration. Status/Buckled/Near/Battery pills unchanged.

## TEST-018
- Date: 2026-07-29
- Scope: Home child card gender-coloured header
- Verification target:
  - Boy (or null gender) + SAFE/CAUTION → blue card header.
  - Girl + SAFE/CAUTION → pink card header.
  - Girl + WARNING → red warning header (not pink).
  - SAFE/CAUTION/WARNING badge and Buckled/Near/Battery pills still follow status only.

## BUG-017
- Date: 2026-07-29
- Area: Home child card DOB/details contrast on gradient header
- Root cause: DOB and details used `AppColors.navy.withAlpha(170)`, which was too faint on blue/pink gradient headers (~3.2:1 / ~2.6:1, below WCAG AA 4.5:1).
- Fix: Raise to `withAlpha(225)` and `FontWeight.w600` so the secondary lines stay readable while still secondary to the name. Pink gradient already at `#EC82AC` → `#F6C9DE`.

## TEST-019
- Date: 2026-07-29
- Scope: Child card secondary text legibility
- Verification target:
  - DOB and details lines are clearly readable on both blue (Boy) and pink (Girl) headers.
  - Name remains visually primary; DOB/details stay slightly softer but heavier than before.

## BUG-018
- Date: 2026-07-29
- Area: Family page child gender colour scheme
- Root cause: Family/Contacts child list and detail sheet used a single teal treatment for all non-warning children, so Boy/Girl theming only existed on Home.
- Fix: Apply the same soft blue (`#D7F1F8` / `#7FD0E4`) and soft pink (`#FCEAF2` / `#F5B4CD`) palette to Family child cards, avatars, and detail headers; warning red still wins. Detail header text switches to navy on pastel headers for contrast.

## TEST-020
- Date: 2026-07-29
- Scope: Family children Boy/Girl colour scheme
- Verification target:
  - Boy child card + detail header → soft blue; Girl → soft pink.
  - Warning child still uses soft red regardless of gender.
  - Avatar fill matches the gender pastel on list and detail.

## BUG-019
- Date: 2026-07-29
- Area: Add-child Date of Birth field
- Root cause: `_DateInputFormatter` re-sliced all digits into fixed DD/MM/YYYY positions on every keystroke, so deleting/editing a middle digit shifted later digits left and corrupted other segments (e.g. month erase pulled a year digit into the month).
- Fix: Replaced the single masked field with three independent DD / MM / YYYY boxes, auto-advance/back-focus between segments, `_dobFromFields()` for parsing, and calendar pick filling the three controllers. Removed `_DateInputFormatter` and `_dobController`.

## TEST-021
- Date: 2026-07-29
- Scope: Add-child segmented DOB entry
- Verification target:
  - Typing day then month then year advances focus at 2 / 2 digits.
  - Backspace on empty month/year moves focus to the previous box without deleting the previous segment.
  - Editing/deleting a digit in month does not change day or year digits.
  - Calendar picker fills DD, MM, YYYY correctly.
  - Invalid / out-of-range dates still show the existing `_error` messages on save or when complete.

## BUG-020
- Date: 2026-07-29
- Area: Family page children list freshness
- Root cause: `_ChildrenSectionState` used a one-shot `Future`/`FutureBuilder` for children. `ContactsScreen` stays alive in an `IndexedStack`, so a child added from Home never appeared until pull-to-refresh.
- Fix: Switched Children section to `ChildService.myChildrenStream()` + `StreamBuilder`, matching Home, so Realtime updates show new children immediately. Retry/reload re-subscribes the stream.

## TEST-022
- Date: 2026-07-29
- Scope: Family children live after Home add
- Verification target:
  - Add a child from Home → open Family tab without pull-to-refresh → new child appears.
  - Retry still recovers from stream errors by re-subscribing.
  - Empty and loading UIs unchanged.

## BUG-021
- Date: 2026-07-29
- Area: Family page members and emergency contacts freshness
- Root cause: Family members and emergency contacts used one-shot Futures/`FutureBuilder`s while `ContactsScreen` stays alive in an `IndexedStack`, so adds/edits/removes elsewhere did not appear until pull-to-refresh.
- Fix: Wired `FamilyService.familyMembersStream()` and `ContactService.contactsStream()` into `StreamBuilder`s; reload re-subscribes. Invite-code lookup left as a one-shot Future.

## TEST-023
- Date: 2026-07-29
- Scope: Family members and contacts live updates
- Verification target:
  - Add/remove a family member elsewhere → Family page updates without pull-to-refresh.
  - Add/edit/remove an emergency contact → Family page updates without pull-to-refresh.
  - Pull-to-refresh and Retry still re-subscribe cleanly.
  - Join code card still loads via its one-shot Future.

## BUG-022
- Date: 2026-07-29
- Area: Stale profile avatar/name after sign-out
- Root cause: `AppState.greetingName` and `AppState.avatarPath` are process-wide `ValueNotifier`s never cleared on sign-out. Home only re-fetches avatar when the cached value is null, so Account B after Account A kept A's photo (and briefly name) in the same session.
- Fix: Clear both notifiers in `AuthService.signOut()`, and refresh avatar path alongside greeting name in `routeAfterAuth()`.

## TEST-024
- Date: 2026-07-29
- Scope: Profile cache cleared across accounts
- Verification target:
  - Sign in as account with a photo → sign out → create/sign in as a new account → Home shows no previous avatar (or the new account's own).
  - Greeting name updates to the new account after `routeAfterAuth`.

## BUG-023
- Date: 2026-07-29
- Area: Join-family confirmation before write
- Root cause: Entering an invite code called `joinFamily` immediately, so users joined before seeing which family the code belonged to.
- Fix: Added `FamilyService.lookupFamilyByCode` (RPC already deployed) and a two-step join dialog — lookup then Confirm — so the DB join only runs after confirmation.

## TEST-025
- Date: 2026-07-29
- Scope: Join family confirm step
- Verification target:
  - Valid code → "Join this family? You are about to join '<name>'." before any join write.
  - Confirm → joins and shows Joined! success dialog.
  - Back returns to code entry without closing the dialog.
  - Invalid code still shows "Invalid invite code" SnackBar at lookup.

## BUG-024
- Date: 2026-07-29
- Area: Phone number entry UX
- Root cause: Register, Profile, and Add Emergency Contact used free-text phone fields, so users typed dial codes manually and formats were inconsistent.
- Fix: Added `kCountryDialCodes` + reusable `PhoneNumberField` (flag + dial code picker + local digits) that keeps `controller.text` as a single stored string like `+60123456789`.

## TEST-026
- Date: 2026-07-29
- Scope: Country-code phone field
- Verification target:
  - Register with Singapore +65 stores/displays the correct combined number.
  - Profile prefills an existing saved phone with the right flag/code and local digits.
  - Add Emergency Contact uses the same picker and still saves via the unchanged ContactService API.

## BUG-025
- Date: 2026-07-29
- Area: Profile save return tab
- Root cause: Profile is pushed from Home or Settings, but MainScreen kept tab index as private state — after save from Home, popping returned to Home instead of Settings.
- Fix: Added `AppState.mainTabIndex` and drove MainScreen's IndexedStack/BottomNavigationBar from it; after a successful Profile save, set tab to Settings (2) then pop.

## TEST-027
- Date: 2026-07-29
- Scope: Profile save lands on Settings
- Verification target:
  - Home avatar → Profile → Save → after "Profile saved", lands on Settings tab.
  - Settings → Profile → Save → lands on Settings tab.
  - Failed save stays on Profile.

## BUG-026
- Date: 2026-07-29
- Area: Phone country picker visuals
- Root cause: Dial-code UI used national flag emojis, which looked casual and inconsistent across platforms.
- Fix: Removed flag emojis from `CountryDialCode`; selector and sheet now use a Material `Icons.public` globe icon (circular bubble in the list) while still showing country name + dial code.

## TEST-028
- Date: 2026-07-29
- Scope: Professional dial-code icons
- Verification target:
  - Register / Profile / Add Emergency Contact phone field shows globe icon + dial code (no flag emoji).
  - Country sheet lists countries with globe icon bubbles; selecting still stores `+XX...` correctly.
## BUG-027
- Date: 2026-07-29
- Area: Car profiles + active-car prompt + Telegram car mention
- Root cause: App had no client for the new `cars` / `families.active_car_id` backend, so caregivers could not save cars or have alerts name which vehicle was in use.
- Fix: Added `Car` model, `CarService`, FamilyService active-car getters/RPC, Car Profiles settings UI, MainScreen "Which car today?" prompt, and append `Car: <name>.` on Telegram escalate messages (refreshing active car name at escalate time).

## TEST-029
- Date: 2026-07-29
- Scope: Car profiles end-to-end
- Verification target:
  - Settings → Car Profiles → add two cars with different colors; set one current.
  - Kill/reopen app → "Which car today?" shows current name; Change lists both with swatches.
  - Escalated Telegram alert includes `Car: <name>.` when an active car is set.

## BUG-028
- Date: 2026-07-29
- Area: Car number plate on profiles
- Root cause: Car profiles only stored name + color, so cars with the same model could not be told apart in the UI or Telegram alerts.
- Fix: Added optional `number_plate` (model/service/form/list/picker) and `Car.displayLabel` for Telegram; SQL migration `20260729_add_cars_number_plate.sql` must be applied in Supabase.

## TEST-030
- Date: 2026-07-29
- Scope: Car number plate
- Verification target:
  - Apply migration, then Add/Edit car with plate e.g. ABC 1234 — list shows plate under name.
  - "Which car today?" / picker shows plate; Telegram escalate includes `Car: Name (PLATE).` when plate set.

## BUG-029
- Date: 2026-07-29
- Area: Car plate_number field alignment
- Root cause: Client used `number_plate` / non-null String while backend column is nullable `plate_number`.
- Fix: Switched model/service/UI/Telegram to optional `plateNumber` mapped from `plate_number`; list/picker show plate separately; Telegram uses `Car: Name (PLATE).`.

## TEST-031
- Date: 2026-07-29
- Scope: plate_number end-to-end
- Verification target:
  - Add/edit car with optional plate — list and which-car picker show plate.
  - Telegram escalate reads `...Car: Honda City (ABC 1234).` when plate set.

## BUG-030
- Date: 2026-07-29
- Area: Home header active-car plate badge
- Root cause: Home wave header showed only the car image, with no cue which vehicle was active.
- Fix: Load active car via FamilyService/CarService on Home init; shrink/raise car image and show a white plate badge under it when `plateNumber` is set.

## TEST-032
- Date: 2026-07-29
- Scope: Home plate badge
- Verification target:
  - Active car with plate → badge under smaller car on Home header.
  - Clear plate (or no active car) → badge gone, car image alone.

## BUG-031
- Date: 2026-07-29
- Area: Add/Edit Car sheet keyboard overflow
- Root cause: `_CarFormSheet` Column was not scrollable, so opening the keyboard shrunk available height and overflowed/clipped the Save button.
- Fix: Wrapped the form Column in a `SingleChildScrollView` (viewInsets padding already applied by the parent sheet).

## TEST-033
- Date: 2026-07-29
- Scope: Car form sheet keyboard scroll
- Verification target:
  - Add Car → focus name/plate → no RenderFlex overflow; sheet scrolls; Add/Save button reachable.

## BUG-032
- Date: 2026-07-29
- Area: Home plate badge styling
- Root cause: Plate badge used flat black border/text that did not match Waby navy/accent + Poppins card styling.
- Fix: Restyled badge with navy border, accent tab, soft navy shadow, and Poppins.

## TEST-034
- Date: 2026-07-29
- Scope: Home plate badge visual
- Verification target:
  - Active car with plate shows navy-bordered white badge + accent stripe + Poppins plate text under car.

## BUG-033
- Date: 2026-07-30
- Area: Home plate badge Option C restyle
- Root cause: Previous plate badge (navy border + accent tab) felt cramped against the car and did not match the preferred Option C look.
- Fix: Replaced with pin + white plate, accent bullet, larger Poppins navy text, accent-tinted shadow, and 8px gap below the car.

## TEST-035
- Date: 2026-07-30
- Scope: Home Option C plate badge
- Verification target:
  - Active car with plate shows connector pin + white plate with blue dot clearly below the car.
  - No plate / no active car → badge absent as before.

## BUG-034
- Date: 2026-07-30
- Area: Car Profiles header vertical placement
- Root cause: The Car Profiles wave header sat slightly too low, making the top feel heavy compared with the descriptive text beneath it.
- Fix: Shifted the `SharedPageHeader` upward on the Car Profiles page without moving the wording block below.

## TEST-036
- Date: 2026-07-30
- Scope: Car Profiles header spacing
- Verification target:
  - Car Profiles header sits higher on the page while the descriptive wording stays in its existing position.

## BUG-035
- Date: 2026-07-30
- Area: Car Profiles number plate requirement
- Root cause: The Add/Edit Car form treated number plate as optional, which allowed incomplete car profiles.
- Fix: Made number plate required in the form UI, updated the field label, and block save with a SnackBar when it is empty.

## TEST-037
- Date: 2026-07-30
- Scope: Required car number plate
- Verification target:
  - Add/Edit Car cannot save with an empty number plate.
  - Entered number plate saves in uppercase and proceeds normally.

## BUG-036
- Date: 2026-07-30
- Area: Per-user active car reads
- Root cause: Client still read `families.active_car_id`, but active car is now per-user on `profiles.active_car_id` (cars RLS scoped to `created_by`).
- Fix: `FamilyService.getActiveCarId()` and `AlertService._loadActiveCarName()` now read the caller's profile; `setActiveCar` RPC unchanged.

## TEST-038
- Date: 2026-07-30
- Scope: Per-user cars / active car isolation
- Verification target:
  - Account A: cars + active plate on Home.
  - Account B (same family): empty car list; no "which car today?" until B adds a car.
  - B's active car does not change A's; A still sees A's active car after re-login.

## BUG-037
- Date: 2026-07-30
- Area: Page header title consistency + Car Profiles overlap
- Root cause: Settings/Family/SharedPageHeader used different title sizes and fonts; Car Profiles also wrapped SharedPageHeader in Transform.translate which caused wave/title overlap.
- Fix: Standardized all titles to Poppins 24/w700 white; restored plain SharedPageHeader on Car Profiles (no Transform.translate).

## TEST-039
- Date: 2026-07-30
- Scope: Unified page header titles
- Verification target:
  - Settings, Family, Car Profiles, Help & Support, Privacy & Data titles match (Poppins 24 / w700).
  - Car Profiles header no longer overlaps the wave.

## BUG-038
- Date: 2026-07-30
- Area: Family page Your Car selector
- Root cause: Active-car picking lived only on Car Profiles / cold-start prompt, so caregivers had no quick switch on Family.
- Fix: Added compact "Your Car" horizontal chips above Children on Family, with + navigating to Car Profiles; selection uses per-user setActiveCar.

## TEST-040
- Date: 2026-07-30
- Scope: Family Your Car section
- Verification target:
  - Family shows only the current user's cars as selectable chips.
  - Tapping a chip sets it active (accent fill).
  - + opens Car Profiles; returning refreshes active selection.

## BUG-039
- Date: 2026-07-30
- Area: Home Your Car section
- Root cause: Home only showed the active plate in the header, with no way to switch cars without leaving the dashboard.
- Fix: Added a "Your Car" card row above Your Children; tapping sets active car (updates header plate); Add Car opens Car Profiles.

## TEST-041
- Date: 2026-07-30
- Scope: Home Your Car cards
- Verification target:
  - Horizontal car cards appear above Your Children on Home.
  - Tap highlights + sets active; header plate badge updates.
  - Add Car opens Car Profiles and returns cleanly.

## BUG-040
- Date: 2026-07-30
- Area: Home Your Car pill size/style
- Root cause: Home car pickers were large white cards that felt heavy above Your Children.
- Fix: Replaced with compact accent pills — selected solid blue fill, unselected soft blue tint; Add Car stays as outline pill.

## TEST-042
- Date: 2026-07-30
- Scope: Home car pills
- Verification target:
  - Your Car row shows small blue pills; active pill is solid accent with white text.
  - Add Car outline pill still opens Car Profiles.

## BUG-041
- Date: 2026-07-30
- Area: Home car pill two-line layout
- Root cause: Name and plate sat on one horizontal line, harder to scan.
- Fix: Stacked name (bold) above plate inside each pill.

## TEST-043
- Date: 2026-07-30
- Scope: Home car pill layers
- Verification target:
  - Each car pill shows bold name on top and number plate underneath.

## BUG-042
- Date: 2026-07-30
- Area: Family page Your Car section removed
- Root cause: Car picking already lives on Home and Car Profiles; the Family "Your Car" row was redundant.
- Fix: Removed Family car selector UI and related stream/state/imports from contacts_screen.dart.

## TEST-044
- Date: 2026-07-30
- Scope: Family page without car section
- Verification target:
  - Family page goes header → children (no Your Car row).

## BUG-043
- Date: 2026-07-30
- Area: Family / Settings header title size
- Root cause: Main tab titles at 24px felt small next to the wave headers.
- Fix: Increased Family and Settings title fontSize from 24 to 28 (Poppins w700 unchanged).

## TEST-045
- Date: 2026-07-30
- Scope: Larger Family/Settings titles
- Verification target:
  - Family and Settings headers read larger than Car Profiles / Help / Privacy (which stay at 24).

## BUG-044
- Date: 2026-07-30
- Area: Home Your Car compact chips
- Root cause: Earlier pill styling still felt busy (dot cue / borders); needed a cleaner compact chip with a vertical color bar.
- Fix: Restyled to height-60 chips with left color bar, soft shadow, accent fill + white check when selected, and solid soft-blue Add chip (no dashed borders).

## TEST-046
- Date: 2026-07-30
- Scope: Home compact car chips
- Verification target:
  - Chips ~60px tall; color bar shows car color (white when selected).
  - Active chip accent-blue with white check; Add opens Car Profiles.

## BUG-045
- Date: 2026-07-30
- Area: Unified wave headers (Family / Settings / Car Profiles)
- Root cause: Family and Settings each had local wave headers with different title size/padding than SharedPageHeader.
- Fix: Extended SharedPageHeader with showBack + height; routed Settings (showBack: false) and Family (showBack: widget.showBack) through it; kept contacts local _WaveClipper for sheet UI only.

## TEST-047
- Date: 2026-07-30
- Scope: Identical SharedPageHeader across pages
- Verification target:
  - Settings, Family, Car Profiles share same wave height/curve/title (Poppins 24).
  - Settings: no back; Car Profiles: back; Family: back only when pushed.

## BUG-046
- Date: 2026-07-30
- Area: SharedPageHeader wave height too tall
- Root cause: Default header height stayed at 140 after title unification, so the wave still looked full-height.
- Fix: Default height 140→112 and title top padding set to flat 6.

## TEST-048
- Date: 2026-07-30
- Scope: Shorter shared wave header
- Verification target:
  - After hot restart, Settings / Family / Car Profiles / Help / Privacy show a visibly shorter blue wave with title still readable.

## BUG-047
- Date: 2026-07-30
- Area: SharedPageHeader title vertical position
- Root cause: After shortening the wave to 112, title top padding of 6 sat the wording too high.
- Fix: Increased title top padding from 6 to 14.

## TEST-049
- Date: 2026-07-30
- Scope: Header title lower on wave
- Verification target:
  - Shared header titles sit lower / nearer the wave body while remaining fully visible.

## BUG-048
- Date: 2026-07-30
- Area: SharedPageHeader title nudged lower again
- Root cause: Title still sat slightly high after padding 14.
- Fix: Increased title top padding from 14 to 20.

## TEST-050
- Date: 2026-07-30
- Scope: Header title further down
- Verification target:
  - Titles sit a bit lower still on the shorter wave without clipping.

## BUG-049
- Date: 2026-07-30
- Area: Home active car stale after "Which car today?"
- Root cause: MainScreen set the DB active car on startup prompt, but Home only loaded `_activeCar` once in initState and never refreshed.
- Fix: Added `AppState.activeCarId` notifier; MainScreen publishes on prompt/pick; Home listens and reloads; Home selector also publishes; cleared on signOut.

## TEST-051
- Date: 2026-07-30
- Scope: Active car sync after startup prompt
- Verification target:
  - Restart app → Change car in "Which car today?" → Home chip highlight and header plate update immediately.
  - Yes keeps existing car and Home still shows that car/plate.

## BUG-050
- Date: 2026-07-30
- Area: Family section helper text → info icons
- Root cause: Inline helper under Family Members cluttered the section; Emergency Contacts had no explanation at all.
- Fix: Replaced/added small info icons next to both headings that open shared `_showSectionInfo` dialogs.

## TEST-052
- Date: 2026-07-30
- Scope: Family Members / Emergency Contacts info icons
- Verification target:
  - Both headings show a small (i) icon; tap opens Got it dialog with explanation.
  - Old Family Members helper line is gone.

## BUG-051
- Date: 2026-07-30
- Area: Home Your Car empty after hot restart
- Root cause: `carsStream()` can emit an empty list on cold start before RLS/realtime settles; Home relied only on that first emission.
- Fix: Seed `_initialCars` via `myCars()` and pass as StreamBuilder `initialData` so the row paints immediately while the stream still updates live.

## TEST-053
- Date: 2026-07-30
- Scope: Home Your Car cold-start seed
- Verification target:
  - After hot restart / reopen, Home Your Car row shows the same cars as Car Profiles without manual refresh.

## BUG-052
- Date: 2026-07-30
- Area: Family girl child profile avatar color
- Root cause: Girl Family cards used a pale pink card with a white avatar ring, so the profile circle did not read as matching Home's soft pink.
- Fix: Girl avatar + ring use `#F5B4CD` (boy uses matching soft blue); detail-sheet avatar aligned the same.

## TEST-054
- Date: 2026-07-30
- Scope: Family girl profile pink
- Verification target:
  - Girl child on Family shows light-pink profile circle matching the pink card / Home theme.
  - Boy still soft blue; warning still red.

## BUG-053
- Date: 2026-07-30
- Area: Girl child detail sheet theme
- Root cause: Tapping a girl child opened a detail sheet whose body/stat/info cards stayed blue-white, so Live Status / Temp Analytics / Device Info did not match the pink gender theme.
- Fix: Soft pink sheet body, pink safe `_statCard` / `_infoRow` accents, and pink `_TempGraph` background when gender is Girl (warning/unsafe stays red).

## TEST-055
- Date: 2026-07-30
- Scope: Girl child detail popup pink
- Verification target:
  - Open a Girl child on Family → live status / temp graph / device info cards use light pink accents; sheet body stays white.
  - Boy detail sheet remains soft blue cards; warning states remain red.

## BUG-054
- Date: 2026-07-30
- Area: Girl detail sheet over-tinted
- Root cause: Soft pink was applied to the entire detail-sheet body, not only the cards.
- Fix: Reverted sheet body to white; kept pink only on Live Status cards, Device Info icon chips, and Temp Analytics card for girls.

## TEST-056
- Date: 2026-07-30
- Scope: Girl detail cards only pink
- Verification target:
  - Girl detail sheet background is white; only the status/info/temp cards are light pink.

## BUG-055
- Date: 2026-07-30
- Area: Telegram escalate missing structured fields
- Root cause: `_escalate()` only sent event/message/family_id while the Edge Function now builds the rich alert from child/car/temp/location fields.
- Fix: Fetch latest `live` row and pass `child_name`, `car_name`, `car_plate`, `temperature_c`, GPS fields, and `last_seen` in the invoke body.

## TEST-057
- Date: 2026-07-30
- Scope: Rich Telegram heat alert payload
- Verification target:
  - Heat escalate Telegram shows header, HIGH SEAT TEMPERATURE, child, car/plate, seat temperature, last update, and location line from structured fields.

## BUG-056
- Date: 2026-07-30
- Area: Forgot password / email OTP reset flow
- Root cause: Login had no password recovery path; users could not reset a forgotten password in-app.
- Fix: Added AuthService send/verify/update password OTP helpers, ForgotPasswordScreen 3-step UI, and a Login "Forgot password?" link. Requires Supabase Reset Password template to include `{{ .Token }}`.

## TEST-058
- Date: 2026-07-30
- Scope: Forgot password OTP end-to-end
- Verification target:
  - Login → Forgot password → Send Code → inbox shows 6-digit OTP.
  - Verify → set new password → returned to Login; sign in with new password works.

## BUG-057
- Date: 2026-07-30
- Area: Home "Your Car" empty after cold/hot start
- Root cause: StreamBuilder only applies `initialData` on first subscribe (when `_initialCars` is still empty). Updating `_initialCars` later via `setState` does not re-seed the snapshot; an empty realtime emission then leaves the row blank even after `myCars()` succeeds.
- Fix: Prefer non-empty stream data, else fall back to `_initialCars`; refresh the seed when returning from Car Profiles.

## TEST-059
- Date: 2026-07-30
- Scope: Home Your Car seed fallback
- Verification target:
  - Hot restart with existing cars: Your Car chips appear (not empty) even if realtime briefly emits [].
  - Add chip → Car Profiles → back: chips refresh via `_loadInitialCars()`.
  - `flutter analyze lib/screens/home_screen.dart` clean.

## BUG-058
- Date: 2026-07-30
- Area: AlertService stale family_id after account switch
- Root cause: Singleton cached `_familyId` (and active car name/plate) once and only reloaded when null, so sign-out → different sign-in without killing the app kept the previous user's family for Telegram / alert_events.
- Fix: `resetForUserChange()` on sign-out; track `_familyIdLoadedForUser` and reload family id whenever the signed-in user differs before insert/escalate.

## TEST-060
- Date: 2026-07-30
- Scope: Cross-account alert family routing
- Verification target:
  - Sign in as Family X → sign out (no kill) → sign in as Family Y → trigger alert → Telegram only to Y contacts.
  - Switch back to X → alert routes to X only.
  - `flutter analyze` clean on alert_service + auth_service.

## BUG-059
- Date: 2026-08-01
- Area: Admin mode / tab index leak across account switch
- Root cause: `signOut()` cleared greeting/avatar/activeCar but left `AppState.isAdminMode` and `mainTabIndex`, so the next account could inherit admin-mode alert overrides and a non-Home tab.
- Fix: Reset `isAdminMode` to false and `mainTabIndex` to 0 in `signOut()` alongside existing AppState / AlertService clears.

## TEST-061
- Date: 2026-08-01
- Scope: Sign-out clears admin mode and Home tab
- Verification target:
  - Enable admin mode on account A → sign out → sign into account B → B is non-admin and starts on Home.
  - `flutter analyze lib/services/auth_service.dart` clean.

## BUG-060
- Date: 2026-08-01
- Area: ESP32 firmware (`Project_1_draft_v2.ino`) buckle inversion + single FSR + temp threshold + live PATCH schema
- Root cause: Buckle used `== HIGH` while comment said LOW=buckled; only FSR pin 34 was read; `TEMP_THRESHOLD` was 40°C vs documented 30°C; no Wi-Fi/Supabase live push matching Flutter `live` columns.
- Fix: Buckle `== LOW`; three FSR pins (32/33/34) any-above-threshold presence; temp threshold 30°C; Wi-Fi (15s timeout) + `sendLiveUpdate()` PATCH to `live?id=eq.1` with `temperature`/`present`/`buckled`/`distance_near`/`battery`/`latitude`/`longitude`/`gps_accuracy_m`.

## TEST-062
- Date: 2026-08-01
- Scope: ESP32 live PATCH (real schema) + sensor logic
- Verification target:
  - Fill WIFI_*/SUPABASE_ANON_KEY → flash → OLED shows WiFi Connected or WiFi FAILED then continues.
  - Serial shows Supabase PATCH HTTP 204/200; Flutter LiveService on `id=1` reflects present/buckled/temp.
  - Buckle closed → LOCKED; weight on any FSR → PRESENT; temp > 30°C with presence → HIGH TEMP ALERT.

## BUG-061
- Date: 2026-08-02
- Area: ESP32 OLED did not show per-pad FSR pressure
- Root cause: Only combined presence was shown; individual FSR1/2/3 values were serial-only, so hardware checks could not tell which pads detect.
- Fix: OLED line `F1:.. F2:.. F3:..` with `*` when above threshold; Serial also prints Y/N detect per pad.

## TEST-063
- Date: 2026-08-02
- Scope: Three FSR pad visibility on OLED/Serial
- Verification target:
  - Press each pad alone → that FSR shows `*` / Y and others stay below threshold.
  - Re-upload sketch after change.

## BUG-062
- Date: 2026-08-02
- Area: ESP32 v3 sketch missing power/RGB when Wi-Fi/live was added
- Root cause: Wi-Fi/Supabase rewrite lived only in a slim v2 sketch and dropped power-button deep sleep, RGB status LEDs, and modular readSensors/updateDisplay from the full hardware firmware.
- Fix: Merged full feature set into `Project_1_draft_v3.ino` — power button, RGB, 3 FSR (`FSR: L R B` on OLED), buckle LOW=locked, temp 30°C, Wi-Fi + `sendLiveUpdate()` to `live?id=eq.1`.

## TEST-064
- Date: 2026-08-02
- Scope: Merged v3 firmware
- Verification target:
  - OLED shows `FSR: x y z`; RGB green only when seated+buckled+cool.
  - Hold power 2s → deep sleep; short wake via button.
  - With Wi-Fi + anon key filled: Serial `Supabase PATCH HTTP 204` and Flutter live row updates.

## BUG-063
- Date: 2026-08-02
- Area: Family children cards used hardcoded battery 88 / demo-only warning
- Root cause: `_ChildrenSectionState._toProfile` ignored `LiveService` and fell back to `battery: 88` and seed-only warning, unlike Home.
- Fix: Nested `StreamBuilder<SeatStatus>` on `_liveStream`; `_toProfile(c, rawLive)` uses `rawLive.battery` and live `severity == warning` when not demo-seeded.

## TEST-065
- Date: 2026-08-02
- Scope: Family page children live battery/warning
- Verification target:
  - Family → Children card battery matches Home / `live.battery`.
  - Heat/left-behind on live row → warning styling on Family child card (non-demo).
  - `flutter analyze lib/screens/contacts_screen.dart` clean.

## BUG-064
- Date: 2026-08-02
- Area: place_name not surfaced in app / Telegram escalate
- Root cause: ESP32 wrote `place_name` to `live` but SeatStatus/Home/AlertService ignored it.
- Fix: Parse `placeName` on SeatStatus; show under Home header temp; pass `place_name` in `_escalate` Telegram payload (select includes column).

## TEST-066
- Date: 2026-08-02
- Scope: place_name end-to-end
- Verification target:
  - With GPS place on `live.place_name`, Home shows location icon + name under °C.
  - Escalate includes place_name when non-empty.
  - `flutter analyze` clean on seat_status, alert_service, home_screen.

## BUG-065
- Date: 2026-08-02
- Area: Profile screen had no visible signed-in email
- Root cause: First profile card only showed name/nickname/phone, so users could not confirm which account they were in.
- Fix: Read-only Email row after Full Name using `_auth.currentUser?.email`.

## TEST-067
- Date: 2026-08-02
- Scope: Profile read-only email
- Verification target:
  - Profile → first card shows Email between Full Name and Nickname; not editable.
  - Matches the signed-in Supabase user email.

## BUG-066
- Date: 2026-08-02
- Area: Family child detail Live Status used hardcoded/always-safe values
- Root cause: Detail sheet used `safe = !isWarning` for Buckle/Distance and literal `23°C`; non-demo `isWarning` was false when seed was null before live wiring, and temperature/buckled/distanceNear were not on `_ChildProfile`.
- Fix: `_ChildProfile` carries live `temperature`/`buckled`/`distanceNear`; detail `_statCard`s use those fields; override path still refreshes sensors from `rawLive`.

## TEST-068
- Date: 2026-08-02
- Scope: Family child detail live indicators
- Verification target:
  - Open child detail → Temperature/Buckle/Distance/Battery match `live` row (and Home).
  - Heat → temp card unsafe; unbuckled → buckle unsafe; far → distance unsafe.
  - `flutter analyze lib/screens/contacts_screen.dart` clean.

## BUG-067
- Date: 2026-08-03
- Area: Heat warning recolored child cards red on Home/Family
- Root cause: Warning state overrode gender pastel header/background; caregivers lost gender cues when temp was high.
- Fix: Keep boy/girl card colors always; status chip still shows WARNING; Home header °C (and Family list °C) turn red when temp > 30°C.

## TEST-069
- Date: 2026-08-03
- Scope: Gender card colors retained under heat
- Verification target:
  - Heat on live → Home child card stays blue/pink; badge says WARNING (red).
  - Home big temperature number turns red above 30°C.
  - Family child list stays gender color; shows WARNING + red °C when hot.
  - `flutter analyze` clean on home_screen + contacts_screen.

## BUG-068
- Date: 2026-08-03
- Area: Heat alert debounce (`lib/services/alert_service.dart`)
- Root cause: `heatDebounce` was 15s — a brief sensor spike (e.g. a couple of seconds above 30°C from DHT11 noise or a momentary read) could count toward triggering a full heat alert without the temperature actually being sustained.
- Fix: Raised `heatDebounce` to 30s. Vehicular-heatstroke research shows real cabin heat risk builds over minutes (≈11°C rise per 10 min), so 30s stays a small fraction of that curve while requiring ~30 consecutive above-threshold pushes (at the firmware's ~1s push rate) before the alert can activate — filtering transient noise without meaningfully delaying a real event.

## TEST-070
- Date: 2026-08-03
- Scope: Heat debounce duration
- Verification target:
  - Simulate temperature > 30°C for <30s (e.g. edit `live.temperature` briefly via Supabase, then revert) → no alert screen, no sound, no Telegram.
  - Simulate temperature > 30°C sustained ≥30s → alert activates at tier 3 (critical) as before.
  - `flutter analyze lib/services/alert_service.dart` clean.

## BUG-069
- Date: 2026-08-03
- Area: Buckle reminder re-fired immediately after acknowledge / swipe-away
- Root cause: Acknowledging a buckle alert cleared it but the next live tick re-activated the same condition with no snooze; swiping the sheet away also re-prompted on the next emission.
- Fix: 5-minute `_buckleSnoozedUntil` after acknowledge (cleared on rebuckle); MainScreen throttles buckle-only sheet re-prompts to 60s.

## TEST-071
- Date: 2026-08-03
- Scope: Buckle acknowledge snooze + sheet re-prompt throttle
- Verification target:
  - Unbuckled present+near → buckle sheet → Acknowledge → no re-alert for 5 min while still unbuckled.
  - Rebuckle then unbuckle again → new buckle alert allowed.
  - Swipe sheet away without acknowledge → sheet may return after ≥60s, not instantly.
  - `flutter analyze` clean on alert_service + main_screen.

## BUG-070
- Date: 2026-08-03
- Area: Buckle reminder fired while parked (diaper change, etc.)
- Root cause: Buckle condition only checked present + unbuckled + distanceNear; no notion of whether the car was moving.
- Fix: Firmware publishes `car_moving` from GPS speed (>2 km/h, fail-safe true without fix); SeatStatus parses it; buckle alert requires `carMoving`.

## TEST-072
- Date: 2026-08-03
- Scope: Buckle gated on car_moving
- Verification target:
  - Parked (`car_moving=false`) + present + unbuckled → no buckle alert sheet.
  - Moving (`car_moving=true`) + present + unbuckled + near → buckle reminder as before.
  - Missing `car_moving` column/null → defaults true (still alerts).
  - Re-flash v3 firmware; ensure Supabase `live.car_moving` boolean exists.
  - `flutter analyze` clean on seat_status + alert_service.

## BUG-071
- Date: 2026-08-03
- Area: Startup car dialog overlapped alert sheet; Acknowledge untappable
- Root cause: `_onAlerts` and `_maybeAskAboutCar` both ran on first frame, stacking two modals so the car dialog blocked taps on Acknowledge. Sheet also relied only on stream sync to pop after ack.
- Fix: Gate alerts until car prompt finishes (`_startupReadyForAlerts`); then show pending alerts. Acknowledge removes locally and pops immediately.

## TEST-073
- Date: 2026-08-03
- Scope: Startup car → then alert sequencing
- Verification target:
  - Cold open with cars + active buckle condition → "Which car today?" first; after Yes/pick, Home visible, then alert sheet.
  - Acknowledge dismisses buckle sheet (does not stay stuck under another dialog).
  - `flutter analyze` clean on main_screen + alert_bottom_sheet.

## BUG-072
- Date: 2026-08-03
- Area: Acknowledge worked once then failed after reopen
- Root cause: Acknowledge + empty stream both called `Navigator.pop()`, stacking a double-pop that could leave a stuck barrier/`sheetOpen`. Buckle snooze was in-memory only, so reopen immediately re-alerted and felt like dismiss failed.
- Fix: Single `_closeSheet()` path with `_closing` guard; reset `sheetOpen` on MainScreen init; persist buckle snooze in SharedPreferences across restarts.

## TEST-074
- Date: 2026-08-03
- Scope: Acknowledge reliable across reopen
- Verification target:
  - Acknowledge buckle → sheet closes; reopen within 5 min → no buckle sheet (snooze persisted).
  - After snooze expires / rebuckle+unbuckle → sheet shows again and Acknowledge still dismisses.
  - `flutter analyze` clean on alert_service, alert_bottom_sheet, main_screen.

## BUG-073
- Date: 2026-08-03
- Area: Family list clutter + sparse header + floating nav gap
- Root cause: Child cards showed caution/temp/battery chips; Family used default SharedPageHeader spacing; bottom nav had 14px bottom margin leaving a large gap.
- Fix: Child cards show name+age only; Family-specific taller header with lower title + pull content up; nav SafeArea with 4px bottom inset and tighter label metrics.

## TEST-075
- Date: 2026-08-03
- Scope: Family / nav visual cleanup
- Verification target:
  - Family child cards: no SAFE/CAUTION/TEMP/battery chips.
  - Family title sits lower in wave; less empty gap before Children.
  - Bottom nav closer to screen edge (smaller gap).
  - `flutter analyze` clean on contacts_screen, main_screen, auth_widgets.

## BUG-074
- Date: 2026-08-09
- Area: ESP32 firmware (`Project_1_draft_v3.ino`) DHT11 oversampling → temp flicker + heat debounce reset
- Root cause: `readSensors()` ran every loop (~200–300 ms) but DHT11 cannot be sampled faster than ~1 Hz; failed reads returned NaN and firmware pushed `temperature: 0`, so the live temp bounced between real value and 0/"Error" and the app's 30s heat debounce kept resetting.
- Fix: Throttle DHT reads to once every 2 s (`DHT_READ_INTERVAL_MS`); on failed/too-soon reads hold last good `temperature`/`tempValid` instead of zeroing; recompute `highTemp` from held value.

## TEST-076
- Date: 2026-08-09
- Scope: DHT11 throttle + last-good temp hold
- Verification target:
  - Serial `Temp:` line updates smoothly every ~2 s with no "Error"/0 flicker between valid reads.
  - Supabase `live.temperature` holds steady instead of bouncing to 0.

## BUG-075
- Date: 2026-08-09
- Area: Heat-alarm false-positive at Malaysian ambient (~30–32°C)
- Root cause: Heat threshold was hardcoded at 30°C in app (`seat_status`, `alert_service`) and firmware (`TEMP_THRESHOLD`), so ambient KL temps triggered tier-3 critical heat alarms at rest.
- Fix: Single `kHeatThresholdC = 38.0` in `lib/core/constants.dart`; seat severity/reason and alert conditions use it; firmware `TEMP_THRESHOLD` set to 38.0; test-alert detail bumped to 41.0°C. Debounce unchanged.

## TEST-077
- Date: 2026-08-09
- Scope: Heat threshold 38°C (app + firmware)
- Verification target:
  - At ambient ~30–32°C no heat alarm fires.
  - Warming the DHT11 above 38°C for ≥30 s fires the tier-3 heat alert.
  - OLED shows "HIGH TEMP!" at the same point.
  - `flutter analyze lib/models/seat_status.dart lib/services/alert_service.dart` clean.

## BUG-076
- Date: 2026-08-09
- Area: ESP32 firmware (`Project_1_draft_v3.ino`) presence flicker near detection line
- Root cause: Presence used a single `PRESS_DETECT_PCT = 15` threshold with no hysteresis/debounce, so weight near the line toggled `babyPresent` every read; each flip made the Flutter app resolve+recreate alerts (flickering sheets, resetting timers/tiers).
- Fix: Schmitt hysteresis (`SEAT_ENTER_PCT` 18 / `SEAT_CLEAR_PCT` 10) plus `PRESENCE_CONFIRM` (4) consecutive confirming reads before flipping; strongest pad drives the decision.

## TEST-078
- Date: 2026-08-09
- Scope: Presence hysteresis + debounce
- Verification target:
  - With a weight resting near the detection line, Serial `Baby:` holds steady at SEATED or EMPTY instead of flapping between reads.
  - Lifting the weight fully clears to EMPTY within ~1 s.
  - App alert sheet no longer flickers open/closed.

## BUG-077
- Date: 2026-08-09
- Area: Project documentation + doc-sync rules
- Root cause: Living docs for database, API, and design system were missing; project-overview still described Firebase; design-system rule had drifted header gradient hexes vs `theme.dart`.
- Fix: Added project documentation: DATABASE, API, DESIGN_SYSTEM, and doc-sync rules. Updated `PRD.md` (Last updated 2026-08-09) and `.cursor/rules/project-overview.mdc` / `design-system.mdc` to match Supabase + `theme.dart`.

## TEST-079
- Date: 2026-08-09
- Scope: Docs and rules established
- Verification target:
  - `docs/DATABASE.md`, `docs/API.md`, `docs/DESIGN_SYSTEM.md` present; sync rules under `.cursor/rules/*-sync.mdc`.
  - `flutter analyze` clean (no Dart regressions from doc-only work).

## BUG-078
- Date: 2026-08-09
- Area: ESP32 firmware (`Project_1_draft_v3.ino`) FSR baseline calibrated after WiFi / wrong if seat loaded
- Root cause: Empty-seat baseline was learned on a timer inside `updateFsrBaselines()` that only started on the first `loop()` after `connectWiFi()` (up to 15 s). The OLED "Keep seat EMPTY / calibrating FSR…" prompt vanished long before calibration, so a loaded seat during WiFi could poison the baseline for the whole session.
- Fix: `calibrateFsrBaselines()` runs ~3 s in `setup()` while the prompt is visible, before WiFi; Serial `'c'` re-baselines mid-session on an empty seat.

## TEST-080
- Date: 2026-08-09
- Scope: Explicit FSR calibration in setup + Serial recalibrate
- Verification target:
  - On boot the "Keep seat EMPTY" prompt stays visible for the full ~3 s calibration.
  - Serial `FSR baselines L/R/B:` prints before "Connecting WiFi".
  - Loading the seat after boot reliably reads SEATED.
  - Typing `c` on an empty seat re-baselines and prints new values.

## BUG-079
- Date: 2026-08-09
- Area: ESP32 firmware (`Project_1_draft_v3.ino`) buckle contact bounce clears app snooze
- Root cause: `buckleLocked` flipped on a single `digitalRead`, so bounce/intermittent contact toggled buckled between reads; each phantom re-buckle cleared the app's 5-minute buckle-acknowledge snooze.
- Fix: Require `BUCKLE_CONFIRM` (4) consecutive consistent reads before changing `buckleLocked`.

## TEST-081
- Date: 2026-08-09
- Scope: Buckle switch debounce
- Verification target:
  - Wiggling or lightly jostling the buckle no longer flips Serial `Buckle:` on single reads.
  - A real latch/unlatch still registers within ~1 s.
  - In the app, acknowledging a buckle reminder keeps it snoozed for the full window instead of re-firing after a phantom re-buckle.

## BUG-080
- Date: 2026-08-09
- Area: ESP32 firmware (`Project_1_draft_v3.ino`) noisy single-sample battery ADC
- Root cause: `voltageRaw = analogRead(VOLTAGE_PIN)` used one unaveraged sample, so ADC noise jumped `batteryPct` and flickered the app's low-battery banner.
- Fix: `readVoltageSmoothed()` discards the first sample after mux switch then averages 16 reads (same pattern as FSR); `readSensors()` uses it. `rawToBatteryPercent` / `VOLTAGE_RAW_MIN/MAX` unchanged.

## TEST-082
- Date: 2026-08-09
- Scope: Smoothed battery ADC read
- Verification target:
  - With a steady battery, Serial Battery Raw / battery % holds within a narrow band instead of jumping several percent between reads.

## BUG-081
- Date: 2026-08-15
- Area: App Home/Family ignored ESP32 live telemetry
- Root cause: Demo overlay painted fixed Jason SAFE / Alysha WARNING cards instead of `live` row `id=1`; demo login also upserted fake live values; app heat threshold was 38°C while firmware `TEMP_THRESHOLD` is 30.0. Firmware also PATCHes `battery_voltage`, which PostgREST rejects if the column is missing (whole update fails).
- Fix: Home and Family child cards use `LiveService` status only; demo seed no longer writes `live`; `kHeatThresholdC` set to 30.0 to match firmware; migration adds `live.battery_voltage`. Firmware sketch was not changed.

## TEST-083
- Date: 2026-08-15
- Scope: App follows hardware live row
- Verification target:
  - After hot restart, Home temperature / presence / buckle match the OLED (not frozen demo SAFE/WARNING).
  - Unbuckle on hardware → app buckle pill / caution updates.
  - Seat empty → app shows empty/safe, not a leftover WARNING child card.
  - Run `alter table public.live add column if not exists battery_voltage numeric;` in Supabase if Serial PATCH is 400.

## BUG-083
- Date: 2026-08-15
- Area: App battery pill showed 0% while ESP32 OLED showed ~44%
- Root cause: `SeatStatus.fromMap` used `as num?` for `battery`. PostgREST often delivers `numeric` as a string, which failed the cast and fell through to 0. Firmware also sends `battery_voltage`, which the app ignored.
- Fix: Parse `battery` from num or string; if percent is 0, derive it from `battery_voltage` using the firmware 3.0–4.2 V map. Sketch not changed.

## TEST-085
- Date: 2026-08-15
- Scope: Live battery % matches hardware
- Verification target:
  - Hot restart with seat pushing ~44% → Home battery pill shows ~44%, not 0%.
  - Serial `Supabase PATCH HTTP` is 204/200 (if 400, add `live.battery_voltage` in Supabase).

## BUG-084
- Date: 2026-08-15
- Area: Home buckle pill did not track hardware LOCKED/UNLOCKED
- Root cause: Buckle/battery pills were hidden when `present` was false, so a stale `live.buckled=true` only showed after a seated read. Live stream also waited for the next Realtime event instead of reading the current `live` row. Firmware already PATCHes `buckled` from `buckleLocked` (LOW = locked).
- Fix: Child card always shows Buckled/Unbuckled from `live.buckled`; `LiveService` seeds with a REST read of `live` id=1 then follows Realtime. Sketch not changed.

## TEST-086
- Date: 2026-08-15
- Scope: Buckle pill follows ESP32 OLED
- Verification target:
  - OLED `Buckle: LOCKED` → app pill **Buckled**; `UNLOCKED` → **Unbuckled**, including when Baby is EMPTY.
  - Serial PATCH 204/200 while toggling the buckle.

## BUG-082
- Date: 2026-08-15
- Area: Unbuckle popup with no child registered
- Root cause: `AlertService` defaulted to placeholder child `"Your child"` / `primary-child`. `_onChildren` returned early when the children list was empty, so `_conditionsFor` still fired buckle (and other seat) alerts from live telemetry.
- Fix: Track `_hasPrimaryChild`; skip live alert conditions until a real child exists; clear pending/active alerts when the last child is removed. Settings test alerts unchanged.

## TEST-084
- Date: 2026-08-15
- Scope: No buckle sheet without a child
- Verification target:
  - Home with no device/child, seat present + unbuckled → no unbuckle popup.
  - After Add Device / child, same unbuckle → buckle reminder shows.
  - Delete last child while a buckle sheet is open → sheet/alerts clear.

## BUG-086
- Date: 2026-08-15
- Area: Family / Settings wave header titles sat too high or too low
- Root cause: Settings used a top-padded title under SafeArea; Family used a taller wave (`height: 148`) plus `titleTopPadding: 44`, so the word sat near an edge instead of in the middle of the wave.
- Fix: `SharedPageHeader` vertically centers the title in the wave (status bar above, ~22px wave dip below). Family uses the same header as Settings.

## TEST-088
- Date: 2026-08-15
- Scope: Family and Settings wave titles
- Verification target:
  - "Family" and "Settings" sit in the vertical middle of the teal wave, not hugging the status bar or the wavy bottom edge.

## BUG-085
- Date: 2026-08-15
- Area: Home place name sat under the temperature, crowding the car label / Add Device area
- Root cause: `placeName` (e.g. "Unknown place") was rendered between the °C value and "$name's car".
- Fix: Move the location line above the thermostat / temperature block.

## TEST-087
- Date: 2026-08-15
- Scope: Home place label position
- Verification target:
  - Location (including "Unknown place") sits above the big °C reading, not under it or near Add Device.

## BUG-087
- Date: 2026-08-15
- Area: Settings Vibration toggle saved a pref but never moved the motor
- Root cause: On/off only wrote `settings_vibration`. No `Vibration.vibrate` on enable, no `cancel` on disable. Alert `stop()` also left any pattern running.
- Fix: Turning Vibration on plays a 180ms preview pulse; turning it off cancels vibration. `AlertFeedbackService.stop()` cancels the motor too. Buckle escalation haptics respect the pref; heat/left-behind still always vibrate.

## TEST-089
- Date: 2026-08-15
- Scope: Settings Vibration switch
- Verification target:
  - Toggle Vibration ON → phone buzzes once.
  - Toggle OFF → motor stops (no pulse).
  - Caution buckle reminder vibrates only when the switch is on.

## BUG-089
- Date: 2026-08-15
- Area: Heat alert froze at 0s or vanished when temperature flickered
- Root cause: After the countdown hit 0 the ring kept showing `0` / "NOTIFYING FAMILY IN" with no notified state. `_onStatus` also resolved heat on the first live tick below threshold (DHT NaN → 0°C), which closed the sheet.
- Fix: At 0s the ring shows ✓ plus Contacts notified / No linked contacts. Heat/left-behind do not auto-clear until the condition has been gone for the heat debounce (30s) / 10s; once Telegram has fired the sheet stays until Acknowledge.

## TEST-091
- Date: 2026-08-15
- Scope: Heat sheet at 0s and through temp flicker
- Verification target:
  - Heat countdown reaching 0 → ✓ and notified copy; sheet stays until Acknowledge.
  - Brief temp dip / 0°C glitch during an active heat alert does not dismiss the sheet.

## BUG-088
- Date: 2026-08-15
- Area: `SeatStatus` battery parsing vs firmware
- Root cause: Voltage was used to override `battery` when percent parsed as 0; `battery_voltage` was not exposed. Firmware already sends a valid 0–100 `battery` plus volts.
- Fix: `battery` is the authoritative percent (`num.tryParse` on int/num/String, no `as num?`). `batteryVoltage` is a nullable double for display only (string-tolerant). No voltage→percent fallback. Schema and firmware unchanged.

## TEST-090
- Date: 2026-08-15
- Scope: Battery percent from live `battery` column
- Verification target:
  - Live `battery` 44 (int or string) → Home shows 44%, even if `battery_voltage` is a string like `"3.72"`.
  - `flutter analyze` clean on `lib/models/seat_status.dart`.

## BUG-090
- Date: 2026-08-15
- Area: Home place name and car/plate alignment
- Root cause: "Unknown place" was left-aligned in the temperature column; the car image and plate sat slightly left/high of the intended header composition.
- Fix: Center the location row in the left column. Nudge the car + plate down and right (`left` 210→228, `top` 78→92).

## TEST-092
- Date: 2026-08-15
- Scope: Home header layout
- Verification target:
  - Place name (including "Unknown place") sits centered in the left half, not flush-left under the greeting.
  - Car image and number plate sit slightly further right and lower than before, still above the wave.

## BUG-091
- Date: 2026-08-15
- Area: Family → Children live telemetry
- Root cause: List cards showed name/age only, so Realtime ticks were invisible. The detail sheet was a frozen `_ChildProfile` snapshot from tap time.
- Fix: Cards show live °C + SAFE/WARNING from `LiveService`. Detail sheet is a `StreamBuilder` so temp/buckle/distance/battery keep updating while open and after dismiss.

## TEST-093
- Date: 2026-08-15
- Scope: Children tab live updates
- Verification target:
  - Change seat temperature / buckle without opening a child → list card °C and SAFE/WARNING update.
  - Open the sheet, change sensors, values update without closing.
  - Close the sheet; list continues to update.

## BUG-092
- Date: 2026-08-15
- Area: Android notification shade during alerts
- Root cause: `_emitUserFacingAlert` skipped `PushNotificationService.show` while the app was resumed. Sheet dispose also `cancelAll()`, wiping any tray entry.
- Fix: Always post a shade notification on alert (silent while foreground so in-app sound is not doubled). Do not cancel tray notifications when the sheet closes; still cancel on acknowledge/resolve.

## TEST-094
- Date: 2026-08-15
- Scope: Android notification drawer
- Verification target:
  - Trigger heat / left-behind / buckle with the app open → swipe down the status bar and see a Waby notification.
  - Acknowledge / clear the alert → notification is removed.
  - Allow Notifications permission if Android prompts.

## BUG-093
- Date: 2026-08-15
- Area: Children Temperature Analytics used a mock 12h series
- Root cause: `_TempGraph` hardcoded 22–24°C and a 32°C danger line. `live` is a single overwriting row, so 12h history needs a sample table.
- Fix: `temperature_samples` + trigger (≤1/min) + app fallback insert. Graph reads last 12h, hourly buckets, danger line = `kHeatThresholdC` (30°C).

## TEST-095
- Date: 2026-08-15
- Scope: 12-hour temperature analytics
- Verification target:
  - After running `supabase/migrations/20260815_temperature_samples.sql`, wait ~1–2 minutes with the seat online → `SELECT * FROM temperature_samples ORDER BY recorded_at DESC LIMIT 5` shows DHT values.
  - Children detail graph uses those samples (not the old flat 22–24 mock). Danger line reads 30°C.
  - Before SQL is applied, graph shows the live reading or "Collecting temperature history…".

## BUG-094
- Date: 2026-08-15
- Area: Children Device Info GPS was a hardcoded KL coordinate
- Root cause: `_infoRow` used `3.1478° N, 101.6953° E`. `SeatStatus` did not parse `live.latitude` / `live.longitude`.
- Fix: Parse GPS from the live row (string-tolerant). Firmware `0.0, 0.0` shows as "No GPS fix"; a real fix shows live coordinates and updates with the stream.

## TEST-096
- Date: 2026-08-15
- Scope: Live GPS in Family → Children detail
- Verification target:
  - With NEO-6M fix on `live` (non-zero lat/lng) → Device Info GPS matches those coordinates (N/S E/W).
  - With `0, 0` or null → "No GPS fix", never the old KL mock.
  - Coordinates update if the seat moves without reopening the sheet.

## BUG-095
- Date: 2026-08-15
- Area: Home showed "Unknown place" even with a GPS fix
- Root cause: ESP32 reverse-geocode often stores `Unknown place` on `live.place_name` (empty BigDataCloud fields, or HTTP geocode fail with `placeNameReady` still true). The app displayed that string as-is.
- Fix: `PlaceNameService` reverse-geocodes live lat/lng on the phone (HTTPS BigDataCloud, Nominatim fallback) and Home/Telegram use that label instead of the placeholder. Does not write back to `live` (firmware would overwrite at 1 Hz).

## TEST-097
- Date: 2026-08-15
- Scope: Known place name on Home
- Verification target:
  - With a real GPS fix and `live.place_name` = "Unknown place" → Home shows "Locating…" then a locality/city (not "Unknown place").
  - No GPS fix → location row hidden (not "Unknown place").
  - Telegram escalate uses the resolved name when the live column is still a placeholder.

## BUG-096
- Date: 2026-08-15
- Area: Place lookup needed a simpler, more reliable API path
- Root cause: Custom `HttpClient` reverse-geocode was easy to fail silently; firmware still writes "Unknown place".
- Fix: Use the `geocoding` plugin (Android/Google geocoder, no key) first, then Nominatim and BigDataCloud via `http`. Home also triggers lookup on each live tick. Label is "suburb, state" when both exist.

## TEST-098
- Date: 2026-08-15
- Scope: API reverse-geocode on Home
- Verification target:
  - Full restart after `geocoding` + `http` (not hot reload).
  - GPS fix + Unknown place on `live` → Home shows a real locality (e.g. "Subang Jaya, Selangor"), not "Unknown place".
  - Phone must be online for the first lookup.

## BUG-097
- Date: 2026-08-15
- Area: Remaining mock hardware values in Family, Home, and Admin
- Root cause: Children Device Info always said "Weight detected". Home temp bar was scaled to 32°C. Admin listed fake users (Jason/Alysha/…) and fake recent alerts.
- Fix: Seat sensor follows `live.present`. Home bar max is `kHeatThresholdC` (30°C). Admin seats and recent alerts read `live` + `children` + `alert_events`.

## TEST-099
- Date: 2026-08-15
- Scope: Live hardware vs leftover mocks
- Verification target:
  - Lift the baby off the FSR → Children Device Info shows "Seat empty"; put weight back → "Weight detected".
  - Home temp scale labels 20°C … 30°C.
  - Admin panel child temp/buckle/battery match the `live` row, not Sarah Tan / 88%.

## BUG-098
- Date: 2026-08-15
- Area: Caregiver Near/Far was hardcoded `distance_near: true` in firmware
- Root cause: No proximity sensor. ESP32 always PATCHed true, so left-behind could not fire.
- Fix: ESP32 advertises BLE name `WabySeat` and omits `distance_near` from the live PATCH. The app scans RSSI (≥ −70 Near, ≤ −82 or lost 8s Far) and writes `live.distance_near`. Overlay applies only after the beacon is seen once this session.

## TEST-100
- Date: 2026-08-15
- Scope: BLE RSSI near/far
- Verification target:
  - Flash the updated `.ino` (backup `Project_1_draft_v3.ino.bak-20260815-ble`). Serial shows `BLE advertising as WabySeat`.
  - Full `flutter run` (new BLE plugin). Allow Bluetooth + Location.
  - Phone next to the seat, baby present → Home/Family Distance **Near**.
  - Walk ~10 m away with the phone (app open) → **Far** within ~8–12 s; left-behind can fire.
  - Without the new firmware, Near/Far stays on the last `live` value (no false Far).

## BUG-099
- Date: 2026-08-18
- Area: Every child card showed the same global `live` row
- Root cause: One ESP32 writes `live` id=1; Home/Family/Admin/AlertService all bound every child to that row.
- Fix: `children.hardware_linked` (first child per family). That child reads `live`; later children get a cached always-SAFE `SimulatedStatusService` status. `AlertService` only names alerts after the hardware-linked child.

## TEST-101
- Date: 2026-08-18
- Scope: Per-family first child = hardware, later children simulated
- Verification target:
  - Run `supabase/migrations/20260818_children_hardware_linked.sql` in the SQL editor.
  - Existing family: earliest child has `hardware_linked=true`; others false.
  - New account: first Add Device child tracks the physical seat (temp/buckle/near/alerts); a second child stays SAFE (present, buckled, Near, battery 70–95, temp 22–26) even when the seat is unbuckled/hot/far.
  - Home header temperature still follows the ESP32 `live` row.
  - Unbuckle/leave the real seat → alerts name the first child only, never the simulated sibling.

## BUG-100
- Date: 2026-08-18
- Area: New family Home showed the shared ESP32 temperature with no device
- Root cause: Home header always bound to `live` id=1, even when the family had zero children.
- Fix: Header uses live telemetry only if the family has a hardware-linked child. Otherwise temperature shows `--`, the bar is empty, and place name is hidden.

## TEST-102
- Date: 2026-08-18
- Scope: New family empty Home
- Verification target:
  - Create a new account + new family with no device → Home temperature is `--`, no place name, empty child list.
  - Add the first child/device → header switches to the real `live` °C.
  - Existing families with a hardware-linked child still show live temp.

