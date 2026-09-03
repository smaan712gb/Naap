import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ease.dart';
import 'fabric.dart';
import 'learning.dart';
import 'measure/engine.dart';
import 'models/measurements.dart';
import 'models/profile.dart';
import 'silhouettes.dart';
import 'styles.dart';

/// One completed scan, kept so a person can watch their naap change over
/// time (weight journeys, growing kids, pre-wedding tailoring seasons).
class ScanRecord {
  final DateTime date;
  final Naap naap;
  const ScanRecord({required this.date, required this.naap});

  Map<String, dynamic> toJson() =>
      {'date': date.toIso8601String(), 'naap': naap.toJson()};

  factory ScanRecord.fromJson(Map<String, dynamic> j) => ScanRecord(
        date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
        naap: Naap.fromJson(j['naap'] as Map<String, dynamic>),
      );
}

/// One measured person. A phone can hold many — the household, or a
/// tailor's/associate's whole client book (Phase 2 assisted mode).
/// Everything stays on-device, per the product law.
class ClientRecord {
  final String id;
  UserProfile profile;
  Naap naap;
  KameezStyle style;
  PersonalCalibration calibration;
  final List<ScanRecord> history;

  /// Design/fabric reference photos the USER CHOSE from their gallery, to
  /// send the tailor alongside the parchi. NEVER capture photos — those
  /// are deleted by product law; the parchi PDF itself stays numbers-only.
  final List<String> referencePaths;

  ClientRecord({
    required this.id,
    UserProfile? profile,
    Naap? naap,
    KameezStyle? style,
    PersonalCalibration? calibration,
    List<ScanRecord>? history,
    List<String>? referencePaths,
  })  : profile = profile ?? UserProfile(),
        naap = naap ?? Naap.empty(),
        style = style ?? KameezStyle(),
        calibration = calibration ?? PersonalCalibration(),
        history = history ?? [],
        referencePaths = referencePaths ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'profile': profile.toJson(),
        'naap': naap.toJson(),
        'style': style.toJson(),
        'calibration': calibration.toJsonString(),
        'history': [for (final h in history) h.toJson()],
        'referencePaths': referencePaths,
      };

  factory ClientRecord.fromJson(Map<String, dynamic> j) => ClientRecord(
        id: j['id'] as String,
        profile: j['profile'] != null
            ? UserProfile.fromJson(j['profile'] as Map<String, dynamic>)
            : null,
        naap: j['naap'] != null
            ? Naap.fromJson(j['naap'] as Map<String, dynamic>)
            : null,
        style: j['style'] != null
            ? KameezStyle.fromJson(j['style'] as Map<String, dynamic>)
            : null,
        calibration: j['calibration'] != null
            ? PersonalCalibration.fromJsonString(j['calibration'] as String)
            : null,
        history: j['history'] != null
            ? [
                for (final h in j['history'] as List<dynamic>)
                  ScanRecord.fromJson(h as Map<String, dynamic>)
              ]
            : null,
        referencePaths: j['referencePaths'] != null
            ? [for (final p in j['referencePaths'] as List<dynamic>) '$p']
            : null,
      );
}

/// Single source of truth for the app. Everything lives on-device.
class AppState extends ChangeNotifier {
  static const _kClients = 'naap.clients';
  static const _kActive = 'naap.activeClient';
  static const _kShopName = 'naap.shopName';

  /// Device-level: a tailor's shop name, printed on every parchi this
  /// phone generates (the tailor-branded viral artifact).
  String shopName = '';

  final List<ClientRecord> clients = [];
  String _activeId = '';
  GarmentType garment = GarmentType.shalwarKameez;
  FitPreference fit = FitPreference.regular;
  FabricType? fabric;
  SilhouetteProfile silhouette = SilhouetteProfile.relaxedStraight;
  List<CaptureIssue> lastIssues = [];
  bool hydrated = false;

  ClientRecord get active =>
      clients.firstWhere((c) => c.id == _activeId, orElse: () => clients.first);

  // Familiar accessors — always the ACTIVE client's data, so the rest of
  // the app reads exactly as it did in single-profile days.
  UserProfile get profile => active.profile;
  Naap get naap => active.naap;
  KameezStyle get style => active.style;
  PersonalCalibration get calibration => active.calibration;

  bool get hasMeasurements => naap.values.isNotEmpty;

