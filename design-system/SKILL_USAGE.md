# Design skill usage record

Every available design-related skill was reviewed before UI implementation. Specialist techniques contribute an explicit applicability assessment; PantryPal remains a Flutter Material 3 application and does not gain a web, React, or 3D runtime dependency merely to demonstrate a skill.

| Skill | Why it applies or perspective | Action taken | Decision or rejection produced | Artifact or screen affected |
|---|---|---|---|---|
| imagegen | Raster archive fallback | Generated square finished-dish cover | Use as archive fallback; icon stays vector-native | `assets/images/archive-fallback.png` |
| brand | Identity and voice | Defined warmth, specific action copy, pantry-window motif | Adopted | Master, shell |
| design | Cross-discipline identity review | Reconciled plan’s fixed colours/type with system | Adopted fixed direction | Master |
| design-system | Token architecture | Created primitive→semantic→component model | Adopted | Master, theme |
| frontend-design | Distinctiveness critique | Chose a single pantry-window signature; avoided template stats | Adopted | Shell and empty states |
| impeccable | UX, responsive, states review | Defined empty/loading/error/accessibility contracts | Adopted | All feature screens |
| anti-slop | Generic-pattern audit | Rejected generic gradients, decorative stats and vague copy | Adopted | Copy and components |
| ui-styling | Component state consistency | Specified stateful buttons, cards, chips, semantic tokens | Adapted to Flutter Material 3 | Theme/widgets |
| ui-ux-pro-max | Planning and responsive UX | Validated five-destination mobile IA and adaptive rail | Adopted | Navigation |
| modern-web-design | Current web quality/accessibility pass | Selected responsive PWA, visible focus and performance restraint | Adapted; no web-only widgets | Web shell |
| design-evaluation-scoring | Quantitative quality gate | Set 32/40 threshold and eight dimensions | Adopted | Phase 6 review |
| design-motion-principles | Motion critique | Set 180–220ms, interruptible, reduced-motion behavior | Adopted | Feedback/transitions |
| israeli-accessibility-compliance | Accessibility specialist pass | Assessed semantic and touch guidance | English/RTL law-specific rules deferred by scope | Accessibility audit |
| banner-design | Marketing composition | Assessed hierarchy and image/copy balance | No banner surface in MVP; no runtime impact | N/A |
| slides | Presentation storytelling | Assessed for stakeholder docs | Not an in-app requirement | N/A |
| animated-component-libraries | Prebuilt animated React components | Assessed interaction patterns | Rejected: React/Tailwind stack incompatible | N/A |
| animejs | Timeline animation | Assessed choreographed motion | Rejected: native Flutter motion is sufficient | N/A |
| gsap-scrolltrigger | Scroll animation | Assessed scroll-driven visuals | Rejected: harms task-focused/accessible flow | N/A |
| barba-js | Page transitions | Assessed route transitions | Rejected: browser/React pattern incompatible | N/A |
| locomotive-scroll | Smooth scrolling | Assessed scroll treatment | Rejected: conflicts with predictable native scroll | N/A |
| lottie-animations | Animated vector assets | Assessed loading/empty-state asset option | Deferred; no asset requiring it yet | N/A |
| motion-framer | React motion | Assessed state-motion patterns | Rejected: Flutter stack incompatible | N/A |
| react-spring-physics | Physics motion | Assessed playful interactions | Rejected: nonessential and Flutter-incompatible | N/A |
| rive-interactive | Interactive vector state machines | Assessed rich illustration option | Deferred; no stateful art needed for MVP | N/A |
| scroll-reveal-libraries | Simple reveal effects | Assessed content reveals | Rejected: information UI needs stable layout | N/A |
| pixijs-2d | High-performance canvas | Assessed archive collage rendering | Rejected: native layout handles it | N/A |
| lightweight-3d-effects | Decorative depth | Assessed subtle elevation/tilt | Rejected: plan requires flat rounded surfaces | N/A |
| aframe-webxr | WebXR | Assessed immersive possibilities | Rejected: no VR/AR product need | N/A |
| babylonjs-engine | 3D engine | Assessed 3D visualisation | Rejected: not relevant/stack incompatible | N/A |
| blender-web-pipeline | Web 3D export | Assessed asset pipeline | Rejected: no 3D assets needed | N/A |
| playcanvas-engine | Browser game engine | Assessed realtime scene use | Rejected: not relevant | N/A |
| react-three-fiber | React declarative 3D | Assessed 3D component patterns | Rejected: Flutter stack incompatible | N/A |
| spline-interactive | No-code interactive 3D | Assessed decorative scene use | Rejected: no 3D requirement | N/A |
| substance-3d-texturing | PBR materials | Assessed visual asset production | Rejected: flat illustration direction | N/A |
| threejs-webgl | WebGL 3D | Assessed web rendering option | Rejected: no 3D requirement | N/A |
| web3d-integration-patterns | Combined 3D/motion architecture | Assessed integration complexity | Rejected: no constituent runtime selected | N/A |

## Implementation follow-up

Stitch generated the mobile signed-out PantryPal experience in project
`17784570670142129014`. Its concrete decisions were translated into the Flutter
identity surfaces: a flat kitchen-mark signature, calm labelled forms, and
terracotta primary actions. The artifact and the connector limitation are
recorded in `STITCH.md`.
