# AutoX marketing revamp — implementation plan

Date: 19 November 2026  
Status: First implementation pass complete in the local checkout. Visual refinement is scheduled for a later pass.  
Design source: [Layout plan](2026-11-19-marketing-layout-plan.md).  
Reference prototype: `site/public/theme-lab/trenova-study.html` and `highway-grid.js`.

## 1. Deliverable and scope

Revamp the six existing marketing routes (`/`, `/personal`, `/fleet`, `/pricing`, `/faq`, `/demo`) with a shared Trenova-inspired frame, direct navigation, standard-character feature illustrations, an amber footer and coordinated reveals. The homepage alone receives the square-dithered moving highway hero.

Legal routes `/privacy`, `/terms`, `/account-deletion` inherit the new shell and readable typography; their legal text does not change. The authenticated web, fleet portal, Flutter app, backend behavior, pricing contracts and environment configuration stay outside this change.

Use the current checkout when implementation starts; inspect status and applicable instructions again so user changes are preserved. Keep reviewable increments, and use the repository's branch/commit conventions (`codex/` when creating a branch). This plan does not create a branch, commit or deployment.

## 2. Verified starting point

| Area | Existing source / behavior | Required handling |
| --- | --- | --- |
| Framework | Next 15 / React 19, Tailwind 4; server pages and small client components | Keep architecture and dependencies |
| Shared layout | `site/src/app/layout.tsx` installs locale, theme bootstrap, navigation and footer | Keep preference resolution and metadata; change presentation |
| Shared tokens | Generated `site/src/app/theme-tokens.css` from shared Garage Minimal JSON | Do not hand-edit generated CSS or migrate all products |
| Marketing styles | `site/src/app/globals.css`: font mappings, aurora/glass/gloss, reveals, Myanmar and reduced-motion rules | Replace marketing treatment without accumulating conflicting overrides |
| Navigation/footer | `site/src/components/layout/site-nav.tsx`, `site-footer.tsx`; `site/src/content/site.ts` | Retain real destinations and configured contact data |
| Translation | `site/src/i18n/dictionaries/en.json`, `my.json`, `types.ts`, locale cookie and dictionary merge | Keep both languages; add any new structural labels in both |
| Pricing | `site/src/lib/pricing.ts`, `site/src/components/pricing/*` | Preserve live/fallback/localization/billing/currency behavior |
| FAQ | `site/src/components/faq/faq-category.tsx` and dictionary categories | Preserve IDs, native accordions and all 44 answers |
| Demo | `site/src/components/demo/demo-form.tsx` | Preserve validation, payload, endpoint/mailto, errors and success focus |
| Motion | `site/src/components/marketing/reveal.tsx` and `.reveal` CSS | Adapt existing wrapper; fix visible-without-JS behavior |
| Art prototype | `site/public/theme-lab/highway-grid.js` | Port the selected scene into a managed React lifecycle; do not ship the static prototype as the production route |
| Assets | Five WebP subjects × two modes, official logo and self-hosted fonts | Reuse; no fake screenshots |

The inspected `site/package.json` has `dev`, `build`, `start`, `lint`, API generation and theme generation scripts. It does not define a test script. Do not report an invented `npm test` result or install a broad new toolchain just to restyle pages.

## 3. Implementation design

### Marketing theme boundary

Before styling components, add a marketing-specific section to `docs/design-system.md` recording black/amber, broader Plex headings, square marketing panels and the large amber footer exception. The shared navy/brass product theme and mobile-card rules remain authoritative for their applications.

Create `site/src/app/marketing-theme.css` as the marketing token source. Import it after the existing generated token layer in `globals.css`, and scope it with a `marketing-site` class on this application's body. Define mode-specific semantic backgrounds, text, action, input, border and focus values once. Update the site-local Tailwind display-font mapping to Plex Sans. Use token references in components; avoid a second collection of inline hex overrides.

