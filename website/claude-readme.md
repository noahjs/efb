# Tropiq — Website Build Specification

> **Brief better. Fly smarter.**
> Tropiq is a next-generation Electronic Flight Bag (EFB) for general aviation pilots, competing with ForeFlight on iOS and Android.

---

## 1. What Is Tropiq?

Tropiq is a modern flight planning app for general aviation (GA) pilots. It combines real-time weather, vector charts, route planning, weight & balance, fuel planning, and a logbook into a single cross-platform app (iOS + Android). The name evokes the **tropopause** — the atmospheric boundary where weather happens — with a modern "q" ending that gives it a tech-forward feel.

### Core Differentiators
- **Cross-platform**: iOS + Android (ForeFlight is iOS-only)
- **Modern performance**: 60fps vector chart rendering
- **Transparent pricing**: Simple tiers, no surprise upsells or feature removal
- **Pilot-first engineering**: Domestic team, no offshore pivot
- **Easy migration**: Import ForeFlight waypoints, logbooks, aircraft profiles in minutes

### Market Context
ForeFlight dominates the EFB market but is experiencing major disruption. Thoma Bravo acquired it from Boeing for $10.55B in late 2025, immediately laid off 30–40% of the workforce, raised prices 20%, and began moving engineering offshore. Pilots are actively looking for alternatives. Tropiq is positioned to capture that demand.

---

## 2. Tech Stack

Build with:
- **Next.js 14+** (App Router)
- **Tailwind CSS v4**
- **Framer Motion** for animations
- **TypeScript**
- **Inter** (Google Fonts) as primary typeface
- **JetBrains Mono** (Google Fonts) for aviation data displays

Deploy target: Vercel

---

## 3. Brand Identity

### 3.1 Brand Personality

| Attribute | Meaning |
|-----------|---------|
| **Confident, Not Cocky** | We never name competitors or attack them. We let comparison be self-evident. |
| **Pilot-Fluent** | We use real aviation terms naturally (METAR, VOR, TFR). The audience knows what they mean. |
| **Modern & Precise** | Visual language borrows from the best consumer tech. No skeuomorphism. Every element earns its place. |
| **Transparent** | No surprise tier upgrades, no features held hostage behind paywalls. |
| **Pilot-First** | Every decision filters through: "Does this make the pilot's flight better?" |

### 3.2 Design Reference Points

Tropiq should look like **Linear.app, Vercel, Arc Browser, or Figma** — not like a traditional aviation company. We look like a technology company that deeply understands aviation.

**Do NOT reference** the visual style of ForeFlight (institutional), 8Flight (aggressive/scrappy), Garmin Pilot (hardware-manual aesthetic), or FlyQ (dated).

---

## 4. Color Palette

### Primary Colors

| Name | Hex | CSS Variable | Usage |
|------|-----|-------------|-------|
| Midnight Navy | `#0A1628` | `--color-navy` | Primary dark: app bg, nav, hero sections, footer |
| Tropiq Teal | `#00C9A7` | `--color-teal` | Primary accent: CTAs, links, brand mark, success states |
| Sky Blue | `#38BDF8` | `--color-sky` | Secondary accent: hover states, secondary CTAs, data viz |

### Neutrals

| Name | Hex | CSS Variable | Usage |
|------|-----|-------------|-------|
| White | `#FFFFFF` | `--color-white` | Backgrounds, card surfaces, text on dark |
| Warm White | `#F8FAFC` | `--color-warm-white` | Alternating sections, subtle bg tint |
| Slate | `#64748B` | `--color-slate` | Body text on white, secondary labels |
| Deep Slate | `#1E293B` | `--color-deep-slate` | Headings on light backgrounds |

### Semantic / Status Colors (Aviation Standard)

| Name | Hex | Usage |
|------|-----|-------|
| VFR Green | `#22C55E` | Flight category VFR, success states |
| IFR / Caution | `#F59E0B` | IFR conditions, caution states |
| LIFR / Alert | `#EF4444` | LIFR alerts, error states, TFRs |

### Color Rules
- Tropiq Teal is the primary CTA color on both light and dark backgrounds
- Never rely on color alone — always add labels/icons for accessibility
- All text must meet WCAG AA contrast minimum
- Midnight Navy + white or teal text = high contrast hero sections
- Alternating page sections: white → warm white → white

---

## 5. Typography

### Type Scale

| Element | Font | Weight | Size | Tracking | Color (Light BG) |
|---------|------|--------|------|----------|-------------------|
| Hero Headline | Inter | Bold (700) | 48–64px | -0.02em | Midnight Navy |
| Section Headline | Inter | Semibold (600) | 32–40px | -0.01em | Midnight Navy |
| Subsection | Inter | Semibold (600) | 24–28px | 0 | Deep Slate |
| Body | Inter | Regular (400) | 16–18px | 0 | Slate |
| Caption / Meta | Inter | Medium (500) | 13–14px | 0.01em | Slate (60% opacity) |
| Button / CTA | Inter | Semibold (600) | 15–16px | 0.02em | White on Teal |
| Aviation Data | JetBrains Mono | Regular (400) | 14–16px | 0.02em | Context-dependent |

