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

## iOS TestFlight (one-time setup, ~1 hour of clicking)

Everything below is account work only you can do — the build pipeline itself
is already committed as [codemagic.yaml](../codemagic.yaml).

1. **Apple Developer Program** — enroll at
   https://developer.apple.com/programs/enroll/ ($99/yr). Use the same Apple
   ID you'll manage the app with.
2. **App Store Connect** — https://appstoreconnect.apple.com →
   Apps → "+" → New App:
   - Platform iOS, bundle ID **com.naap.naap** (register the bundle ID first
     at developer.apple.com → Identifiers if it's not offered).
   - Name "Naap", primary language English, SKU `naap-001`.
3. **App Store Connect API key** — App Store Connect → Users and Access →
   Integrations → App Store Connect API → "+".
   Role **App Manager**. Download the `.p8` once; note the Key ID and
   Issuer ID.
4. **Codemagic** — https://codemagic.io → sign up with GitHub → add the
   `smaan712gb/Naap` repo. Then Teams → Personal Account → Integrations →
   Developer Portal → add the API key from step 3 and name it **naap-asc**
   (the name `codemagic.yaml` expects).
5. **TestFlight testers** — App Store Connect → your app → TestFlight →
   Internal Testing → "+" group named **Family** → add household Apple IDs.
   Internal groups get builds instantly, no Apple review.
6. Push to `main` (or hit "Start new build" in Codemagic). The
   `ios-testflight` workflow tests, builds a signed ipa, and uploads to the
   Family group. Testers get a TestFlight push notification.

Codemagic free tier includes 500 macOS build minutes/month; a build is
~15 min, so ~30 free iOS builds a month.

## What testers should exercise (both phases)

- **Phase 1:** profile → guided capture (front + side) → review measurements
  → edit anything that looks off → generate parchi PDF → WhatsApp it.
- **Phase 2 preview:** Shop tab → browse the fabric catalog (live backend) →
  su misura EU size card on the results screen → tri-modal checkout flow
  (stops before payment until Stripe is configured).
- **Calibration:** after each capture, record tape measurements per
  [CALIBRATION.md](CALIBRATION.md) so the engine constants can be tuned.
