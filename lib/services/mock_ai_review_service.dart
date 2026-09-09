import '../models/ai_observation.dart';

class MockAiReviewService {
  Future<List<AiObservation>> loadObservations() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return [
      AiObservation(
        id: 'possible_leak',
        title: 'Demo Scenario: Possible Fluid Residue Near Oil Pan',
        description: 'Synthetic critical-concern scenario for testing technician review. No media was analyzed.',
        stage: 'Under Vehicle',
        confidencePercent: 0,
        requiresAction: true,
      ),
      AiObservation(
        id: 'drain_plug_clear',
        title: 'Demo Scenario: Drain Plug Review',
        description: 'Advisory placeholder only. No claim about actual leakage or service condition.',
        stage: 'Under Vehicle',
        confidencePercent: 0,
        requiresAction: false,
      ),
      AiObservation(
        id: 'oil_level',
        title: 'Demo Oil-Level Evidence Reminder',
        description: 'The demo tracks simulated photo metadata and a separate reinsertion statement. AI has not seen or interpreted an actual dipstick image.',
        stage: 'Under Hood',
        confidencePercent: 0,
        requiresAction: false,
      ),
    ];
  }
}