### Typography Rules
- Negative letter-spacing on headlines (tighter = more premium)
- Body line-height: 1.5–1.6; Headline line-height: 1.1–1.2
- JetBrains Mono used **only** for aviation data (METARs, TAFs, frequencies, coordinates)
- Fallback stack: `Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif`
- Mono fallback: `'JetBrains Mono', 'Fira Code', 'SF Mono', monospace`

---

## 6. Voice & Tone

### We Sound Like
A sharp, knowledgeable pilot friend who also happens to be a great software engineer. Calm and direct, like a good ATC controller.

### Copy Rules

**We say:** modern, fast, precise, clear, transparent, pilot-first, cross-platform, pilots, aviators

**We never say:** revolutionary, game-changing, disruptive, affordable (implies cheap), users, customers, subscribers, "the ultimate/best EFB," "unlike [competitor]"

**Never name competitors.** Let comparison be self-evident. If showing a contrast, use "the old way" vs "the Tropiq way" — never logos or names.

### Key Headline Copy

- **Hero**: "Your flight bag, finally modernized."
- **Subhero**: "Beautiful maps. Real-time weather. Transparent pricing. On iOS and Android."
- **Feature**: "60fps chart rendering. Because your sectional shouldn't stutter at FL180."
- **Pricing**: "One plan. Everything included. No surprises at renewal."
- **Android**: "Fly with the device you already own."
- **Migration**: "Switch in five minutes. Bring your waypoints, aircraft, and logbook."
- **Weather**: "Weather in plain English. Because a good preflight shouldn't require a meteorology degree."

---

## 7. Layout & Design System

### Global Layout
- Max content width: **1280px**, centered
- Section padding: **80–120px** vertical
- Full-bleed sections alternate between white and warm-white backgrounds
- Dark sections (Midnight Navy) used for hero, cross-platform callout, and final CTA

### Component Specifications

#### Navigation
- **Sticky** header
- Transparent background → solid Midnight Navy on scroll (with backdrop-blur)
- Logo left, nav links center, teal CTA button right
- Mobile: hamburger icon → full-screen overlay menu
- Nav links: Features, Pricing, Weather, Blog
- CTA: "Get Early Access" (pre-launch) or "Download" (post-launch)

#### Hero Section
- Full-width Midnight Navy background
- Large headline + subheadline left-aligned or centered
- Two CTAs: primary teal filled ("Get Started") + secondary white outline ("See Features")
- Right side or below: floating iPad/phone mockup with app screenshot
- Subtle parallax on device mockup (10–20% speed offset)
- Elements animate in sequentially: headline → subheadline → CTAs → device

#### Social Proof Bar
- Warm White background, directly below hero
- 4 metrics in a row: "5,000+ beta pilots" / "60fps rendering" / "iOS + Android" / "4.9★ beta rating"
- Minimal — plain text with subtle dividers, no icons needed

#### Feature Cards
- White background section
- Section headline: "Built for how you actually fly."
- 3-column grid (stacks on mobile)
- Each card: subtle border (`border-slate-200`), small teal icon (use Lucide icons), headline, 2-line description
- Hover: `translateY(-2px)` + increased shadow

**Feature cards content:**

1. **Maps** — "Vector charts at 60fps. Silky smooth pan and zoom with day/night modes and dynamic decluttering."
2. **Weather** — "Real-time radar, winds aloft, and plain-English briefings organized by flight phase."
3. **Flight Planning** — "Route optimization, weight & balance, fuel planning, and performance profiles for your aircraft."
4. **Logbook** — "Automatic flight recording with cross-device sync. Import your existing logbook in minutes."
5. **Cross-Platform** — "Full feature parity on iOS and Android. Your data syncs everywhere."
6. **Avionics Integration** — "Connect to Dynon, GRT, Garmin, and ADS-B receivers. Not just Stratus."

#### Comparison Section
- Warm White background
- Two-column layout
- Left: "The old way" — generic dark cramped UI representation
- Right: "The Tropiq way" — clean bright app screenshot
- **Do NOT use competitor names or logos**
- Keep it visual contrast, not text-heavy

#### Cross-Platform Section
- Midnight Navy background
- Headline: "Fly with the device you already own."
- Side-by-side iPad and Android phone mockups
- Brief copy about cross-platform sync
- Teal CTA

#### Weather Content Preview
- White background
- Headline: "Weather in Plain English."
- 3 blog/video preview cards: thumbnail, title, read time
- Links to /weather

