import 'dart:ui';

Color alpha(Color c, double a) => c.withAlpha((a.clamp(0.0, 1.0) * 255).round());
