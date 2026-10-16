/// Lets a demo or a test take the simulated bill backend offline, to see how the
/// screen copes with a bill that cannot be loaded.
abstract interface class BillBackendControl {
  bool get online;

  void setOnline({required bool online});
}
