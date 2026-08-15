# Waby — Design System

| | |
|---|---|
| **Source of truth** | `lib/core/theme.dart` (`AppColors`, `kHeaderGradient`, `AppTheme`) |
| **Brand** | Waby — butterfly logo (navy wings + blue dot); calm, rounded, friendly |
| **Last updated** | 2026-08-09 |

Build-time rule: `.cursor/rules/design-system.mdc` (must stay aligned with this doc and `theme.dart`).

---

## Colours (`AppColors`)

Exact hex values from `lib/core/theme.dart`:

### Brand

| Token | Hex | Use |
|-------|-----|-----|
| `navy` | `#0F2D54` | Primary buttons, headings |
| `navyDeep` | `#0D1117` | Logo wings / darkest text |
| `headerTop` | `#008FB4` | Wave-header gradient start |
| `headerBottom` | `#7AD0E4` | Wave-header gradient end |
| `accent` | `#3B74BC` | Links, info pills |
| `value` | `#5187C6` | Big stat numbers |
| `dot` | `#2AAEE0` | Logo dot / bright accent |
| `softBlue` | `#8ECEE1` | Bottom nav, soft accents |

### Surfaces

| Token | Hex | Use |
|-------|-----|-----|
| `field` | `#F7F3F3` | Input backgrounds |
| `safeCard` | `#E0E8F2` | Safe child card |
| `warningCard` | `#FBE6E5` | Warning child card |
| `card` | `#FFFFFF` | Plain cards |

### Status (general UI)

| Token | Hex | Use |
|-------|-----|-----|
| `safe` | `#56B337` | SAFE green |
| `caution` | `#F0C040` | Amber (non-alert UI) |
| `warning` | `#C2291D` | Destructive / status red |
| `critical` | `#C2291D` | Critical red |

### Alert escalation ramp

Matches soft → warning → critical sound cues (`AlertFeedbackService` / alert sheet):

| Token | Hex | Tier |
|-------|-----|------|
| `alertSoft` | `#8A9199` | Grey — tier 1 / caution sound |
| `alertCaution` | `#F0A020` | Yellow-orange — tier 2 / warning sound |
| `alertCritical` | `#C2291D` | Red — tier 3 / critical sound |

### Text

| Token | Hex |
|-------|-----|
| `textPrimary` | `#0F2D54` |
| `textSecondary` | `#6B7280` |
| `hint` | `#A0A6B1` |

**Rule:** Never hard-code hex in widgets — use `AppColors.*`.

---

## Header gradient (`kHeaderGradient`)

```
LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [AppColors.headerTop, AppColors.headerBottom], // #008FB4 → #7AD0E4
  stops: [0.31, 0.88],
)
```

Used by `SharedPageHeader` and other wave headers.

---

## Typography

- Font: **Poppins** via `google_fonts` (`GoogleFonts.poppinsTextTheme` on `AppTheme.light`).
- Body / display colour: `AppColors.textPrimary`.
- Patterns: big bold headings; bold coloured values (`AppColors.value`); grey secondary (`textSecondary` / `hint` for placeholders).
- Primary elevated button text: Poppins 18 / w700, white on navy.
- Section labels (Settings-style): navy Poppins w600 / ~13.

---

## Theme defaults (`AppTheme.light`)

| Element | Spec |
|---------|------|
| Scaffold | White |
| Material 3 | Yes |
| Primary / secondary | `navy` / `accent` |
| Elevated button | Navy fill, white fg, min height 56, radius 16, elevation 0 |
| Inputs | Filled `field`, radius 16, no border, hint = `AppColors.hint` |
| App bar | Transparent, white foreground |

---

## Recurring components

### SharedPageHeader (wave header)

`lib/widgets/auth_widgets.dart` — `SharedPageHeader`.

- Full-width `kHeaderGradient` clipped with `AppWaveClipper` (white wavy bottom edge).
- White Poppins title (24 / w700), vertically centered in the wave (below the status bar, above the dip); optional back button.
- Default height 128.

### Status pill

`lib/widgets/status_pill.dart` — `StatusPill` + `StatusTone`.

- Tones: `good` → `safe`, `bad` → `warning`, `neutral` → `accent`.
- Background = tone at 12% opacity; icon in tone colour; label navy.

Used on child cards for buckle / near / battery-style chips.

### Info pill

Blue rounded chip pattern (accent / soft blue) with icon + short label (e.g. Latched, Near, battery %). Prefer `StatusPill` / theme tokens over raw colours.

### Child card

Home / Family child cards:

- Avatar + name + age / gender / weight details.
- Background tint: safe → `safeCard` / gender-aware soft blues-pinks; warning → `warningCard`.
- Gender tinting (Boy/Girl) on Family cards; status badge SAFE / WARNING.
- Empty seat must **not** use warning-red styling.

### Metric card

Detail / dashboard metric tiles: white rounded card, icon, optional **LIVE** chip, label, large `AppColors.value` number, subtitle. Often in a 2×2 grid.

### Primary button

Full-width (or theme `ElevatedButton`) navy, ~16px radius, bold white Poppins — often with a trailing arrow on onboarding CTAs.

### Bottom nav

Rounded light-blue bar (`softBlue` family), three tabs: **Home** / **Family** / **Settings**.

### Alert bottom sheet

`lib/widgets/alert_bottom_sheet.dart`:

- Colour from escalation ramp: buckle → `alertSoft`; tier 1 → `alertSoft`; tier 2 → `alertCaution`; tier 3 → `alertCritical`.
- Countdown / acknowledge path; navy acknowledge controls.
- Critical path non-dismissible via back until Acknowledge.

### Other shared widgets

| Widget | Role |
|--------|------|
| `SignedAvatar` | Storage-backed circular avatar |
| `GenderSelector` | Boy / Girl (`kGenderOptions`) |
| `LowBatteryBanner` | Home caution banner |
| `ContactStatusBadge` | Linked / Not linked Telegram |
| `InviteFamilySheet` | Add emergency contact |
| `DrainingAckButton` | Acknowledge control on alerts |

---

## Icons & assets

- Prefer Material Icons (`Icons.home`, `Icons.link`, `Icons.thermostat`, battery, GPS).
- Brand / illustration PNGs under `assets/images/`.
- Alert sounds: `assets/sounds/alert_caution.mp3`, `alert_warning.mp3`, `alert_critical.mp3` (played via `AlertFeedbackService`).

---

## Maintenance notes

When tokens in `lib/core/theme.dart` or shared widgets under `lib/widgets/` change, update this document in the same change. Keep `.cursor/rules/design-system.mdc` hex values identical to `theme.dart`.
