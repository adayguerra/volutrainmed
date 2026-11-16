---
name: VolutrainMed Pro Max
colors:
  surface: '#faf8ff'
  surface-dim: '#d2d9f4'
  surface-bright: '#faf8ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f3ff'
  surface-container: '#eaedff'
  surface-container-high: '#e2e7ff'
  surface-container-highest: '#dae2fd'
  on-surface: '#131b2e'
  on-surface-variant: '#40484c'
  inverse-surface: '#283044'
  inverse-on-surface: '#eef0ff'
  outline: '#70787d'
  outline-variant: '#bfc8cd'
  surface-tint: '#1e667f'
  primary: '#004357'
  on-primary: '#ffffff'
  primary-container: '#0d5c75'
  on-primary-container: '#93d3ef'
  inverse-primary: '#90cfec'
  secondary: '#006877'
  on-secondary: '#ffffff'
  secondary-container: '#8debff'
  on-secondary-container: '#006b7a'
  tertiary: '#004730'
  on-tertiary: '#ffffff'
  tertiary-container: '#006142'
  on-tertiary-container: '#6bdeac'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#bde9ff'
  primary-fixed-dim: '#90cfec'
  on-primary-fixed: '#001f2a'
  on-primary-fixed-variant: '#004d64'
  secondary-fixed: '#a3eeff'
  secondary-fixed-dim: '#76d4e7'
  on-secondary-fixed: '#001f25'
  on-secondary-fixed-variant: '#004e5a'
  tertiary-fixed: '#85f8c4'
  tertiary-fixed-dim: '#68dba9'
  on-tertiary-fixed: '#002114'
  on-tertiary-fixed-variant: '#005137'
  background: '#faf8ff'
  on-background: '#131b2e'
  surface-variant: '#dae2fd'
  surface-canvas: '#F4FAFB'
  surface-card: '#FFFFFF'
  border-subtle: '#C5D9E0'
  clinical-error: '#DC2626'
  clinical-warning: '#D97706'
  clinical-deep: '#0A4D68'
  unit-dimmed: '#475569'
typography:
  display-handsfree:
    fontFamily: Space Mono
    fontSize: 64px
    fontWeight: '700'
    lineHeight: 72px
    letterSpacing: -0.02em
  display-handsfree-mobile:
    fontFamily: Space Mono
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Space Grotesk
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Space Grotesk
    fontSize: 26px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Space Grotesk
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: '0'
  headline-sm:
    fontFamily: Space Grotesk
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: '0'
  numeric-input:
    fontFamily: Space Mono
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
    letterSpacing: 0.02em
  numeric-input-mobile:
    fontFamily: Space Mono
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: 0.02em
  body-problem:
    fontFamily: Noto Sans
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
    letterSpacing: '0'
  body-default:
    fontFamily: Noto Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: '0'
  body-sm:
    fontFamily: Noto Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: '0'
  label-code:
    fontFamily: Space Mono
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
    letterSpacing: 0.04em
  label-unit:
    fontFamily: Space Mono
    fontSize: 14px
    fontWeight: '700'
    lineHeight: 20px
    letterSpacing: 0.02em
  badge-micro:
    fontFamily: Space Grotesk
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.06em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-tablet: 1.5rem
  gutter-desktop: 2rem
  margin: 1rem
  margin-tablet: 1.5rem
  margin-desktop: 2rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

### Visual Personality & Target Audience
The design system establishes a clinical, high-reliability, and utilitarian interface engineered specifically for intensive care physicians, specialized clinical nurses, paramedics, and veterinary surgeons. It explicitly rejects consumer gamification archetypes—such as cartoon mascots, faux 3D claymorphism, confetti bursts, and punitive health meters—in favor of serious, scientific credibility. 

The emotional tone balances calm authority, precision measurement, and total cognitive clarity under emergency pressures. Every visual element is calibrated to prevent cognitive overload during acute medical calculations, dosimetric titrations, and fluid administration protocols.

### Design Movement: Swiss Clinical Modernism
The aesthetic synthesizes Swiss International Typographic Style with modern clinical UI architecture:
- **Hairline Precision**: Clean 1px structural contours that isolate calculation variables without visual clutter.
- **Instrumental Whitespace**: Uncluttered canvases that frame complex dimensional analysis and prevent human factor calculation errors.
- **Ergonomic Safety Ratios**: Generous minimum touch boundaries (48dp standard, 72dp high-visibility glove targets) and strict visual coupling between numbers and units.
- **The Meniscus Signature**: Purely abstract, liquid-inspired geometric cues (subtle concave curvature reminiscent of fluid levels in calibrated glass syringes and ampoules) replace decorative ornamentation.

