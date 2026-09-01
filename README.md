# Naap (ناپ) — Privacy-First Body Measurement for Tailors

Naap turns two photos into a bilingual (English/Urdu) **Digital Parchi** — a
tailor-ready measurement slip sent over WhatsApp. All computer vision runs
**on-device** (Google ML Kit); photos are analyzed on the phone and deleted.
Only numbers ever leave the device.

## How it works (v1 engine)

1. **Guided capture** — front + side photo against a ghost-silhouette overlay
   with a self-timer.
2. **On-device analysis** — ML Kit pose landmarks (33 points) + selfie
   segmentation silhouette, calibrated by the user's real height.
   - Lengths (shoulder/teera, sleeve/baazu, inseam, kameez length) come from
     landmarks.
   - Circumferences (chest/chaati, waist/kamar, hip) come from silhouette
     width (front) × depth (side) through an elliptical cross-section model
     (Ramanujan perimeter) with per-region shape factors.
   - Remaining values (neck, wrist, paincha…) fall back to anthropometric
     regressions and are flagged low-confidence for manual correction.
3. **Ease engine** — traditional Pakistani tailoring ease ("asan") per garment
   and fit preference produces the *stitching naap* next to the body naap.
4. **Digital Parchi** — a PDF with English + Urdu labels, tailor terms
   (Teera, Chaati, Kamar, Ghera, Paincha), a generic mannequin sketch, and a
   note to the tailor in Urdu. Shared via WhatsApp deep link + share sheet.

## Project layout

```
lib/
  core/
    models/        measurement vocabulary (EN/UR/tailor terms), profile, storage
    measure/       geometry helpers + the on-device CV engine
    ease.dart      garment definitions + asan (ease) tables — tailor-tunable
    parchi/        bilingual PDF generation
    app_state.dart provider-based app state (all local)
  features/
    home/ profile/ capture/ results/   the four screens
test/              engine + ease unit tests (run on the Dart VM)
```

## Building

Toolchain lives in `%USERPROFILE%\dev` (Flutter, JDK 17, Android SDK). From a
fresh shell:

```powershell
$env:JAVA_HOME="$env:USERPROFILE\dev\jdk-17.0.20.1+1"
$env:ANDROID_HOME="$env:USERPROFILE\dev\android-sdk"
$env:Path="$env:USERPROFILE\dev\flutter\bin;$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:Path"

flutter pub get
flutter test          # engine unit tests
flutter build apk     # Android APK (sideload to any Android phone)
flutter run           # with a phone connected over USB debugging
```

### iOS (no Mac needed locally)

iOS binaries must be compiled on macOS. The codebase is already
dual-platform (`ios/` is committed); use CI to build for iPhone testing:

- **Codemagic** (easiest for Flutter): connect the repo, add your Apple
  Developer account, ship to TestFlight.
- Or GitHub Actions with a `macos-latest` runner + fastlane.

Camera/photo permission strings for iOS are set in `ios/Runner/Info.plist`.

## Accuracy roadmap

| Stage | Approach | Expected error |
| --- | --- | --- |
| v1 (this) | landmarks + silhouette ellipse | ±2–4 cm circumferences, ±1–2 cm lengths |
| v1.5 | multi-frame averaging, camera-tilt correction, per-user learning from tape edits | ±2 cm |
| v2 | SMPL-X body model fitted on-device (NPU) from 4 views + video | ±1 cm, full 3D avatar |

The v2 avatar unlocks Phase 2: EU size translation, MTM suit pattern deltas,
and the B2B clienteling app.

## Privacy contract (product law)

- Photos never leave the device; deleted immediately after analysis.
- No account required. Measurements stored only in local app storage.
- The parchi carries numbers + a generic sketch — never user imagery.