The site-local layer can override the semantic variables used by existing marketing components. It must cover hover/pressed/disabled, input/error, caption/link and focus states as well as backgrounds. Preserve status meaning; do not turn errors or overdue indicators amber. The poster's illustration palette is owned by the poster renderer, separate from UI tokens.

Keep `theme-tokens.css`, the active `docs/theme/garage-minimal-*.json` pair and `tools/generate-theme.mjs` unchanged for this marketing-only change. The new `docs/theme/ascii-garage-*.json` candidate pair records the chosen theme for later migration; it is not activated automatically. Running the shared theme generator is not the way to implement a site-only palette.

### Small shared component set

Reuse existing components where their job fits; avoid building a general page-builder or animation framework.

| Component / asset | Approach |
| --- | --- |
| `SiteNav`, `SiteFooter` | Restyle existing components; preserve locale/theme and link inputs |
| `PageFrame` / `FrameSection` | One small shared container/separator pattern for 1280px rails, gutters and optional split alignment |
| `SectionHeading` | Extend existing component for restrained reference typography; no repeated hard-coded page markup |
| `HighwayPoster` | New homepage client island with a static accessible fallback, pause control and renderer lifecycle |
| `highway-scene.ts` | Port procedural drawing/dithering from the prototype; separate mounting/cleanup from scene math |
| `AsciiArt` + artwork files | Small static standard-character art wrapper; decorative by default, accessible description when meaningful |
| `ProductTour` | Small client island selecting existing screenshots; real tabs and keyboard support |
| `PhoneFrame`, `BrowserFrame` | Retain image sizing/theme selection; remove float/glow presentation |
| `FeatureBand` | Minimal paired-copy/visual pattern for personal and fleet highlights, using existing dictionary data |
| `Reveal` | Reuse wrapper and observer; update movement, stagger and failure behavior |
| `PricingCard`, `FeatureTable`, `PricingToggle` | Restyle; keep price selection and rendering logic |
| `FaqCategorySection`, `DemoForm` | Restyle and preserve current functional implementations |
| `CtaBanner`, `StoreBadges` | Fit the frame/footer presentation; preserve valid-link-only behavior |

Only create helpers when two or more real usages justify them. Keep route composition in each existing `page.tsx` so content order remains obvious.

### Renderer lifecycle and fallback

- Server render hero copy, actions, frame dimensions and a theme-appropriate still of the same city/car composition. Canvas is decorative behind actual HTML; no canvas text for the headline.
- Render the still immediately; initialize the canvas after mount. Hide/replace the still only after a successful first frame. Canvas failure leaves the still and all CTAs usable.
- Use `ref`s, a resize observer and current resolved theme; keep the initial server/client markup consistent. Avoid document-wide class mutation to operate a component.
- Preserve square cells and one-pixel grid gaps; budget the cell count per viewport rather than multiplying work by unrestricted device pixel ratio.
- Target roughly 20fps; suspend when offscreen, paused or document-hidden. Reduced motion renders a single composed frame and removes the redundant play/pause control.
- Cleanup the animation frame, resize/intersection observers, media-query and visibility listeners on unmount. Route changes and React development remounts must not create duplicate loops.
- Generate/check both light and dark stills from the agreed composition; do not ship the old large foreground-car fallback alongside a different distant-car animation.
- Keep the existing pure-black page palette; dark blue is an illustration color inside the poster, not the body surface.

### Reveal implementation

Measured starting values: 14px upward reveal, 700ms duration, `cubic-bezier(0.16,1,0.3,1)`, 60ms delay steps. Treat them as motion tokens in site-local CSS.

Use CSS entry animation for a small hero hierarchy, with a visible final/default state even if JavaScript fails. For scroll reveals, server-render content visible; JavaScript only arms offscreen elements for reveal. Missing observer support, reduced motion or an initialization failure leaves content visible. Use one observer where practical and stop observing after entry. On focus/anchor navigation, reveal the target immediately.

