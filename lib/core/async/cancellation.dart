/// Read-only cancellation of a command that has not yet been accepted.
abstract interface class CancellationSignal {
  bool get isCancelled;
}

/// Owned by the caller; cancellation is permanent and does not stop accepted work.
final class CancellationSource implements CancellationSignal {
  bool _isCancelled = false;

  @override
  bool get isCancelled => _isCancelled;

  void cancel() => _isCancelled = true;
}
