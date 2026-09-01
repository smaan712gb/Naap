/// Pure geometry helpers for the measurement engine. Kept free of Flutter/ML
/// imports so they are unit-testable on the Dart VM.
library;

import 'dart:math' as math;

/// Ramanujan's approximation for the perimeter of an ellipse with semi-axes
/// [a] and [b]. Accurate to well under 0.1% for human torso aspect ratios.
double ramanujan(double a, double b) {
  return math.pi * (3 * (a + b) - math.sqrt((3 * a + b) * (a + 3 * b)));
}

double dist(double x1, double y1, double x2, double y2) =>
    math.sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2));

/// A horizontal slice of a binary silhouette mask: the contiguous foreground
/// run that contains [anchorX] on row [y].
class RowRun {
  final int left;
  final int right;
  const RowRun(this.left, this.right);
  int get widthPx => right - left + 1;
}

/// Scans row [y] of a mask for the contiguous run of foreground pixels
/// containing [anchorX]. Foreground is `confidence >= threshold`.
///
/// [mask] is row-major with dimensions [w] x [h]. Returns null if the anchor
/// pixel itself is background (e.g. landmark fell outside the silhouette).
RowRun? runAtRow(List<double> mask, int w, int h, int y, int anchorX,
    {double threshold = 0.8}) {
  if (y < 0 || y >= h) return null;
  int ax = anchorX.clamp(0, w - 1);
  final row = y * w;
  if (mask[row + ax] < threshold) {
    // Nudge the anchor up to 6px sideways — landmarks sit on joints and can
    // land a hair outside the mask near edges.
    var found = false;
    for (var d = 1; d <= 6 && !found; d++) {
      if (ax - d >= 0 && mask[row + ax - d] >= threshold) {
        ax -= d;
        found = true;
      } else if (ax + d < w && mask[row + ax + d] >= threshold) {
        ax += d;
        found = true;
      }
    }
    if (!found) return null;
  }
  var l = ax;
  while (l > 0 && mask[row + l - 1] >= threshold) {
    l--;
  }
  var r = ax;
  while (r < w - 1 && mask[row + r + 1] >= threshold) {
    r++;
  }
  return RowRun(l, r);
}