## Colors

### Chromatic Hierarchy & Application
The color system operates under strict medical-grade legibility parameters, exceeding WCAG 2.1 AAA contrast ratios across all critical calculation surfaces:

- **Primary (`#0D5C75`)**: Deep Clinical Cyan. Serves as the primary operational anchor, handling actionable calculation triggers, active progress states, and prominent headings. Contrast ratio exceeds 7.2:1 against light surfaces.
- **Secondary (`#088395`)**: Medical Teal. Applied to secondary controls, active unit selector toggles, and dimensional node structures.
- **Tertiary (`#059669`)**: Clinical Verification Green. Used exclusively for verified safe dosages, positive dimensional analysis checks, and parameter confirmations.
- **Neutral (`#0F172A`)**: Slate Obsidian. High-density typographic color for absolute contrast and zero eye fatigue under hospital fluorescent or daylight conditions.

### Contextual Safeguards & Semantic Roles
- **Clinical Error (`#DC2626`)**: Critical dosimetric anomalies, toxic volume alerts, and invalid numerical operations. Must never rely solely on color; always paired with high-contrast text and a non-transient status icon.
- **Clinical Warning (`#D97706`)**: Threshold alerts (e.g., patient weight limits, rapid infusion advisories).
- **Surface Canvas (`#F4FAFB`)**: Desaturated medical tint preventing screen glare and cognitive fatigue during extended shifts.
- **Border Subtle (`#C5D9E0`)**: 1px structural framing for card divisions, custom keypad keys, and dosimetric step sequences.

## Typography

### Typographic Rationale & Clinical Rules
Clinical dosing demands instantaneous legibility without ambiguity between similar glyphs (such as '1', 'l', and 'I', or '0' and 'O'):
- **Space Grotesk**: Provides clean, authoritative geometric architecture for headings, module titles, and protocol sections.
- **Noto Sans**: Uncluttered, universal readability for clinical problem prompts, rationales, and medication guidelines.
- **Space Mono**: Tabular, fixed-pitch monospaced numerals ensure numbers, decimal places, and units align vertically on calculation sheets.

### Medical Formatting Guardrails
1. **Protected Decimal Notation**: Decimal markers (`,`) are reinforced with 2px horizontal spacing on both sides within answer inputs to avoid catastrophic tenfold dosimetric errors.
2. **Strict Unit Coupling**: A numerical value and its respective clinical unit (e.g., `2,5 mg/kg/h` or `12 gotas/min`) must utilize `white-space: nowrap`. The numerical quantity is rendered in weight `700` while the unit uses weight `400` or `label-unit`.
3. **Dimensional Cancellation**: Units canceled in step-by-step conversion sequences transition to 40% opacity with a clean horizontal strikeout.

## Layout & Spacing

### Spatial Rhythm & Grid Structure
The system is built upon a 4dp/8dp mathematical baseline rhythm:
- **Mobile (`< 600dp`)**: Single-column vertical layout with 16px margins. Interactive keypad controls, unit selectors, and confirmation CTAs are anchored strictly within the lower 60% of the viewport (the thumb zone) for single-handed use during physical rounds.
- **Tablet / Foldable (`600dp – 839dp`)**: Single wide column (max 640dp reading column) supported by a compact navigation rail. Margins expand to 24px.
- **Desktop / Clinical Workstation (`≥ 840dp`)**: Two-column master-detail workspace: problem parameters and patient profile on the left; dosimetric calculations, interactive keypad, and step-by-step analysis on the right. Margins expand to 32px.

### Ergonomic Bounds
- **Standard Touch Target**: Minimum 48dp × 48dp on all actionable controls, surrounded by a minimum 8dp clearance buffer.
- **High-Visibility Hands-Free Targets**: Minimum 72dp × 72dp targets designed for rapid non-tactile or gloved interactions.
- **Max Content Containment**: Clinical prompts and documentation cards cap at 640dp to preserve optimal line lengths (50–70 characters per line).

## Elevation & Depth

### Flat Clinical Restraint
The design system rejects heavy skeletal drop shadows, multi-tiered ambient lighting, and faux 3D skeumorphism in favor of Swiss flat architectural clarity. Depth is communicated strictly through surface layering and hairline separation.

