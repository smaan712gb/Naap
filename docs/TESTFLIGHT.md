# Getting Naap onto tester phones

Two audiences, two paths:

| Testers | Device | Path |
|---|---|---|
| Household (US) | iPhone | TestFlight via Codemagic |
| Family + tailors (Pakistan) | Android | Direct APK over WhatsApp |

## Android (works today, no accounts needed)

`flutter build apk --release` produces
`build/app/outputs/flutter-apk/app-release.apk` (~60 MB). Send it over
WhatsApp/Drive; the phone will ask to allow "install unknown apps" — that is
expected for sideloading. Debug-signed release keys are fine for testing;
a Play-Store upload key comes later.

## iOS TestFlight (one-time setup, ~20 minutes)

The Apple side is already done: the **Tern** project's Apple Developer
enrollment is active (external Beta App Review passed once already) and its
team-wide App Store Connect API key lives at
`~\.appstoreconnect\private_keys\AuthKey_6LXF7UJC2L.p8`
(issuer `1cf6af64-6d6c-4008-9dcc-81b66de04c65`) — ASC API keys and the
membership cover every app on the team, so Naap rides the same account.
The build pipeline is committed as [codemagic.yaml](../codemagic.yaml).
Remaining steps:

1. **Register the bundle ID** (from `C:\Projects\Tern`, which has pyjwt):

   ```bash
   export ASC_KEY_ID=6LXF7UJC2L ASC_ISSUER_ID=1cf6af64-6d6c-4008-9dcc-81b66de04c65
   python scripts/asc_api.py POST /v1/bundleIds \
     '{"data":{"type":"bundleIds","attributes":{"identifier":"com.naap.naap","name":"Naap","platform":"IOS"}}}'
   ```

   (Or the web UI: developer.apple.com → Identifiers → "+".)
2. **Create the app record** — the ASC API cannot create apps, so this one
   is clicking: <https://appstoreconnect.apple.com> → Apps → "+" → New App →
   iOS, bundle ID **com.naap.naap**, name "Naap", English (U.S.),
   SKU `naap-001`.
3. **Codemagic** — <https://codemagic.io> → sign in with GitHub → add the
   `smaan712gb/Naap` repo → Teams → Integrations → Developer Portal → add
   the **existing** `.p8` from the path above (Key ID `6LXF7UJC2L`, issuer
   as above), named **naap-asc** (the name `codemagic.yaml` expects).
   Codemagic's cloud signing creates the Naap distribution profile itself.
4. **TestFlight testers** — App Store Connect → Naap → TestFlight →
   Internal Testing → "+" group named **Family** → add household Apple IDs.
   Internal groups get builds instantly, no Apple review.
5. `git push` (or "Start new build" in Codemagic). The `ios-testflight`
   workflow tests, builds a signed ipa, and uploads to the Family group.
   Testers get a TestFlight push notification.

Codemagic free tier includes 500 macOS build minutes/month; a build is
~15 min, so ~30 free iOS builds a month.

**Why not Tern's EC2 Mac pipeline?** Tern builds on a self-provisioned EC2
Mac because its Rust/ggml engines need custom cross-compilation. Naap is
plain Flutter — Codemagic handles it with zero Mac-host cost (an EC2 Mac
dedicated host has a 24 h minimum, ~$16+/session). If Codemagic ever
becomes a limit, `C:\Projects\Tern\apps\ios\provision_mac.sh` +
`build_client_testflight.sh` are the template for a Naap variant (add
Flutter to the Mac provisioning; note App Store Connect rejects uploads
built with SDKs older than iOS 26 as of 2026).

## What testers should exercise (both phases)

- **Phase 1:** profile → guided capture (front + side) → review measurements
  → edit anything that looks off → generate parchi PDF → WhatsApp it.
- **Phase 2 preview:** Shop tab → browse the fabric catalog (live backend) →
  su misura EU size card on the results screen → tri-modal checkout flow
  (stops before payment until Stripe is configured).
- **Calibration:** after each capture, record tape measurements per
  [CALIBRATION.md](CALIBRATION.md) so the engine constants can be tuned.
