# PantryPal design system

## Intent

PantryPal feels like a well-used family kitchen: capable, warm, and clear enough for a hurried weekday. It favours evidence and next actions over decoration. The distinctive recurring device is the **pantry window**: a rounded inset with a terracotta frame, cream field, and small food-colour accents. It appears in the logo, empty states, archive cover fallback, and selected navigation state—never as unrelated ornament.

## Brand voice

Plain, encouraging, and specific. Labels name the person’s task (`Confirm shopping date`, `Check cheese again`); messages explain the cause and recovery (`We could only read the caption. Upload the clip or add ingredients manually.`). Use sentence case. Never use vague failure copy or emoji as icons.

## Token architecture

Primitive values are not used directly in feature widgets. Semantic values map them to intent, and component values map semantic values to reusable controls. Theme mode swaps semantic values only.

| Layer | Token | Light | Dark | Use |
|---|---|---:|---:|---|
| Primitive | terracotta-700 | `#9A3412` | `#FDBA9B` | Identity |
| Primitive | green-600 | `#059669` | `#6EE7B7` | Confirmed action |
| Primitive | cream-50 | `#FFFBEB` | `#17221F` | Warm base |
| Primitive | ink-950 | `#0F172A` | `#F8FAFC` | Reading text |
| Semantic | surface.canvas | cream-50 | `#17221F` | Screen background |
| Semantic | surface.raised | `#FFFFFF` | `#22312D` | Cards/sheets |
| Semantic | content.primary | ink-950 | `#F8FAFC` | Primary text |
| Semantic | action.primary | green-600 | `#6EE7B7` | Main positive CTA |
| Semantic | action.brand | terracotta-700 | `#FDBA9B` | Identity/secondary CTA |
| Semantic | state.warning | `#A16207` | `#FCD34D` | Review/recheck |
| Semantic | state.danger | `#B91C1C` | `#FCA5A5` | Destructive/error |
| Component | button.primary.bg | action.primary | action.primary | Confirm/save/start |
| Component | card.recipe.bg | surface.raised | surface.raised | Recipe cards |
| Component | status.recheck.fg | state.warning | state.warning | Pantry recheck |

## Type, layout, and touch

- Baloo 2: only display hierarchy, 24–32sp, semibold/bold.
- Nunito Sans: all body, labels, controls, and numeric data, 14–18sp.
- Spacing is 4, 8, 12, 16, 24, 32, 40, 48dp. Core screen gutter is 16dp phone and 24dp tablet/desktop.
- Radius is 12dp (small), 20dp (medium), and 28dp (large). Cards use medium; pills use large.
- All interactive targets are at least 48×48dp; all state uses icon + text + colour.
- Phone uses five labelled bottom destinations. Tablet/desktop uses the same items in a navigation rail; content is capped at 1200dp.

## Components and states

| Component | Required states | Accessibility contract |
|---|---|---|
| Primary button | enabled, pressed, loading, disabled | 48dp target; loading retains accessible action label |
| Recipe card | default, needs review, selected | reads title, readiness, servings, source; not colour-only |
| Status chip | default, warning, error, confirmed | text and icon name status |
| Completeness bar | extracted, manual, missing | semantic summary gives all three values |
| Cooking card | confirmed, transfer pending | responsibility is labelled in text |
| Archive collage | 1–4 covers, overflow | date and recipe count exposed as one semantic label |

## Motion

Use native Flutter implicit animations only: 180ms press/state feedback, 220ms sheet/card transition, ease-out. Motion is interruptible. `MediaQuery.disableAnimations` removes nonessential movement and switches transitions to immediate changes. No scroll-jacking, parallax, background animation, or autoplay visual noise.

## Accessibility acceptance

Target WCAG 2.2 AA: 4.5:1 normal text contrast, visible focus, keyboard-operable web controls, logical focus order, scalable text without clipping, labelled fields, adjacent recovery-oriented errors, and no gesture-only action. English LTR is in scope; Hebrew/RTL support is intentionally deferred.

## Design evaluation

Before acceptance, score representative Home, Recipe Review, Trip Detail, and Archive screens on visual coherence, hierarchy, legibility, originality, emotional appeal, usability, accessibility, and craftsmanship. Acceptance target: 32/40 with no dimension below 3. A current pre-implementation review is recorded in `SKILL_USAGE.md`.
