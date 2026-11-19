# AutoX marketing revamp — layout plan

Date: 19 November 2026  
Status: Reviewed for implementation on 19 November 2026.  
Scope: `site/` marketing application. Six main pages, shared navigation/footer, and matching legal-page chrome.  
Companion: [Implementation plan](2026-11-19-marketing-implementation-plan.md).

## 1. Direction and boundaries

Build a digital-garage marketing site for private vehicle owners and fleet operators. The homepage should make AutoX understandable, show the actual product, and route visitors to personal use or fleet/demo. The visual direction follows Trenova's framed page grid, bold typography, illustrated storytelling, restrained controls, amber footer, and render/reveal rhythm.

Use the agreed car-to-city highway hero: square-cell dithering, sunset in light mode, crescent moon and stars in dark mode, a larger, closer rear-view car, moving road texture/markings, and subtle environmental movement. The scene fills the framed background behind readable HTML hero copy. Use standard ASCII characters for all other illustrations. Keep existing product screenshots unfiltered.

This is a marketing presentation change. Preserve the current routes, feature claims, pricing data, contact behavior, translation system and conversion destinations. Shared product themes, Flutter, admin and fleet applications remain a later project. Do not add dropdown products, fake dashboards, customer logos, testimonials, blog pages, newsletters, hosting choices or capabilities to fill the reference's larger sitemap.

## 2. Reference findings and design critique

The original browser study recorded the hero, footer, demo composition and reveal timings below. The November 19 follow-up checked the published homepage and pricing content. It uses the earlier study for motion and demo styling. AutoX's catalog remains authoritative. [Trenova homepage](https://trenova.app/) · [Pricing](https://trenova.app/pricing/)

