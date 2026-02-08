# Weight & Balance Module
## EFB Product Specification

[← Back to Core Specification](../EFB_Product_Specification_v1.md)

---

The Weight & Balance module ensures aircraft are loaded within approved limits before each flight. It uses aircraft type certificate data and allows pilots to quickly evaluate the effects of passenger and cargo loading.

## 1. Core Features

| Feature | Details | Complexity |
|---------|---------|------------|
| Pre-loaded Aircraft | 100+ common GA aircraft models with type certificate W&B envelopes pre-loaded. | High |
| Custom Profiles | Create and customize unlimited W&B profiles for specific aircraft. Adjust empty weight, CG, and station definitions. | Medium |
| Loading Interface | Interactive interview-style wizard for entering pilot, passenger, baggage, and fuel weights at each station. | Medium |
| Envelope Visualization | Graphical CG envelope chart showing takeoff and landing weight/CG plotted against approved limits. | High |
| Limit Alerts | Visual and audio alerts when weight or CG falls outside approved envelope. | Low |
| Fuel Planning | Calculate fuel load requirements based on flight distance, reserves, and alternate requirements. Show effect on W&B. | Medium |
| Takeoff & Landing | Takeoff and landing performance calculations based on weight, density altitude, runway length, and wind. | Very High |
| Scenario Comparison | Save and compare multiple loading scenarios for the same flight. | Medium |
