# LoveLet 💜

> **Your person. One tap away.**
>
> A minimal, widget-first iOS app that puts your partner's latest moment right on your home screen.  
> Not a feed. Not a social network. Just u two.

[![Platform](https://img.shields.io/badge/platform-iOS%2016%2B-blue?style=flat-square)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/swift-5.9-orange?style=flat-square)](https://swift.org/)
[![Backend](https://img.shields.io/badge/backend-Supabase-3ECF8E?style=flat-square)](https://supabase.com/)
[![Status](https://img.shields.io/badge/status-pre--launch%20MVP-yellow?style=flat-square)]()

---

## What is LoveLet?

LoveLet is an intimate, widget-first iOS app for couples who want to stay close without the noise of social media. One partner snaps a selfie and writes a short message — the other sees it instantly on their iOS home screen widget.

That's it. That's the whole thing. No feed. No algorithm. No ads. Just u two.

---

## Core Features

| Feature | Description |
|---|---|
| **Widget-first** | Partner's latest moment lives on your iOS home screen — no app-open required |
| **1:1 Pairing** | Strictly two people per pair via invite code — no groups, no noise |
| **Instant moments** | Selfie + caption surfaced to your partner in seconds |
| **Offline resilience** | Latest moment is cached locally so the widget works in poor connectivity |
| **No ads. No algorithm.** | Your moments are yours — we don't monetise your attention |
| **Auto image compression** | Adaptive JPEG quality for fast uploads without sacrificing quality |
| **Signed storage URLs** | Moment URLs expire in 24 hours for security |
| **Anonymous auth** | Zero-friction device-based auth — no email, no OTP, no account creation |

---

## Tech Stack

### iOS App
- **Language:** Swift 5.9
- **UI:** SwiftUI
- **Widget:** WidgetKit (home screen + lock screen)
- **State management:** MVVM with `@Published` / `@StateObject` / `@EnvironmentObject`
- **Data sharing:** App Groups (`group.com.example.couples`) for app ↔ widget communication

### Backend
- **Platform:** [Supabase](https://supabase.com)
  - **Auth:** Anonymous auth — zero-friction, device-bound identity
  - **Database:** PostgreSQL with custom RPC functions for pairing and moment retrieval
  - **Storage:** Private `moments/` bucket with signed download URLs (24h TTL)
  - **RLS:** Row-level security policies ensure pairs can only access their own data
- **Client:** `supabase-swift`

---

## Project Structure

```
idea/
├── ios/
│   ├── CouplesMVP/                       # Main app target
│   │   ├── Views/
│   │   │   ├── HomeView.swift            # Main screen — shows partner's latest moment
│   │   │   ├── PairingView.swift         # Generate or enter partner invite code
│   │   │   ├── LoginView.swift           # Anonymous auth bootstrapping
│   │   │   ├── CaptureMomentView.swift   # Selfie capture + caption entry
│   │   │   └── WidgetOnboardingView.swift# Step-by-step widget setup tutorial (4 steps)
│   │   ├── ViewModels/
│   │   │   └── HomeViewModel.swift       # MVVM layer for home screen state + actions
│   │   ├── Services/
│   │   │   └── SupabaseService.swift     # Singleton — all Supabase interactions
│   │   └── CouplesMVPApp.swift           # App entry point + root navigation state machine
│   │
│   └── PartnerMomentWidget/              # WidgetKit extension
│       ├── PartnerMomentWidget.swift     # Entry point + timeline provider
│       ├── PartnerMomentWidgetEntryView.swift  # Widget UI (all sizes)
│       └── SharedMomentData.swift        # App Group shared data model
│
└── supabase/
    └── schema.sql                        # DB schema, RPC functions, RLS policies
```

---

## User Flows

### First-Time Setup
```
Launch → Anonymous Auth → Widget Onboarding (4 steps) → Pair with Partner → Home
```

### Core Usage Loop
```
View partner's latest moment
        ↓
Tap "Share a Moment"
        ↓
Snap selfie + write caption
        ↓
Send → partner sees it on their home screen widget → repeat
```

### Pairing
```
Person A: tap "Create pair" → share invite code
Person B: tap "Join pair" → enter invite code
Both: paired ✓ — start sharing moments
```

---

## Minimal API / Data Flow

```
Anonymous Auth (device-bound)
    ↓
create_pair()          → returns invite code (Person A)
join_pair(code)        → links two users (Person B)
    ↓
upload_moment(img, msg) → writes to Supabase Storage + DB
fetch_latest_moment()   → returns partner's single latest moment
    ↓
App writes to App Group cache
Widget reads cache + refreshes timeline every ~15 min
```

---

## Widget

The **Partner Moment** widget supports all standard iOS sizes and displays your partner's latest photo + caption directly on your home screen or lock screen.

- **Refresh cadence:** ~15 minutes (balanced for battery vs. freshness)
- **Offline:** Renders cached moment if network is unavailable
- **Setup:** Long-press home screen → **"+"** → search **LoveLet** → pick size → add

---

## Reliability Notes

- Images compressed before upload (adaptive JPEG, target < 1 MB)
- Upload retries once on transient failure
- Widget uses local App Group cache for resilience against connectivity issues
- Signed storage URLs fetched fresh on each moment load

---

## Setup & Development

### Prerequisites
- Xcode 15+
- iOS 16+ deployment target
- A [Supabase](https://supabase.com) project with anonymous auth enabled
- `xcodegen` (for project generation from `project.yml`)

### Steps

**1. Clone the repo**
```bash
git clone https://github.com/rish106-hub/idea.git lovelet-ios
cd lovelet-ios
```

**2. Verify prerequisites**
```bash
./scripts/check-prereqs.sh
```

**3. Configure secrets**

Fill `ios/Config/Secrets.xcconfig`:
```
SUPABASE_URL = https://your-project.supabase.co
SUPABASE_ANON_KEY = your-anon-key-here
```

**4. Apply the Supabase schema**
```bash
export SUPABASE_DB_URL='postgresql://...'
./scripts/apply-supabase-schema.sh
```

This creates tables, RPC functions, RLS policies, and the private `moments` storage bucket.

**5. Generate & open the Xcode project**
```bash
./scripts/setup.sh
open ios/CouplesMVP.xcodeproj
```

**6. Configure signing**

In Xcode → Signing & Capabilities for **both** the app and widget targets:
- Set your development Team
- Enable App Group: `group.com.example.couples`

**7. Build & run**

Connect a real iPhone (WidgetKit does not work fully in Simulator for widget timeline testing).

---

## Platform Support

| Platform | Status |
|---|---|
| iOS 16+ | ✅ Supported |
| iPadOS | 🔜 Planned |
| macOS | ❌ Not planned |
| Android | ❌ Not planned (for now) |

---

## Status

Pre-launch MVP — core features built and functional. Currently in private beta.

🌐 Join the waitlist → [lovelet.app](https://lovelet.app) *(site coming soon)*

---

## License

Private and proprietary. All rights reserved © 2025 LoveLet.
