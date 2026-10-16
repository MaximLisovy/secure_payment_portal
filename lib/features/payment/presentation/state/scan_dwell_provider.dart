import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long one revolution of the security scan lasts. The flow keeps the
/// device check on screen until a revolution ends: a verdict that arrives early
/// waits for the end of the current one, so the user always sees the sweep go
/// all the way round. Zero (the default) shows the verdict as soon as it is
/// known. The app overrides it from the active brand's scan period.
final scanDwellProvider = Provider<Duration>((ref) => Duration.zero);