Do not carry the prototype's missing page-reveal behavior into production: that prototype verifies the canvas/grid direction, not the final route-entry experience. Do not add a library solely for these opacity/transform effects.

## 4. Execution phases

### Phase 1 — Baseline and content contract

1. Capture current six-route desktop/mobile views and inventory all feature/benefit/audience/step/comparison/FAQ keys.
2. Record pricing live and bundled fallback rendering, monthly/annual behavior, destination rules and store URLs' configured/unconfigured states.
3. Record demo validation, submitting/error/sent/mailto/send-another states using local or mocked responses, not real external submissions.
4. Inventory the original screenshot pairs at intended display size. Dashboard and Maintenance show “# days” in the oil-change entry in both themes. Mark usable detail crops or refreshed real captures for every occurrence on Home and Personal. Record the actual Fleet analytics subject for caption and alt text. Preserve logo, metadata, legal content and anchor targets.
5. Record the marketing-specific design-system exception and target token/motion values.

Done when a content-coverage checklist maps every existing item to a planned section and functional baselines are recorded. This prevents accidental removal while reducing card repetition.

### Phase 2 — Shared foundation and shell

1. Add the marketing theme layer and font mapping; remove unused aurora/glass/gloss styles as their last consumers migrate.
2. Build the shared frame rails and section pattern; replace fixed floating capsule navigation with the solid sticky header.
3. Add a focus-visible skip link targeting the existing main landmark. Keep the four navigation links and demo CTA, with Escape and focus return in the flat mobile menu.
4. Build the shared amber brand, link and contact columns and lower illustration. Each marketing route places its closing actions immediately above those columns. Home owns the single `download` anchor. Demo's form supplies its closing action.
5. Apply the shell to all routes including legal pages. Verify the footer in both modes, not just dark.

Done when navigation, preferences, focus visibility, footer links and page rails work in English/Myanmar at desktop and mobile. A footer-only review should verify that no nonexistent subscription or social functionality was added.

### Phase 3 — Hero, art and motion primitives

1. Port the city/car poster into `HighwayPoster` and the typed renderer module; replace direct DOM globals with managed inputs/lifecycle.
2. Prepare matching static fallbacks and verify text remains readable over the square grid.
3. Produce the small standard-character art family from the layout plan, with mobile-safe widths and mode-aware ink.
4. Adapt `Reveal` and add coordinated entry/section animation tokens.
5. Implement the three tour views with matching localized captions, alt text and a fixed-aspect image area. Render Dashboard and its caption before hydration. Verify each selection updates its caption and image together and the same selection survives a theme change.

Done when theme switching, pause/resume, reduced motion, no-JS/canvas fallback, resizing, route unmount and keyboard tabs behave correctly. Review the wide hero beside the supplied reference and the 390px layout independently.

### Phase 4 — Home and personal routes

1. Place the existing localized Personal and Fleet links in the highway hero. Use the lower paths section for each audience's detailed benefits. Fit the full Myanmar heading, introduction and both links before positioning the skyline.
2. Remove the redundant repeat screenshot showcase while preserving its informational role in the tour.
3. Recompose Personal with garage hero proof and the three paired feature bands; keep all original problems, solution bullets, benefits and steps.
4. Use `#download` for the closing invitation. Exercise zero, one and two configured stores. With zero, render the Personal route and copy that makes sense without a download button. Keep the pricing and FAQ links reachable.
5. Translate new group/structural labels and review headline wrapping in both languages.

Done when all six homepage features, five audiences and three steps remain represented, and all six Personal highlights and four benefits remain represented. No filtered/synthetic product screenshots or missing download anchors.

### Phase 5 — Fleet route

1. Present Fleet analytics with its monthly operating-cost chart, cost-per-km caption, demo/pricing links and guided-onboarding note. Choose a readable mobile detail from the same capture if the full dashboard makes the chart illegible.
2. Reflow challenges, benefits, four paired module groups and onboarding with standard-character art.
3. Preserve the existing comparison rows in a semantic, responsive ruled table.
4. Keep all eight industries in a compact index and finish with the contextual demo CTA.

