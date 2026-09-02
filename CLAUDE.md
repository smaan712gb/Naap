
# NAAP — Claude Code guide

Flutter app (Android + iOS): privacy-first body measurement → bilingual EN/Urdu
PDF parchi → WhatsApp to tailor. See README.md for architecture.

## Build environment (Windows)

Toolchain is NOT on PATH. Prefix every shell:

```powershell
$env:JAVA_HOME="$env:USERPROFILE\dev\jdk-17.0.20.1+1"
$env:ANDROID_HOME="$env:USERPROFILE\dev\android-sdk"
$env:Path="$env:USERPROFILE\dev\flutter\bin;$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:Path"
```

- `flutter test` — engine/ease unit tests (fast, Dart VM only).
- `flutter analyze` — must stay at zero issues.
- `flutter build apk --release` — Android artifact.
- iOS builds only in CI (`.github/workflows/ios-build.yml`); this machine is Windows.

## Product laws (do not violate)

1. Capture photos are analyzed on-device and deleted (`shredCaptures`). Never
   add code that uploads, persists, or logs user photos.
2. The parchi contains numbers + generic sketch only — never user imagery.
3. Every AI measurement stays user-editable; manual edits win (source=manual).
4. **No cloud vision API ever receives user body photos** — measurement CV is
   on-device only. All agent prose runs on DeepSeek (founder cost decision
   2026-09-02) with a hard rule: **no customer identity ever enters an LLM
   prompt** — names/contacts/addresses stay out; measurements without
   identity are OK. Claude is a per-deployment opt-in
   (NAAP_PREFER_CLAUDE=1). See docs/BLUEPRINT.md §AI architecture.
5. **No LLM in the numeric path** — ease, stretch, and size math stays
   deterministic, testable Dart (tables in `lib/core/ease.dart`).

## Device testing (no local Android phone)

- `python scripts\devicefarm_smoke.py` — one rented AWS Device Farm phone
  (~$1/run, shared `tern` project, us-west-2). Needs
  `flutter build apk --debug --target-platform android-arm64` and
  `android\gradlew.bat app:assembleDebugAndroidTest` first.
- Keep runs single-device unless the user approves the cost of more.
- iOS: CI only (`.github/workflows/ios-build.yml`); TestFlight via Codemagic
  is the tester-distribution plan.

## Conventions

- Measurement values are stored in **cm** internally; convert at the UI/PDF edge.
- Tailoring domain tables (ease/asan, garment definitions) live in
  `lib/core/ease.dart` — keep them declarative so a master tailor can review.
- Urdu strings live beside English in the measurement/garment defs; the PDF
  uses NotoNaskhArabic with `pw.Directionality(rtl)`.
- Engine tuning constants (row positions, shape factors) are at the top of
  `lib/core/measure/engine.dart` — calibrate against tape measurements, don't
  scatter magic numbers.
