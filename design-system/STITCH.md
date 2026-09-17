# Stitch design record

Stitch was used for the first implemented PantryPal front-end vertical slice.

- Project: `projects/17784570670142129014` (PantryPal MVP, private)
- Uploaded direction: `projects/17784570670142129014/screens/8513252392855706849`
- Generated session: `3795495774214573504`
- Screen: **Sign in - PantryPal**, generated with Gemini 3.1 Pro for mobile.

The generated screen established a warm, flat, adult-friendly sign-in treatment:
cream canvas, terracotta primary action, an outlined cupboard/kitchen signature,
Baloo 2 display text, Nunito Sans body text, labelled inputs, thin borders, and
no gradients or elevated-card shadows. Flutter implementation in
`apps/client/lib/features/auth/auth_page.dart` adopts those decisions rather
than copying generated HTML into a non-web runtime.

Stitch's `create_design_system_from_design_md` endpoint rejected the returned
uploaded screen instance with `Request contains an invalid argument`; screen
generation nevertheless produced the inferred PantryPal design system and
screen successfully. The source visual contract remains `MASTER.md`.

## Phase 2 reference set

The same private project and existing PantryPal Design System asset
(`assets/e6d9b1f83a294fa1aed96c6846e97f39`) generated the next Flutter
translation references with Gemini 3.1 Pro:

- **Plan - PantryPal:** `projects/17784570670142129014/screens/44e06dcb131d4769842785aead146ca5`
  — scheduled meals, date strip, responsibility states, and cooking editor.
- **Shop - PantryPal:** `projects/17784570670142129014/screens/f61e502954ce43d1abedac7e2c1bf774`
  — confirmed-trip context, contribution labels, pantry recheck, and shopping action.
- **Archive - PantryPal:** `projects/17784570670142129014/screens/c329811c3c3f471d9f2449e044cb982d`
  — archive month collages, day detail, and immutable-history Cook again action.

These are visual references only. Their generated HTML is not product code;
Stage 3 translates the approved hierarchy, states, and interaction intent into
the existing Flutter runtime and semantic theme.
