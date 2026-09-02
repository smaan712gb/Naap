import 'package:flutter/foundation.dart';

import 'ease.dart';
import 'fabric.dart';
import 'learning.dart';
import 'measure/engine.dart';
import 'models/measurements.dart';
import 'models/profile.dart';
import 'styles.dart';

/// Single source of truth for the app. Everything lives on-device.
class AppState extends ChangeNotifier {
  UserProfile profile = UserProfile();
  Naap naap = Naap.empty();
  GarmentType garment = GarmentType.shalwarKameez;
  FitPreference fit = FitPreference.regular;
  FabricType? fabric;
  KameezStyle style = KameezStyle();
  PersonalCalibration calibration = PersonalCalibration();
  List<CaptureIssue> lastIssues = [];
  bool hydrated = false;

  Future<void> hydrate() async {
    final p = await LocalStore.loadProfile();
    if (p != null) profile = p;
    final n = await LocalStore.loadNaap();
    if (n != null) naap = n;
    final st = await LocalStore.loadStyle();
    if (st != null) style = st;
    final cal = await LocalStore.loadCalibrationRaw();
    if (cal != null) calibration = PersonalCalibration.fromJsonString(cal);
    hydrated = true;
    notifyListeners();
  }

  bool get hasMeasurements => naap.values.isNotEmpty;

  Future<void> saveProfile(UserProfile p) async {
    profile = p;
    await LocalStore.saveProfile(p);
    notifyListeners();
  }

  Future<void> setResult(EngineResult r) async {
    naap = r.naap;
    // v1.5 per-user learning: apply remembered tape corrections to the
    // fresh AI values (manual edits are never touched).
    calibration.apply(naap);
    lastIssues = r.issues;
    await LocalStore.saveNaap(naap);
    notifyListeners();
  }

  Future<void> editMeasurement(MeasurementKey k, double cm) async {
    // Learn from the correction when it replaces an AI value.
    final prev = naap[k];
    if (prev != null && prev.source != MeasurementSource.manual) {
      calibration.learn(k, aiCm: prev.cm, manualCm: cm);
      await LocalStore.saveCalibrationRaw(calibration.toJsonString());
    }
    naap.set(k, MeasurementValue(cm, source: MeasurementSource.manual));
    await LocalStore.saveNaap(naap);
    notifyListeners();
  }

  void setGarment(GarmentType g) {
    garment = g;
    notifyListeners();
  }

  void setFit(FitPreference f) {
    fit = f;
    notifyListeners();
  }

  void setFabric(FabricType? f) {
    fabric = f;
    notifyListeners();
  }

  Future<void> setStyle(KameezStyle s) async {
    style = s;
    await LocalStore.saveStyle(s);
    notifyListeners();
  }
}
