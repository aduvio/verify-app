/// No transport, hosting, upload, or customer communication is implemented.
abstract class DeliveryService {
  Future<void> simulate({
    required String inspectionId,
    required int revision,
    required String channel,
    required String recipient,
  });
}

class MockDeliveryService implements DeliveryService {
  final bool fail;
  const MockDeliveryService({this.fail = false});
  @override
  Future<void> simulate({
    required String inspectionId,
    required int revision,
    required String channel,
    required String recipient,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (fail) throw StateError('Simulated delivery failure');
  }
}
