import 'package:flutter/painting.dart';

// Non-nullable interpolation helpers for ThemeExtension tokens. The framework
// lerps (Color.lerp, lerpDouble, ...) return nullable types because they accept
// null inputs; tokens never hold null, so these wrappers keep call sites free
// of `!`. The formula `a * (1 - t) + b * t` is exact at t == 0 and t == 1.

double lerpValue(double a, double b, double t) => a * (1 - t) + b * t;

Duration lerpDuration(Duration a, Duration b, double t) => Duration(
  microseconds: lerpValue(
    a.inMicroseconds.toDouble(),
    b.inMicroseconds.toDouble(),
    t,
  ).round(),
);

// Color.lerp and LinearGradient.lerp return null only when both inputs are null.
Color lerpColor(Color a, Color b, double t) => Color.lerp(a, b, t) ?? b;

// LinearGradient.lerp returns an equivalent gradient with explicit stops even at
// t == 0 / 1, which breaks value equality, so the endpoints are returned as is.
LinearGradient lerpGradient(LinearGradient a, LinearGradient b, double t) {
  if (t == 0) return a;
  if (t == 1) return b;
  return LinearGradient.lerp(a, b, t) ?? b;
}

/// For members that cannot be interpolated (curves, page transitions):
/// keeps [a] for the first half of the animation and switches to [b] at t >= 0.5.
T lerpStep<T>(T a, T b, double t) => t < 0.5 ? a : b;