Done when all eight modules, six benefits and eight industries remain present, original comparison content survives, and no nonexistent module screenshots have been introduced.

### Phase 6 — Pricing, FAQ and demo

1. Pricing: split hero/receipt visual, rectangular monthly/annual control, data-driven plan grid, included perks, feature matrix and a few reused pricing FAQs linking to the full FAQ page.
2. Keep the receipt unpriced. Within each returned plan, align vehicle, sharing and storage limits under its MMK/USD totals. Use `formatLimit` with a localized unlimited label and `formatStorage` from `site/src/lib/pricing.ts`. Keep one billing-period state in `PricingSection`. Reuse localized payment questions from the FAQ's `plans` category and link to `/faq#plans`. Leave numeric entitlements on the pricing page to the catalog.
3. FAQ: category index and ruled native accordions; keep all nine IDs and 44 questions/answers. No unnecessary search or extra data source.
4. Demo: adapt the illustrated split layout while retaining every current form field/rule, endpoint/mailto behavior, payload shape, source marker and user-feedback state.
5. On mobile put the demo fields immediately after the invitation. Follow them with proof, artwork and email help. Preserve the DOM reading order when switching to the desktop split.

Done when pricing values, currencies, billing units, fallback note and actions are unchanged in behavior; FAQ anchors work beneath the sticky header; demo validation, errors and success focus work with mocked responses. An email-app fallback must say it opened/prepared an email, not falsely claim a request was delivered.

### Phase 7 — Visual and functional release checks

Run the checks below, resolve findings, then prepare a final six-page review. Replace the actual marketing routes rather than publishing `/theme-lab/` as the production site. Remove/exclude exploration HTML/screenshots from the deployment artifact once their role is complete; keep durable plans and approved source assets. Roll out the marketing application through its existing process only when implementation is complete and verified.

## 5. Validation matrix

| Area | Required verification |
| --- | --- |
| Content | Compare page inventory to baseline; no missing features, steps, benefits, FAQ answers or legal text |
| Viewports | 320, 390, 768, 1024 and 1440–1920px; localized nav breakpoints follow actual text fit |
| Modes/locales | All six routes in light/dark and `en`/`my`; no clipped glyphs, cropped highlights or theme flash |
| Navigation | Correct direct links, `aria-current`, flat mobile menu, Escape/focus behavior, anchor offsets, no horizontal page overflow |
| Screenshots | Correct subject/mode, aspect ratio and alternative text; no stretched frames or unstable layout while loading |
| Hero | Square cells/grid, frame alignment, visible city/car/sun/moon at narrow widths; pause stops frames, resume changes frames |
| Lifecycle | No duplicate loops after navigation/remount; stops offscreen/hidden; resize redraw works |
| Reduced/no motion | Composed still; no invisible reveal content; no long smooth scrolling; no redundant inactive control |
| Progressive enhancement | Readable SSR/no-JS content and default screenshot; static poster survives missing canvas/script |
| Keyboard/accessibility | Visible focus, tab arrow keys/Home/End, FAQ controls, errors tied to inputs, success focus; normal browser modifier shortcuts unaffected |
| Pricing | Live vs fallback, monthly/annual MMK/USD values and units, highlighted plan, dynamic plan count, null/unlimited/storage formatting, existing CTA routes |
| Demo | Missing names/contact, invalid provided contact, email-only/phone-only, mocked 200/non-200/network error, no-endpoint mailto, sending/disabled/reset states |
| Footer | Amber/black contrast, real destinations, configured email, valid store links, legal row and contained artwork |
| Performance | Compare measured production build against baseline; target LCP ≤2.5s, CLS ≤0.1 and INP ≤200ms at p75 when field data exists; lab results are proxies, not field proof |

