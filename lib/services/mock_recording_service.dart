abstract class RecordingService {
  Future<void> startSegment(String attemptId);
  Future<void> stopSegment(String attemptId);
  Future<void> prepareRetake(String attemptId);
  void cancel(String attemptId);
}

/// Delays only. No media or storage; cancel has no external work to stop.
class MockRecordingService implements RecordingService {
  @override
  Future<void> startSegment(String attemptId) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<void> stopSegment(String attemptId) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<void> prepareRetake(String attemptId) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  void cancel(String attemptId) {}
}
