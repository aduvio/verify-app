import '../models/ai_observation.dart';

class MockAiReviewService {
  Future<List<AiObservation>> loadObservations() async {
    await Future.delayed(const Duration(milliseconds: 350));

    return [
      AiObservation(
        id: 'possible_leak',
        title: 'Possible Fluid Residue Near Oil Pan',
        description:
            'AI observed possible wetness near the oil-pan area. Technician review is required before this can be included in the inspection record.',
        stage: 'Under Vehicle',
        confidencePercent: 78,
        requiresAction: true,
      ),
      AiObservation(
        id: 'drain_plug_clear',
        title: 'Drain Plug Area Appears Clear',
        description:
            'AI observed no obvious active leakage in the captured drain-plug segment.',
        stage: 'Under Vehicle',
        confidencePercent: 91,
        requiresAction: false,
      ),
      AiObservation(
        id: 'oil_level',
        title: 'Oil Level Capture Present',
        description:
            'A dipstick/oil-level capture was included. Final interpretation remains the technician’s responsibility.',
        stage: 'Under Hood',
        confidencePercent: 88,
        requiresAction: false,
      ),
    ];
  }
}
