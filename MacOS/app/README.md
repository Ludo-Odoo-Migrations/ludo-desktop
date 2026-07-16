# LUDO Desktop — macOS click-dummy scaffold

A navigable SwiftUI skeleton of the macOS app (5 screens, mock data, working
click-through). It is a **click-dummy** for hand-off — the real backend wiring
(`LiveAPIClient`, the live auth exchange) is stubbed and clearly marked `TODO`.

PRD: `../prd_macos.md` · Prototypes: `../prototypes/` · Epic: Ludo-Odoo-Migrations/ludo-webapps#94

## Run it

Requires **Xcode 15+** (full Xcode, not just Command Line Tools).

```sh
brew install xcodegen           # one-time
cd ludo-desktop/MacOS/app
xcodegen generate               # writes LudoDesktop.xcodeproj from project.yml
open LudoDesktop.xcodeproj       # then press ⌘R
```

The `.xcodeproj` is generated, not committed — edit `project.yml` and re-run
`xcodegen generate`.

## What works (mock)

- **Sign in** — "Sign in with GitHub" → instant mock session (default).
- **Discovery** → **Scope picker** → **Review** → **Monitor** click-through.
- Scope picker: tri-state module/model/"All" checkboxes, per-model custom-field
  toggles, live dependency + port-blocker inspector, live summary footer.
- Monitor: progress ring + per-model bars + live event log (timer-driven replay).

## Login modes

`AuthService(mode:)` — see `Sources/LudoDesktop/Services/AuthService.swift`:

- `.mock` (default) — instant fake session, no browser. For click-through.
- `.live` — real browser redirect: `ASWebAuthenticationSession` opens the system
  browser, OAuth returns to `ludo-desktop://auth/callback` (PKCE). Needs the BFF
  desktop-auth endpoint (tracked under #94). Toggle on the Sign-in screen.

## Swapping in the real backend

`Sources/LudoDesktop/Services/APIClient.swift` defines the `APIClient` protocol with
a `MockAPIClient` (active) and a `LiveAPIClient` stub. Point the environment at
`LiveAPIClient` and implement the calls against the Contract A endpoints in #94.