### Surface Tiers & Outlines
1. **Tier 0 (Root Canvas)**: `#F4FAFB` desaturated background representing the sterile working canvas.
2. **Tier 1 (Surface Containers & Cards)**: `#FFFFFF` pure white surfaces, framed by a continuous `1px solid #C5D9E0` boundary. No box shadow is applied in neutral states.
3. **Tier 2 (Active Calculation Blocks)**: Emphasized via a `2px solid #0D5C75` border rather than vertical elevation.
4. **Tier 3 (Clinical Drawers & Bottom Sheets)**: Framed with a 1px border and an ambient, low-opacity drop shadow (`box-shadow: 0 8px 24px rgba(15, 23, 42, 0.08)`).
5. **Tier 4 (Critical Verification Alerts / Modals)**: Centered over an opaque scrim (`rgba(15, 23, 42, 0.6)`) with a clean `1px solid #C5D9E0` structural contour.

## Shapes

### Shape Language & Geometry
The geometric language reflects clinical instruments: clean, reliable, and functional. Elements maintain balanced, calibrated corners that soften technical density without appearing playful or juvenile.

- **Containers & Clinical Cards**: `rounded-md` (0.5rem / 8px) or `rounded-lg` (1rem / 12px–16px) for major panels, establishing clean structural boundaries.
- **Input Fields & Custom Keypad Keys**: `rounded-md` (0.5rem / 8px) providing defined touch boundaries without ballooning into toy-like volumes.
- **Unit Chips & Validation Badges**: Full pill contours (`rounded-full` / 9999px) strictly reserved for concise tags, dosage units (`mg/kg/min`, `ml/h`), and status pills.
- **Modals & Bottom Action Sheets**: Top-left and top-right radii set to `16px`, maintaining a clean sheet architecture.

## Components

### 1. Primary & Secondary Action Buttons
- **Primary Clinical Action**: Height `52dp`. Solid `#0D5C75` fill with `#FFFFFF` text. Monospaced numerals within labels. Min-width `100%` on mobile screens. Micro-interaction: scale `0.98` on active tap with `100ms` duration.
- **Secondary Action**: Height `52dp`. Background transparent with `1px solid #C5D9E0` and text `#0D5C75`. Hover/focus background: `#F4FAFB`.
- **Hands-Free Action (Glove Mode)**: Minimum height `72dp`. Border `2px solid #0D5C75`. Typography `headline-md` for quick recognition from a 1-meter working distance.

### 2. Custom Medical Keypad
- **Layout**: 3×4 grid (`1–9`, decimal comma `,`, `0`, and backspace delete). Fluid width within a maximum container width of `420dp`.
- **Keys**: Minimum height `56dp`, background `#FFFFFF`, border `1px solid #C5D9E0`. Active key press triggers a light 10ms haptic tap and 100ms `#F1F5F9` background fill.
- **Decimal Comma Safeguard**: The decimal key `,` is disabled dynamically if one comma already exists in the active input parameter.

### 3. Unit Selector Chips & Badges
- **Unit Selector Chips**: Minimum height `48dp`, pill-shaped (`9999px`), internal padding `0.5rem 1rem`. Inactive state: `#FFFFFF` fill with `1px solid #C5D9E0` and text `#475569`. Active state: `#0D5C75` fill with text `#FFFFFF` and a checkmark icon.
- **Status Badges**: Pill-shaped with micro-typography (`Space Grotesk`, `11px`, `600`). Emerald container (`#DCFCE7` / text `#047857`) for validated doses; Crimson container (`#FEE2E2` / text `#DC2626`) for critical limit breaches.

### 4. Calculation Display & Input Fields
- **Answer Display Box**: Minimum height `64dp`, surface `#FFFFFF`, border `2px solid #0D5C75` when active. Typography `numeric-input` (`Space Mono`, `40px`).
- **Unit Attachment**: The associated unit (`ml/h`, `µg/min`) sits within the input box as a permanent right-aligned anchor in `#475569`.

### 5. Clinical Problem Cards
- **Structure**: Surface `#FFFFFF`, border `1px solid #C5D9E0`, radius `12px`, padding `1.5rem`.
- **Card Header**: Displays case taxonomy (e.g., *Pediatría*, *Canino Urgencias*, *UCI*) in `badge-micro` alongside patient weight and vital parameters.
- **Problem Statement**: Rendered in `body-problem` with key clinical values highlighted in semibold monospace.

### 6. Dimensional Analysis Steps
- **Step Row**: Horizontal calculation sequence featuring dimensional cancellations. Numbers are bold (`700`); units are regular (`400`). Cancelled matching units use an angled `1.5px` strikeout line and dim to 40% opacity.
- **Deviation Pulse**: Erroneous calculation steps trigger a static `2px solid #DC2626` outline paired with a clear textual explanation beneath the step.