#### Pricing Section
- Warm White background
- Clean card design (start with one plan for simplicity, can expand to 2–3 tiers)
- Annual/monthly toggle
- Teal CTA
- Below pricing: "No surprise tier upgrades. What you see is what you get."
- No asterisks, no hidden fees

#### Testimonials
- White background
- 2–3 pilot quotes in italic Inter
- Below each: pilot name, certificate level (e.g., "PPL-IR"), aircraft type (e.g., "Cessna 182")
- Use placeholder content for now

#### Final CTA
- Midnight Navy full-width section
- "Ready to modernize your flight bag?"
- Teal CTA button
- Optional: email signup for waitlist

#### Footer
- Deep Slate (`#1E293B`) background
- 4 columns:
  - **Product**: Features, Pricing, Download, Changelog
  - **Resources**: Weather, Blog, Docs, Status
  - **Company**: About, Careers, Press, Contact
  - **Legal**: Privacy, Terms
- Bottom bar: © Tropiq 2026 · social icons · "Built by pilots, for pilots."

---

## 8. Animation & Interaction

- **Scroll-triggered fade-up** for content sections using Framer Motion (stagger 100ms between elements)
- **Smooth parallax** on hero device mockup (10–20% speed offset)
- **Navigation**: blur backdrop + opacity transition on scroll
- **Page load**: hero elements animate in sequentially
- **Hover states**: feature cards lift 2px with shadow; buttons darken 10%; nav links get teal underline
- **No**: auto-playing video, carousels/sliders, pop-ups, chat widgets on load
- **Performance target**: Lighthouse 95+ Performance, 100 Accessibility, 100 Best Practices
- All images: lazy-loaded, `next/image` optimized, AVIF/WebP with fallbacks

---

## 9. Page Structure

| Route | Purpose |
|-------|---------|
| `/` | Homepage (see Section 7 for full layout) |
| `/features` | Deep dive on Maps, Weather, Planning, Logbook. Interactive demos where possible. |
| `/pricing` | Transparent pricing. 1–3 tiers. Feature grid. No asterisks. |
| `/switch` | Migration guide from other EFBs. "Switch in 5 minutes" demo. FAQ on data transfer. |
| `/android` | Dedicated Android landing page. Play Store badge. Device mockups. |
| `/weather` | Content hub for Weather in Plain English series. Blog/video cards. SEO-optimized. |
| `/cfi` | CFI Ambassador Program. Free subscriptions, student tracking, school licensing. |
| `/blog` | Aviation education, product updates, pilot stories. Categories: Weather, Planning, Product, Community. |
| `/about` | Team page (real aviation credentials), mission, origin story. |

**Build priority**: Homepage first, then `/features`, `/pricing`, `/about`. Other pages can be placeholder/coming-soon.

---

## 10. Assets & Placeholders

Since the app is pre-launch, use these placeholder strategies:

- **App screenshots**: Create realistic mockup compositions showing a dark-themed map UI with weather radar overlay, flight route lines, and airport markers. Use device mockup frames (iPad + phone).
- **Photography**: Use placeholder images of GA cockpits (Cessna 172, Cirrus SR22, Piper Cherokee), golden-hour flying, small airport ramps. Diverse pilots.
- **Logo**: For now, render "TROPIQ" in Inter Bold, all-caps, -0.03em tracking, in Midnight Navy (light bg) or White (dark bg). The brand mark/icon will be designed separately.
- **Icons**: Use [Lucide React](https://lucide.dev/) for feature icons. Prefer: Map, Cloud, Navigation, BookOpen, Smartphone, Radio.

---

## 11. SEO & Meta

```
Title: Tropiq — The Modern Electronic Flight Bag
Description: Beautiful maps, real-time weather, and transparent pricing for general aviation pilots. Available on iOS and Android.
OG Image: Hero section screenshot with app mockup
Keywords: EFB, electronic flight bag, flight planning app, aviation weather, ForeFlight alternative, pilot app, Android EFB
```

---

## 12. Quick Reference: Do's and Don'ts

### Do
- Use generous whitespace — let the design breathe
- Show real aviation data in screenshots (real airports, real weather)
- Use Inter everywhere except aviation data (JetBrains Mono)
- Keep copy short and declarative for headlines, warm and detailed for descriptions
- Support dark mode from the start (the app is dark-themed)
- Make the teal CTA button visible at all times in the nav

### Don't
- Name any competitor by name anywhere on the site
- Use emojis in marketing copy
- Use stock photos of airline cockpits or business jets — GA only
- Use carousels, pop-ups, or auto-playing video
- Use "revolutionary," "game-changing," "disruptive," or "affordable"
- Use more than 2 font families
- Sacrifice performance for animation — speed is a brand value
