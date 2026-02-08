# Logbook Module
## EFB Product Specification

[← Back to Core Specification](../EFB_Product_Specification_v1.md)

---

The Logbook module provides digital flight logging that replaces the traditional paper logbook. It integrates with track recording to auto-populate flight data and provides currency tracking to help pilots maintain legal recency requirements.

## 1. Core Features

| Feature | Details | Complexity |
|---------|---------|------------|
| Flight Entry | Log flights with date, aircraft, route, duration, landings, approaches, holds, and remarks. Auto-populate from track logs. | Medium |
| Time Tracking | Track total time, PIC, SIC, dual received, dual given, solo, cross-country, night, actual instrument, simulated instrument, and simulator time. | Medium |
| Currency Tracking | Color-coded currency status for: day/night passenger carrying, IFR currency, flight review, medical certificate, and type ratings. | High |
| Certificates & Ratings | Record pilot certificates, ratings, endorsements, and medical certificates with expiration tracking. | Medium |
| Endorsements | Digital instructor endorsements (issue and receive). Remote endorsement capability. | High |
| Experience Reports | Generate reports summarizing flight time by category, aircraft type, date range, and other filters. | Medium |
| Import/Export | Bulk import from CSV/other logbook apps. Export to CSV and PDF formats. | Medium |
| Cloud Sync | All logbook data backed up and synced across devices via cloud storage. | Medium |
| Flight History | Searchable/filterable list of all flights organized by date (as seen in Flights tab: origin, destination, type, altitude, aircraft, ETA, route). | Medium |
