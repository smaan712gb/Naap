/// Shoulder slope & posture profiling — v1 deterministic estimates from
/// 2D landmarks. A bespoke cutter reads these as ADVISORY figuration
/// notes (pad thickness, front/back balance direction), not as spec: the
/// precise version arrives with the v2 mesh. Pure functions, unit-tested.
library;

import 'dart:math' as math;

class PostureProfile {
  /// Downward angle of each shoulder from the neck point, degrees.
  final double leftSlopeDeg;
  final double rightSlopeDeg;

  /// square | regular | sloping (average of both sides).
  final String slopeClass;

  /// How far the ear sits forward of the shoulder line in the side view, cm.
  final double headForwardCm;

  /// erect | forward-leaning | reclined (shoulder vs hip, side view).
  final String balanceClass;

  const PostureProfile({
    required this.leftSlopeDeg,
    required this.rightSlopeDeg,
    required this.slopeClass,
    required this.headForwardCm,
    required this.balanceClass,
  });

  Map<String, dynamic> toJson() => {
        'leftSlopeDeg': leftSlopeDeg,
        'rightSlopeDeg': rightSlopeDeg,
        'slopeClass': slopeClass,
        'headForwardCm': headForwardCm,
        'balanceClass': balanceClass,
      };

  factory PostureProfile.fromJson(Map<String, dynamic> j) => PostureProfile(
        leftSlopeDeg: (j['leftSlopeDeg'] as num?)?.toDouble() ?? 0,
        rightSlopeDeg: (j['rightSlopeDeg'] as num?)?.toDouble() ?? 0,
        slopeClass: j['slopeClass'] as String? ?? 'regular',
        headForwardCm: (j['headForwardCm'] as num?)?.toDouble() ?? 0,
        balanceClass: j['balanceClass'] as String? ?? 'erect',
      );

  String get tailorSummary =>
      'Shoulders: $slopeClass (${leftSlopeDeg.toStringAsFixed(0)}°L/'
      '${rightSlopeDeg.toStringAsFixed(0)}°R)'
      '${(leftSlopeDeg - rightSlopeDeg).abs() >= 4 ? ', uneven' : ''} · '
      'Head: ${headForwardCm >= 5 ? 'forward ${headForwardCm.toStringAsFixed(0)} cm' : 'neutral'} · '
      'Stance: $balanceClass';
}

/// Slope of one shoulder: angle below horizontal of the line from the
/// neck point to the shoulder landmark. Tailoring bands: <15° square,
/// 15–23° regular, >23° sloping.
double shoulderSlopeDeg({
  required double neckX,
  required double neckY,
  required double shoulderX,
  required double shoulderY,
}) {
  final dx = (shoulderX - neckX).abs();
  final dy = shoulderY - neckY; // +y is down in image space
  if (dx <= 0) return 0;
  return math.atan2(dy, dx) * 180 / math.pi;
}

String classifySlope(double avgSlopeDeg) {
  if (avgSlopeDeg < 15) return 'square';
  if (avgSlopeDeg <= 23) return 'regular';
  return 'sloping';
}

/// Side-view balance from horizontal offsets (cm, magnitudes): a shoulder
/// sitting well forward of the hip reads as forward-leaning; well behind,
/// reclined.
String classifyBalance(double shoulderVsHipCm) {
  if (shoulderVsHipCm > 4) return 'forward-leaning';
  if (shoulderVsHipCm < -4) return 'reclined';
  return 'erect';
}