| Reference pattern | AutoX decision |
| --- | --- |
| The homepage puts its two entry paths directly under the promise. Further down, each Desk view pairs a task with a product capture. | Give owners and operators a route in the hero. Follow with three things an owner can recognize in the app. [Homepage](https://trenova.app/) |
| The pricing receipt names a plan and period. Each plan then presents the same three capacity measures before its feature list. | Give vehicles, sharing and storage consistent positions on every AutoX plan. Keep the receipt a quiet illustration of a garage expense. [Pricing](https://trenova.app/pricing/) |
| Framed, square-dithered highway hero | Retain chosen city/car composition and light/dark sky states |
| Large headlines with amber emphasis | Keep the demonstrated treatment for the main message; avoid highlighting arbitrary phrases throughout every page |
| Rich product dropdown menus | Replace with direct links because AutoX has six main screens |
| Alternating explanations, artwork and screenshots | Use a few substantial feature bands, not a new screenshot for every feature |
| Pricing hero with receipt graphic and comparison grid | Give all subscription amounts, periods and limits to the selectable plan grid |
| FAQ accordion block | Adapt into a categorized standalone page for AutoX's larger question set |
| Demo illustration and short lead form | Adapt the composition while retaining AutoX's current full form and validation |
| Large amber footer with character art and lower pattern | Use amber in both modes, a compact existing-link sitemap, standard-character artwork and contact row |
| Reveal opacity/translate animation | Reuse measured visual timing; progressively enhance visible server-rendered content |

The skill's usual cautions about square borders, monospace labels, indexed sections and highlighted type are deliberate exceptions here: the user explicitly chose that reference. The individuality comes from car ownership, AutoX's existing content and an original city/car scene. Avoid copying the reference's freight terminology, rocket, mountain landscape or unnecessarily large navigation. Do not turn every section into the same generic card grid.

## 3. Compact visual system

### Color

| Name | Hex | Use |
| --- | --- | --- |
| Black | `#000000` | Dark page canvas; text on amber |
| Paper | `#F7F7F5` | Light page canvas; dark-mode primary text |
| Amber | `#FFA31A` | Signature emphasis, primary accent, entire footer |
| Charcoal | `#101010` | Dark secondary surface and dark controls |
| Slate | `#A7A7A0` | Dark supporting text, subject to contrast checks |
| Deep amber | `#965100` | Small accent text/focus on light surfaces |

Borders use semantic mode-specific neutral tokens; component boundaries/focus must meet contrast requirements even where decorative grid rules are subtle. The poster has a separate, limited illustration palette for sky, buildings, grass and vehicle pixels. Illustration colors are not UI status colors. Dark body surfaces stay black/neutral rather than returning to navy.

The amber footer is an explicit marketing-only exception to the current shared rule against large gold fills. Record that exception before implementation. Black text on amber is the default; do not use white text on amber controls. Amber focus indicators need a black companion outline when the background is already amber.

### Type and sizing

- IBM Plex Sans, self-hosted: headlines, paragraphs, navigation and controls. Use 600 for major English headlines, with the broader proportions demonstrated in the sample. This is a marketing-specific change from Barlow headings, not a product font migration.
- IBM Plex Mono, self-hosted: standard-character art and small structural labels. Body copy stays proportional.
- English desktop hero: roughly 80–96px; section headings 44–56px; body 16–18px with 1.6–1.75 line height. Mobile headings scale to approximately 36–44px, with minimum readable body text.
- Myanmar: preserve the `my` locale and glyph-appropriate fallback; review actual font coverage. Keep approximately 1.4 heading/1.7 body line height rather than applying compressed English leading. Do not hard-code English line breaks into translated headings.

### Grid and shapes

- Maximum content frame: 1280px. Desktop header, hero, content, CTA and footer inner columns share rails.
- Desktop: 12-column alignment, typically 5/7 or 6/6 feature splits; 40–48px inner gutters; 80–96px vertical section spacing.
- Tablet: 24–32px gutters. Stack when content needs it rather than retaining cramped two-column sections.
- Mobile: 12–16px outer frame allowance, 20–24px content padding, 48–56px section spacing. Touch targets remain at least 44px.
- Square controls and panels; thin neutral separators; no floating capsule header, glass, colored gradients, glow shadows or bouncing cards. Screenshots retain real device/browser framing and natural proportions.
- Primary content is left aligned. Center only the homepage hero and simple closing statements. Section indices can serve as a short page index; actual onboarding steps alone imply sequence.

## 4. Shared navigation

```text
AutoX logo       Personal   Fleet   Pricing   FAQ       EN / MY   Theme   Request a demo
```

The logo links to `/`; the four text links keep their existing destinations. `/demo` is the single prominent navigation CTA. No desktop dropdowns or mega menus. Active pages receive a quiet state and `aria-current`, not a glowing pill.

Use a solid, approximately 65–72px sticky header. At the width where translated links no longer fit, use one flat mobile menu with Home, Personal, Fleet, Pricing, FAQ and Request a demo. It is the same sitemap, not a nested product menu. Retain theme and language controls, close on navigation/Escape, and restore focus appropriately. Anchor offsets account for the sticky header.

## 5. Page layouts

### Homepage `/`

```text
Shared direct-link header
+---------------------------------------------------------+
|        Ownership headline and supporting copy           |
|           Explore personal use   Explore fleet management |
|      [square-dithered city-highway poster behind text]    |
+---------------------------------------------------------+
| Offline-first | Reminders | History | Multiple vehicles  |
+---------------------------------------------------------+
| Product-tour tabs               Actual phone screenshot |
+---------------------------------------------------------+
| Offline/history explanation     Standard ASCII dossier   |
+---------------------------------------------------------+
| All six feature highlights, grouped in a compact catalog |
+---------------------------------------------------------+
| Personal path                    Fleet path              |
+---------------------------------------------------------+
| Existing audience groups + three onboarding steps        |
+---------------------------------------------------------+
| Download area (#download) + pricing/FAQ links             |
+---------------------------------------------------------+
Shared amber footer
```

- Keep the current ownership value proposition; the preview's shortened headline is composition guidance, not an automatic copy replacement.
- Use the existing two path labels and links in the hero. Give Personal the filled control and Fleet the adjacent outlined control. The header already offers a direct demo request. Keep both paths ahead of the skyline in mobile reading order. If the Myanmar copy fills the sky, grow the text area and place the scene below it. The prototype's mobile height is a starting composition, never a text limit.
- Keep installation in the closing `#download` section with one badge per configured store. With neither store configured, use the Personal link and a localized invitation to explore personal use. Fold this section into the home footer invitation so visitors encounter one installation choice at the end.
- Give the phone tour three task captions. Dashboard shows the selected car and its odometer. Fuel shows litres and MMK for each fill-up. Maintenance shows the next tyre rotation by date and mileage. Use a short localized sentence for each, alongside its real capture. The refuel image supports the petrol example; charging remains in the feature copy. On desktop align the selected row with the phone. On mobile put the controls above the active caption and image. Render the default view on the server and keep one reserved image area across selections.
- The six current highlights remain visible: Maintenance, Fuel or Charging, Mileage, Costs, Reminders, Multiple Vehicles. A three-group catalog can pair Care (maintenance/reminders), Running costs (fuel/costs), Garage (mileage/multiple vehicles). Group labels do not replace the actual feature descriptions.
- Keep all five current audience groups in compact rows rather than five large cards. Preserve the existing three steps: create account, add vehicles, start logging.
- The tour replaces the current separate repeated screenshot showcase. Do not show the same three phone screens again just to make the page longer.

### Personal `/personal`

```text
Split hero: existing promise + CTA      Actual garage screenshot
Problem / solution rows                ASCII paperwork-to-records scene
Fuel & expenses band                   Fuel screenshot
Maintenance & reminders band           Maintenance screenshot
Documents & sharing band               Standard ASCII dossier / shared garage
Existing benefits                      Short character illustration
Install / add vehicle / log steps       Download + pricing CTA
Shared amber footer
```

Preserve the hero badge/bullets, problem items, solution bullets and all six feature highlights. The three paired bands cover Fuel & Charging, Expenses, Maintenance, Reminders, Documents Vault and Vehicle Sharing. Keep the four benefits and the existing three onboarding steps. A one-off artwork can sit beside multiple related benefits; each claim does not need an illustration.

Use the actual garage image as hero proof. Avoid another full animated highway hero on this page; the homepage owns the signature moving scene. Put download access near the hero and closing CTA, using the existing destinations.

Give each feature band one ownership question. The fuel band answers “What did my last fill-up cost?” with a dated entry showing litres and MMK. The maintenance band answers “When should I rotate my tyres?” with the due date and remaining distance visible together. For documents and sharing, use the service dossier illustration and existing copy about access. Place captions outside the art so Myanmar readers have the same evidence.

### Fleet `/fleet`

```text
Split hero: existing fleet promise      Actual portal dashboard
Challenges / benefits                   Standard ASCII workshop board
Talk to us / add fleet / manage steps   Demo CTA
Four grouped module bands              ASCII work order / checklist / reports
Existing manual-vs-AutoX comparison     Ruled comparison table
Existing eight industries              Compact text index
Request a demo / pricing CTA
Shared amber footer
```

Use the portal dashboard once as the primary product proof, large enough to read. Do not fabricate screenshots for modules without assets. Preserve all eight modules, paired into Operations (Work Orders, Inspections), People & workshops (Driver Assignments, Workshop Management), Vehicle records (Warranty Templates, Vehicle Lifecycle), Reporting (Cost Analytics, Reports & CSV). Retain each original module description.

Keep the current challenges, six benefits, comparison rows, eight industries and three steps. Use text/diagram-led bands for these rather than repeating the portal screenshot. Primary CTA remains `/demo`; secondary remains `/pricing`.

The portal asset actually opens Fleet analytics. Caption the monthly operating-cost chart and cost per km, and put the guided-onboarding note beside the demo button. At phone width stack the copy, actions and image. A detail crop of the original chart can use the available width. Keep its title, axis labels and legend together so the reader can interpret the bars.

### Pricing `/pricing`

```text
Pricing headline + explanation         Standard-character receipt illustration
Monthly / annual selector              Live catalog or snapshot note
+-------------+-------------+-------------+-------------+
| Actual plan | Actual plan | Actual plan | Actual plan |
+-------------+-------------+-------------+-------------+
Included perks / ownership art
Grouped feature-comparison table
Selected existing pricing FAQs + full FAQ link
Contextual personal / fleet CTA
Shared amber footer
```

Adapt Trenova's receipt-and-plan-grid composition, not its plan names, prices or policies. The bundled AutoX snapshot currently has Free, Lite, Standard and Fleet/Pro; render the actual returned plan list. Preserve the live API path, offline snapshot note, localization, highlighted-plan state, monthly/yearly units, MMK primary/USD secondary amounts, storage and limit formatting, annual-billing messaging and existing CTA behavior.

Draw a garage receipt with a torn edge and item lines. Omit amounts from the art. Lead each plan with its name and audience, followed by its MMK total and period, USD equivalent and billing note. Align three rows for vehicle limit, sharing limit and storage. Read these from each returned plan's `limits` and retain the catalog's unlimited semantics. A visitor comparing two plans should find vehicle allowance at the same position in each. Keep longer feature lists below these rows. On mobile stack the plans and keep the full comparison inside a labeled, keyboard-scrollable region. Link the pricing questions directly to `/faq#plans`.

### FAQ `/faq`

```text
Clear title + short intro               Small standard ASCII question/dossier graphic
Category index                          Category headings and ruled accordions
                                        All existing questions and answers
Pricing / download / demo support paths
Shared amber footer
```

Trenova's inspected pricing page includes a FAQ block; the standalone AutoX category layout is an adaptation, not a claim of a matching standalone Trenova page. Preserve AutoX's nine category anchors and all 44 questions/answers. Desktop: narrow sticky category index and a readable answer column; mobile: wrapped category links followed by the same content. Retain native `details/summary`, clear focus and open-state indicators. No new search engine is necessary for this revamp.

### Request a demo `/demo`

```text
Existing demo heading / explanation     Existing full request form
Standard ASCII fleet/workshop scene     First and last name
Existing proof points                  Email / phone
Configured email alternative           Company / job title / message
                                       Submit + privacy note
Shared amber footer
```

Use Trenova's illustration-led, framed demo composition. Adapt the artwork to a fleet handover/workshop rather than copying its rocket. Preserve AutoX's full form, including the rule requiring first and last name plus at least one valid email or phone. Optional company, job title and message remain optional. Preserve submitting, success, mail-app fallback, error and send-another states. Never replace the full request flow with the reference's email-only form.

On mobile use the order heading, short invitation, form, proof points and email alternative. Move the workshop art to the proof block. The first name field should follow the invitation directly in both reading and keyboard order.

## 6. Shared amber footer

Use the reference's large amber finishing section in both themes, with black text and controlled whitespace. Adapt its size and column count to AutoX's smaller sitemap.

```text
AMBER BAND
Download / personal invitation                      Store badges / demo link
--------------------------------------------------------------------------
Official AutoX brand + character car     Product        Help          Legal
Existing tagline                        Personal       FAQ           Privacy
                                        Fleet          Demo          Terms
                                        Pricing        Contact       Delete account

                                        Large configured contact email
--------------------------------------------------------------------------
Copyright                               Existing legal links
[wide standard-character city / road silhouette at the lower edge]
```

The official logo remains intact on its required logo plate. A new decorative character illustration can accompany it without replacing the brand mark. Use three useful link columns rather than padding the sitemap to match the reference's four columns. The top band replaces a newsletter signup with existing download/demo actions; no subscription form or new backend is introduced. Contact uses configured AutoX email data, not a copied address. Do not add source-code links, licenses, clocks or social accounts that AutoX does not already expose.

The lower silhouette uses standard characters because square-cell art is reserved for the hero. Legal links stay real text above the decoration. On mobile stack the CTA, brand, two-column link groups and contact; allow email wrapping and keep the artwork contained.

Use one closing invitation per page. On Home, the route owns the `download` anchor and badges just above the shared brand and link columns. On Demo, the form already supplies the action, so go directly to the shared columns. On the other marketing pages use the route's existing closing actions as the top band.

## 7. Screenshot and artwork budget

There are exactly five existing screenshot subjects, each with dark/light WebP variants:

| Subject | Primary role |
| --- | --- |
| `app-dashboard-{mode}.webp` | Homepage tour default |
| `app-fuel-{mode}.webp` | Homepage tour; personal fuel/expense band |
| `app-maintenance-{mode}.webp` | Homepage tour; personal care band |
| `app-garage-{mode}.webp` | Personal hero |
| `portal-dashboard-{mode}.webp` | Fleet hero |

The current Dashboard and Maintenance captures in both themes show an unresolved “# days” in the oil-change row. For the tour, frame the Dashboard's vehicle and quick actions and the Maintenance tyre-rotation entry as truthful detail crops, or use refreshed captures of those same real screens. Preserve the product pixels. Check both modes at display size. Keep the full-frame presentation wherever the capture is suitable. The English UI in the existing assets needs explanatory **HTML** captions in both site languages.

Reuse across relevant routes is fine; repetition within the same page needs a reason. Mode changes select matching assets. Never dither product screenshots or invent screenshots of documents, reporting, sharing or work orders.

Prepare one square-cell hero scene plus a small reusable family of standard-character illustrations: service record/dossier, fuel gauge/receipt, shared garage, workshop/assignment board, checklist/report, help/question motif and footer city/road strip. Derive variations from these motifs rather than generating a unique complex graphic for every paragraph. Use ordinary ASCII characters such as `. : - = + * # % @ / | _`; no block-square glyphs outside the hero. Art is static by default, with at most a brief reveal; it does not compete with the hero's continuous motion.

## 8. Render and interaction animation

Measured reference behavior in the browser: reveal elements move from `translateY(14px)`/opacity 0 to their final state over 700ms with `cubic-bezier(0.16, 1, 0.3, 1)`. Pricing hero elements showed delays of 0, 60, 120 and 180ms. Use these as the initial motion spec, followed by side-by-side review, rather than claiming every reference animation has been reverse-engineered.

- Page entry: short hierarchy of heading, introduction, actions and visual. Start in the visible route; no full-screen loading animation.
- Scroll: reveal section groups once as they enter the viewport, using the 14px/700ms treatment and small 60ms staggers. Do not delay all 44 FAQ rows, every table cell or form field independently.
- Product tabs: a short opacity change, stable image area and no layout jump; no autoplay screenshot carousel.
- Menus, FAQ and controls: brief, user-triggered state feedback. Avoid spring/bounce or exaggerated hover lifts.
- Hero: keep the current driving style, pause/play, offscreen/tab-hidden suspension and a composed still for reduced motion.
- Theme: update palette, screenshot and sun/moon state together. Prototype a localized reveal only if it matches the reference well and remains fast; preserve the current theme persistence and avoid a theme-transition framework.
- Progressive enhancement: server-rendered content is visible with JavaScript disabled or failed. Animation must never strand text at opacity zero. Reduced-motion users see all content immediately; anchor/focus navigation must not land inside a delayed invisible group.

## 9. Layout acceptance

Review all six routes in English/Myanmar and light/dark. Check 320, 390, 768, 1024 and approximately 1440–1920px desktop widths. The hero grid and rails should align with the supplied reference at wide sizes while headings, CTAs, sun/moon and the larger car remain visible on mobile.

A content audit must account for every existing feature, benefit, audience, step, comparison row, pricing state and FAQ answer. The official logo, legal routes, `#download`, category anchors and current request/download destinations must survive. New claims, screenshots, business policies and subscriptions are outside this plan.

## Theme source and latest viewpoint

The candidate theme now lives in `docs/theme/ascii-garage-dark.json` and `ascii-garage-light.json`, with migration notes in `docs/theme/README.md`. These preserve the active pair and are not selected by the current generator. The latest hero lowers the camera viewpoint: the horizon is at 74% of the frame, the city grows to approximately 23% of its height, and car width increases from about 6.9% to 11.5% of the frame width (with a mobile minimum). The current preview is retained; superseded concept pages, test captures and historical decision logs were removed.
