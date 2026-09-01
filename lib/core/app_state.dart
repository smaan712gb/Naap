import 'package:flutter/foundation.dart';

import 'ease.dart';
import 'measure/engine.dart';
import 'models/measurements.dart';
import 'models/profile.dart';

/// Single source of truth for the app. Everything lives on-device.
class AppState extends ChangeNotifier {
  UserProfile profile = UserProfile();
  Naap naap = Naap.empty();
  GarmentType garment = GarmentType.shalwarKameez;
  FitPreference fit = FitPreference.regular;
  List<CaptureIssue> lastIssues = [];
  bool hydrated = false;

  Future<void> hydrate() async {
    final p = await LocalStore.loadProfile();
    if (p != null) profile = p;
    final n = await LocalStore.loadNaap();
    if (n != null) naap = n;
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
    lastIssues = r.issues;
    await LocalStore.saveNaap(naap);
    notifyListeners();
  }

  Future<void> editMeasurement(MeasurementKey k, double cm) async {
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
}
