import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/core/logging/logger.dart';

/// The app's logger. A test overrides it with one that records what is said.
final loggerProvider = Provider<Logger>((ref) => const DeveloperLogger());
