import 'dart:async';

import 'package:secure_payment_portal/core/error/result.dart';
import 'package:secure_payment_portal/features/security/security.dart';

/// A controller whose answer the test gives by hand, to hold a request for
/// protection "in flight" for as long as it needs.
class GatedSecureWindowController implements SecureWindowController {
  final Completer<Result<void>> answer = Completer<Result<void>>();
  int enables = 0;
  int disables = 0;

  @override
  Future<Result<void>> enable() {
    enables++;
    return answer.future;
  }

  @override
  Future<Result<void>> disable() async {
    disables++;
    return Success.unit;
  }
}
