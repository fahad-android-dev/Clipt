import '../../domain/models/export_limits.dart';

abstract class EntitlementRepository {
  Future<ExportLimits> exportLimits();
}

/// Stub implementation that returns free limits unless debugPro is true.
/// Will be replaced with RevenueCat in a later step.
class StubEntitlementRepository implements EntitlementRepository {
  bool debugPro = false;

  @override
  Future<ExportLimits> exportLimits() async {
    return debugPro ? ExportLimits.pro : ExportLimits.free;
  }
}