Use three walkthroughs at the direction and coverage checkpoints. Repeat them at 390px with Myanmar copy as well as on desktop.

| Visitor question | Evidence of a successful walk-through |
| --- | --- |
| Where can I see what owning one car looks like? | From Home, reach Personal in one action. In the Home tour, select Fuel and identify volume and MMK on a fill-up. Switch to Maintenance and identify the next tyre rotation. Both captions describe the selected capture. |
| Can I see how the fleet tracks operating costs? | Take the Fleet action in the hero, locate the monthly chart, and reach the first demo field. On mobile, the form precedes the workshop illustration. |
| Which plan fits my garage? | Compare vehicle limits between adjacent plans, change the billing period and read the MMK total with its unit. Follow a paid personal plan to `/#download` and the Fleet plan to `/fleet`. Check the download landing with and without a store URL. |

Hero text must never wait for the animation bundle or a remote asset to appear. Preload only the necessary existing font/initial product image; lazy-load lower screenshots. Profile canvas work on a real mobile device. If it materially harms responsiveness, reduce frame rate/cell count or default constrained devices to the still rather than weakening form/navigation responsiveness.

## 6. Commands and test scope

From `site/`, run the existing `npm run lint`, `npx tsc --noEmit` (using installed TypeScript), and `npm run build`. All three passed for the first implementation.

Headless Chrome loaded each marketing route at 320, 390, 768, 1024 and 1440px in all four locale/theme combinations. Each returned HTTP 200 with one main heading and fit the viewport. Separate interaction checks covered the tour, theme switching, hero pause/resume, reduced motion, no-JavaScript content, menu focus, FAQ anchors and the demo email handoff. An isolated local fixture exercised one and two store links, a five-plan catalog with monthly and annual prices, and demo request failures, retry and success. The production build reported 106–113 kB of first-load JavaScript for the six routes. Real-device performance and visual-shift measurements are pending.

Use focused verification for the changed behavior, not tests that duplicate every CSS class. Appropriate automated coverage includes pricing-state preservation, form validation/submission states, reveal failure/reduced-motion behavior and animation lifecycle cleanup. Use the repository's existing test tooling if available when work starts; the current site has no declared test runner. Browser QA can cover the visual and interaction flows without adding a large testing dependency.

For animation, retain the successful prototype check: capture paired paused frames and paired running frames. Paused captures should remain identical; running captures should differ. Also assert canvas bounds/rail alignment and absence of horizontal overflow. Perform a real reduced-motion check in implementation rather than relying only on inspecting the media-query branch.

Do not send demo requests to real external recipients during QA. Use test-only local/mocked responses and inspect generated mailto links without sending mail.

## 7. Review checkpoints and completion

| Checkpoint | Reviewable result |
| --- | --- |
| Foundation | Real header/footer, mode tokens and rails on one working route |
| Direction | Finished homepage hero/tour plus one Personal and one Fleet feature band |
| Coverage | All six routes composed with actual copy, screenshots and both locales |
| Ready | Functional matrix passed, final screenshots and measured build/performance findings documented |

These checkpoints organize review; they are not additional permission gates or reasons to stop authorized implementation midway. No whole-system redesign is bundled into completion. The finished deliverable is the marketing application with its original business behavior, the selected reference-inspired layout/art/motion, and evidence that both modes, both languages and key conversion flows still work.

## Prepared theme sources and cleanup

`docs/theme/ascii-garage-dark.json` and `ascii-garage-light.json` are now prepared with matching semantic keys and marketing grid/footer/hero/reveal tokens. Follow `docs/theme/README.md` for activation boundaries. When implementation starts, map the site theme layer from this candidate source rather than introducing a competing palette. The current prototype remains isolated from the generator. The hero viewpoint has been adjusted for a larger city and car; use the latest prototype rather than deleted historical screenshots. Only these two current plans remain in `docs/design-explorations/`.
