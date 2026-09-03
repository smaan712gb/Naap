import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../styles.dart';
import 'measurements.dart';

enum BodyType { male, female }

enum PreferredUnit { cm, inches }

/// The person being measured. Height is the calibration anchor for the whole
/// computer-vision pipeline, so it is required before capture.
class UserProfile {
  String name;
  double heightCm;
  double? weightKg;
  BodyType bodyType;
  PreferredUnit unit;

  /// Tailor's WhatsApp number in international format, e.g. +923001234567.
  String? tailorWhatsApp;

  /// When a TAILOR runs Naap for their customers (client book), their shop
  /// name goes on every parchi they generate — the parchi becomes their
  /// branded artifact, carrying Naap with it. App-level, set once.
  String? shopName;

  UserProfile({
    this.name = '',
    this.heightCm = 170,
    this.weightKg,
    this.bodyType = BodyType.male,
    this.unit = PreferredUnit.inches,
    this.tailorWhatsApp,
    this.shopName,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'bodyType': bodyType.name,
        'unit': unit.name,
        'tailorWhatsApp': tailorWhatsApp,
        'shopName': shopName,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        name: j['name'] as String? ?? '',
        heightCm: (j['heightCm'] as num?)?.toDouble() ?? 170,
        weightKg: (j['weightKg'] as num?)?.toDouble(),
        bodyType: BodyType.values
            .firstWhere((b) => b.name == j['bodyType'], orElse: () => BodyType.male),
        unit: PreferredUnit.values
            .firstWhere((u) => u.name == j['unit'], orElse: () => PreferredUnit.inches),
        tailorWhatsApp: j['tailorWhatsApp'] as String?,
        shopName: j['shopName'] as String?,
      );
}

/// Local-only persistence. Nothing here ever leaves the device — that is the
/// core product promise.
class LocalStore {
  static const _kProfile = 'naap.profile';
  static const _kNaap = 'naap.measurements';

  static Future<UserProfile?> loadProfile() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kProfile);
    if (raw == null) return null;
    return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<void> saveProfile(UserProfile p) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kProfile, jsonEncode(p.toJson()));
  }

  static Future<Naap?> loadNaap() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kNaap);
    if (raw == null) return null;
    return Naap.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<void> saveNaap(Naap n) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kNaap, jsonEncode(n.toJson()));
  }

  static const _kStyle = 'naap.style';
  static const _kCalibration = 'naap.personalCalibration';

  static Future<String?> loadCalibrationRaw() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kCalibration);
  }

  static Future<void> saveCalibrationRaw(String raw) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kCalibration, raw);
  }

  static Future<KameezStyle?> loadStyle() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kStyle);
    if (raw == null) return null;
    return KameezStyle.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<void> saveStyle(KameezStyle s) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kStyle, jsonEncode(s.toJson()));
  }
}
