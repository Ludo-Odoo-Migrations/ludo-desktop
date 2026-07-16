# LUDO Desktop — Windows · Product Requirements

Status: placeholder · Target: after macOS · Related: `../MacOS/prd_macos.md` · epic Ludo-Odoo-Migrations/ludo-webapps#94

The Windows app is **functional parity** with the macOS app — same flow, same screens
(sign-in → discovery → scope picker → review & launch → monitor), same backend contract.
**macOS ships first**; this is scoped once that lands.

## Parity rules
- Thin client of the **ludo-apps BFF** (Contract A, REST + SSE). No MinIO / agent / broker access.
- `account_id` only — no customer PII on the device.
- Same scope-selection behaviour: default = everything (opt-out); module → model + custom-fields-only;
  dependencies resolved server-side via `/resolve-scope`.
- Reuse the **Contract A OpenAPI** + typed DTOs (no second API surface).

## Open (decide at Windows kickoff)
- **Stack:** WinUI 3 / .NET (native, recommended for Windows-native feel) vs .NET MAUI vs a shared
  cross-platform core. See `../MacOS/prd_macos.md` §14.
- **Distribution:** MSIX + Microsoft Store vs signed installer + auto-update.
- **Auth:** GitHub OAuth via the system web-auth broker (WebAuthenticationBroker / ASWebAuthenticationSession-equivalent).

Until kickoff, treat `../MacOS/prd_macos.md` as the authoritative behaviour spec; this file records
only Windows-specific deltas.
