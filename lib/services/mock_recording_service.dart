class MockRecordingService {
  Future<void> startSegment(String stepId) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> stopSegment(String stepId, int seconds) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> archiveAndReplaceLastSegment(String stepId) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }
}