  Future<void> hydrate() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kClients);
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      clients.addAll([
        for (final j in list) ClientRecord.fromJson(j as Map<String, dynamic>)
      ]);
      _activeId = sp.getString(_kActive) ?? '';
    }
    if (clients.isEmpty) {
      // Migrate the single-profile era: whatever was stored becomes the
      // first client, nothing is lost.
      final legacy = ClientRecord(
        id: DateTime.now().millisecondsSinceEpoch.toRadixString(36),
        profile: await LocalStore.loadProfile(),
        naap: await LocalStore.loadNaap(),
        style: await LocalStore.loadStyle(),
        calibration: (await LocalStore.loadCalibrationRaw()) != null
            ? PersonalCalibration.fromJsonString(
                (await LocalStore.loadCalibrationRaw())!)
            : null,
      );
      clients.add(legacy);
      _activeId = legacy.id;
      await _persist();
    }
    if (!clients.any((c) => c.id == _activeId)) _activeId = clients.first.id;
    shopName = sp.getString(_kShopName) ?? '';
    hydrated = true;
    notifyListeners();
  }

  Future<void> setShopName(String name) async {
    shopName = name.trim();
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kShopName, shopName);
    notifyListeners();
  }

  Future<void> _persist() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
        _kClients, jsonEncode([for (final c in clients) c.toJson()]));
    await sp.setString(_kActive, _activeId);
  }

  // ---- client book (Phase 2 assisted mode) ----

  /// Default garment follows the active person: women land on Ladies Suit,
  /// men on Shalwar Kameez. Only a default — always changeable.
  void _defaultGarmentForActive() {
    garment = active.profile.bodyType == BodyType.female
        ? GarmentType.ladiesSuit
        : GarmentType.shalwarKameez;
  }

  Future<ClientRecord> newClient(String name) async {
    final c = ClientRecord(
        id: DateTime.now().millisecondsSinceEpoch.toRadixString(36));
    c.profile.name = name;
    clients.add(c);
    _activeId = c.id;
    _defaultGarmentForActive();
    await _persist();
    notifyListeners();
    return c;
  }

  Future<void> switchClient(String id) async {
    if (clients.any((c) => c.id == id)) {
      _activeId = id;
      _defaultGarmentForActive();
      await _persist();
      notifyListeners();
    }
  }

  Future<void> deleteClient(String id) async {
    if (clients.length <= 1) return; // always keep one
    clients.removeWhere((c) => c.id == id);
    if (_activeId == id) _activeId = clients.first.id;
    await _persist();
    notifyListeners();
  }

  // ---- active-client mutations (signatures unchanged) ----

  Future<void> saveProfile(UserProfile p) async {
    active.profile = p;
    _defaultGarmentForActive();
    await _persist();
    notifyListeners();
  }

  Future<void> setResult(EngineResult r) async {
    active.naap = r.naap;
    // v1.5 per-user learning: apply this client's remembered corrections.
    active.calibration.apply(active.naap);
    // Scan history: a deep copy per scan, newest first, capped.
    active.history.insert(
        0,
        ScanRecord(
            date: DateTime.now(),
            naap: Naap.fromJson(active.naap.toJson())));
    if (active.history.length > 12) {
      active.history.removeRange(12, active.history.length);
    }
    lastIssues = r.issues;
    await _persist();
    notifyListeners();
  }

  Future<void> editMeasurement(MeasurementKey k, double cm) async {
    final prev = naap[k];
    if (prev != null && prev.source != MeasurementSource.manual) {
      active.calibration.learn(k, aiCm: prev.cm, manualCm: cm);
    }
    naap.set(k, MeasurementValue(cm, source: MeasurementSource.manual));
    await _persist();
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

  void setSilhouette(SilhouetteProfile s) {
    silhouette = s;
    notifyListeners();
  }

  Future<void> setStyle(KameezStyle s) async {
    active.style = s;
    await _persist();
    notifyListeners();
  }

  /// Copy a user-picked gallery image into app storage as a design
  /// reference for the active client (capped at 6).
  Future<void> addReference(String pickedPath) async {
    if (active.referencePaths.length >= 6) return;
    final dir = await getApplicationDocumentsDirectory();
    final ext = pickedPath.split('.').last.toLowerCase();
    final dest = File(
        '${dir.path}/ref_${active.id}_${DateTime.now().millisecondsSinceEpoch}.$ext');
    await File(pickedPath).copy(dest.path);
    active.referencePaths.add(dest.path);
    await _persist();
    notifyListeners();
  }

  Future<void> removeReference(String path) async {
    active.referencePaths.remove(path);
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    await _persist();
    notifyListeners();
  }
}
