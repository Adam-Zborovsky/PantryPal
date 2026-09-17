# PantryPal Design System

## Product

Invite-only household recipe planner for Android and responsive web/PWA. Turns recipe
links and shared media into reviewable recipes, scalable meal plans, coordinated
shopping trips, pantry checks, and an immutable cooking archive.

**Users:** every member of a household, any age. The app must read at a glance for a
tired parent mid-shop and still delight a kid checking what's for dinner.

**Feel (one sentence):** An interesting, unique-looking app that feels like a
hand-painted diner board in a family kitchen: loud, warm, playful, never corporate.

**Register:** product. Design serves the household loop (import → plan → shop → cook
→ archive), but the identity is the differentiator; blandness is the enemy.

**Anti-references:** default Material blue/purple, Inter/Roboto everywhere, SaaS
dashboard card grids, glassmorphism, gradient text, hero-metric layouts. If it could
be mistaken for AI-generated admin tooling, it's wrong.

## Color

Strategy: **Committed** — tomato carries the brand moments, butter carries action,
cream is the world everything sits on.

Primitive tokens (light theme):

| Token | Value | Role |
|---|---|---|
| `cream` | `#FFF7E8` | App canvas / scaffold background |
| `paper` | `#FFFFFF` | Card and sheet surfaces |
| `tomato` | `#E23D28` | Primary brand: active states, brand marks, primary emphasis |
| `butter` | `#FFD447` | Action color: primary buttons, highlights, selected indicators |
| `ink` | `#23283B` | Text, borders, hard shadows — never pure black |
| `green` | `#3E8E4C` | Positive/done states |
| `amber` | `#B45309` | Attention states ("Check pantry", "Got some") |
| `line` | `#F0E8D6` | Warm hairlines inside bordered containers |

Dark theme: deep ink-navy canvas (`#1D2029`) and surface (`#272B38`); borders become
warm light hairlines (`rgba(255, 247, 232, 0.14)`), never light-gray. Butter and
tomato keep their roles.

Status color roles (shopping items):

- positive (Already have it / Bought) → green
- attention (Check pantry / Got some) → amber
- active (Buy) → tomato
- neutral (Skip) → muted outline

Never derive these from `ColorScheme.fromSeed` seeds; use explicit tokens.

## Typography

- Display/headings/titles: **Fraunces** black or bold (900/700). Slightly tight
  letter-spacing. Uppercase section labels at small sizes with +6% tracking.
- Body/UI: **Work Sans** 400/500/700.
- Hierarchy comes from scale + weight contrast (≥1.25 between steps), not from
  adding containers.
- Handwriting accents are allowed sparingly (empty states, celebration moments);
  never for data.

## Shape & elevation

- Corner radius scale: 13 (rows/small controls), 16 (cards/sheets), 999 (badges).
- Cards: white surface, **2px ink border**, no blur shadow. Hard offset shadows
  (`4px 4px 0 ink`) reserved for hero panels, CTAs, and featured meal cards only.
- One card tier per purpose; nested cards are always wrong.
- Lists inside cards: warm hairline separators (`line`), no per-item leading icons.
  State is carried by the right-aligned status sticker badge.

## Components

- **Primary button:** butter background, ink text, 2px ink border, radius 16.
  Destructive/danger stays tomato.
- **Status sticker:** pill, 2px ink border, soft tinted background matching its
  color role, Work Sans 700 ~11px.
- **Section labels:** Fraunces uppercase small, tracked out.
- **Archive meal card:** media block on top (screenshot thumbnail until replaced by
  a live photo), title + date below, inviting photo CTA always visible while the
  screenshot placeholder shows.

## Motion

- Ease-out curves only (ease-out-quart family). No bounce, no elastic.
- Staggered entrance for lists (~30ms/card), AnimatedSwitcher on reloads,
  hero-style transition from trip list into trip detail.
- Confirmations get a small scale-pop, not confetti.

## Voice & copy

Warm, plain, family-facing. Statuses are verbs people say: Buy, Already have it,
Check pantry, Got some, Bought, Skip. No raw enums, no ISO timestamps in UI,
no "error code" language without a human sentence around it.
