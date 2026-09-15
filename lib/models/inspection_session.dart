import 'dart:collection';

import 'local_media.dart';

import 'package:flutter/foundation.dart';

import 'ai_observation.dart';
import 'customer.dart';
import 'vehicle.dart';
import 'verification_item.dart';
import 'inspection_step.dart';
import 'provenance.dart';
import '../services/mock_delivery_service.dart';
part 'inspection_session_codec.dart';

enum SavePhase { memory, saving, saved, failed, conflict }

enum DeliveryChannel { sms, email }

enum DeliveryAttemptStatus { pending, succeeded, failed, stale }

/// Immutable record of one simulated operation, independent of inspection approval.
class DeliveryAttempt {
  final String id;
  final ReportSnapshot snapshot;
  final DeliveryChannel channel;
  final String recipient;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final DeliveryAttemptStatus status;
  const DeliveryAttempt({
    required this.id,
    required this.snapshot,
    required this.channel,
    required this.recipient,
    required this.startedAt,
    this.finishedAt,
    this.status = DeliveryAttemptStatus.pending,
  });
  DeliveryAttempt finish(DeliveryAttemptStatus result, DateTime at) =>
      DeliveryAttempt(
        id: id,
        snapshot: snapshot,
        channel: channel,
        recipient: recipient,
        startedAt: startedAt,
        finishedAt: at,
        status: result,
      );
}

class InspectionCompletion {
  final ReportSnapshot snapshot;
  final DeliveryAttempt delivery;
  final DateTime completedAt;
  const InspectionCompletion(this.snapshot, this.delivery, this.completedAt);
}

class ReportSnapshot {
  final String inspectionId;
  final int revision;
  final Map<String, Object?> data;
  ReportSnapshot(this.inspectionId, this.revision, Map<String, Object?> data)
    : data = _freeze(data) as Map<String, Object?>;
}

Object? _freeze(Object? value) {
  if (value is Map<String, Object?>) {
    return Map<String, Object?>.unmodifiable(
      value.map((k, v) => MapEntry(k, _freeze(v))),
    );
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
  return value;
}

typedef SessionClock = DateTime Function();

enum CaptureKind { video, photo }

enum CaptureStatus {
  starting,
  recording,
  review,
  rejected,
  accepted,
  superseded,
  cancelled,
  failed,
}

class CaptureAttempt {
  final String id;
  final String inspectionId;
  final String stepId;
  final String technician;
  final DateTime createdAt;
  final CaptureKind kind;
  final DataProvenance provenance = DataProvenance.sample;
  bool realMedia = false;
  LocalMedia? media;
  bool mediaSaved = false;
  CaptureStatus status = CaptureStatus.starting;
  Duration duration = Duration.zero;
  DateTime? finishedAt;
  CaptureAttempt({
    required this.id,
    required this.inspectionId,
    required this.stepId,
    required this.technician,
    required this.createdAt,
    required this.kind,
  });
  bool get internalOnly => status != CaptureStatus.accepted;
}

class SessionNote {
  final String text;
  final String author;
  final DateTime updatedAt;
  const SessionNote(this.text, this.author, this.updatedAt);
}

class AuditEvent {
  final DateTime at;
  final String actor;
  final String action;
  final Map<String, String> details;
  AuditEvent(this.at, this.actor, this.action, Map<String, String> details)
    : details = Map.unmodifiable(details);
}

/// Active demo state only. Mutations go through this boundary so audit and
/// approval invalidation stay together. No real-service approval is issued.
class InspectionSession extends ChangeNotifier {
  final Map<String, Uint8List> pendingMedia = {};
  Future<Uint8List?> Function(String attemptId)? loadMedia;
  bool get mediaReady => attempts
      .where((a) => a.realMedia && a.status == CaptureStatus.accepted)
      .every((a) => a.media != null && a.mediaSaved);
  final ValueNotifier<SavePhase> savePhase = ValueNotifier(SavePhase.memory);
  Future<bool> Function()? persist;
  bool get persistenceEnabled => persist != null;
  Future<bool> flush() async => await persist?.call() ?? true;
  bool get saved => !persistenceEnabled || savePhase.value == SavePhase.saved;
  int? _approvedRevision;
  int? _acknowledgmentRevision;
  final String id;
  final String technician;
  final String location;
  final SessionClock clock;
  final DateTime createdAt;
  late DateTime updatedAt;
  final bool isDemo = true;
  final DataProvenance intakeProvenance = DataProvenance.sample;
  bool _active = true;
  bool get active => _active;
  bool get editable =>
      active && _completion == null && savePhase.value != SavePhase.conflict;
  InspectionCompletion? _completion;
  InspectionCompletion? get completion => _completion;
  final List<InspectionCompletion> _completedRevisions = [];
  List<InspectionCompletion> get completedRevisions =>
      List.unmodifiable(_completedRevisions);
  final List<DeliveryAttempt> _deliveryAttempts = [];
  List<DeliveryAttempt> get deliveryAttempts =>
      List.unmodifiable(_deliveryAttempts);
  bool get completionCurrent =>
      _completion != null &&
      demoApproved &&
      _completion!.snapshot.inspectionId == id &&
      _completion!.snapshot.revision == reportRevision;

  bool reopen(String reason, {required int completedRevision}) {
    if (!completionCurrent || sending || completedRevision != reportRevision) {
      return false;
    }
    if (reason.trim().isEmpty) {
      throw ArgumentError('A reopening reason is required.');
    }
    _completion = null;
    _invalidate('inspection explicitly reopened');
    _event('demo_inspection_reopened', {
      'reason': reason.trim(),
      'previousRevision': '$completedRevision',
      'revision': '$reportRevision',
    });
    return true;
  }

  Customer? _customer;
  Vehicle? _vehicle;
  Customer? get customer => _customer;
  Vehicle? get vehicle => _vehicle;
  List<VerificationItem> _verificationItems = [];
  List<VerificationItem> get verificationItems =>
      List.unmodifiable(_verificationItems);
  bool _squareSimulated = false;
  bool get squareSimulated => _squareSimulated;
  bool _filterUnderHood = false;
  bool get filterUnderHood => _filterUnderHood;
  bool _underHoodStage = false;
  bool get underHoodStage => _underHoodStage;
  bool _dipstickReinserted = false;
  bool get dipstickReinserted => _dipstickReinserted;
  final List<CaptureAttempt> _attempts = [];
  UnmodifiableListView<CaptureAttempt> get attempts =>
      UnmodifiableListView(_attempts);
  final List<AiObservation> _observations = [];
  List<AiObservation> get observations => List.unmodifiable(_observations);
  bool observationsLoaded = false;
  final List<AuditEvent> _audit = [];
  List<AuditEvent> get audit => List.unmodifiable(_audit);
  SessionNote? internalNote;
  SessionNote? customerRecommendation;
  final List<bool> _approvals = List.filled(4, false);
  List<bool> get approvals => List.unmodifiable(_approvals);
  bool _demoApproved = false;
  bool get demoApproved =>
      _demoApproved && _approvedRevision == reportRevision && canCompleteDemo;
  bool get realServiceReady =>
      false; // No live providers or evidence in this batch.
  bool get realApproved => false;

  int _reportRevision = 0;
  int get reportRevision => _reportRevision;
  ReportSnapshot? _reportSnapshot;
  ReportSnapshot? get reportSnapshot => _reportSnapshot;
  DeliveryChannel _deliveryChannel = DeliveryChannel.sms;
  DeliveryChannel get deliveryChannel => _deliveryChannel;
  final List<bool> _deliveryConfirmations = [false, false];
  List<bool> get deliveryConfirmations =>
      List.unmodifiable(_deliveryConfirmations);
  bool _sending = false;
  bool get sending => _sending;
  String? _deliveryMessage;
  String? get deliveryMessage => _deliveryMessage;
  String get recipient =>
      (deliveryChannel == DeliveryChannel.sms
              ? customer?.phone
              : customer?.email)
          ?.trim() ??
      '';
  String? get recipientProblem {
    if (recipient.isEmpty) {
      return 'No ${deliveryChannel.name.toUpperCase()} contact. Correct the session contact below.';
    }
    final valid = deliveryChannel == DeliveryChannel.sms
        ? RegExp(r'^\+?[0-9 ()-]+$').hasMatch(recipient) &&
              recipient.replaceAll(RegExp(r'\D'), '').length >= 10 &&
              recipient.replaceAll(RegExp(r'\D'), '').length <= 15
        : RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(recipient);
    return valid
        ? null
        : 'Invalid ${deliveryChannel.name.toUpperCase()} contact. Correct the session contact below.';
  }

  List<String> get reportBlockers => [
    if (!demoReady) 'Complete demo intake in SCR-001.',
    for (final s in requiredSteps.where((s) => !s.isComplete))
      'Required inspection check incomplete: ${s.label}.',
    if (!observationsLoaded) 'Complete advisory review in SCR-003.',
    for (final o in observations.where((o) => !o.resolved))
      'Unresolved concern: ${o.title}. ${o.nextAction}',
    if (!demoApproved) 'Return to SCR-003, review changes, manually acknowledge all four approvals and complete demo review.',
  ];
  bool get reportCurrent =>
      demoApproved &&
      _reportSnapshot?.inspectionId == id &&
      _reportSnapshot?.revision == reportRevision;
  bool get canSimulateSend =>
      editable &&
      reportCurrent &&
      recipientProblem == null &&
      _deliveryConfirmations.every((v) => v) &&
      !_sending;

  void _resetDeliveryReview() {
    _reportSnapshot = null;
    _deliveryConfirmations.fillRange(0, 2, false);
    _deliveryMessage = null;
  }

  bool prepareReport() {
    if (!editable || !demoApproved || sending) return false;
    _reportSnapshot = ReportSnapshot(
      id,
      reportRevision,
      projectCustomerReport(this),
    );
    _deliveryConfirmations.fillRange(0, 2, false);
    _deliveryMessage = null;
    _event('demo_report_prepared', {'revision': '$reportRevision'});
    return true;
  }

  void selectDeliveryChannel(DeliveryChannel channel) {
    if (!editable || sending || channel == _deliveryChannel) return;
    _deliveryChannel = channel;
    _deliveryConfirmations.fillRange(0, 2, false);
    _deliveryMessage = null;
    _event('delivery_channel_changed', {'channel': channel.name});
  }

  void setDeliveryConfirmation(int index, bool value) {
    if (!editable ||
        !reportCurrent ||
        sending ||
        (value && recipientProblem != null)) {
      return;
    }
    _deliveryConfirmations[index] = value;
    _deliveryMessage = null;
    _event('demo_delivery_review', {
      'revision': '$reportRevision',
      'index': '$index',
      'checked': '$value',
    });
  }

  Future<bool> simulateDelivery(DeliveryService service) async {
    if (!canSimulateSend) return false;
    final revision = reportRevision;
    final snapshot = _reportSnapshot!;
    final contact = recipient;
    final channel = deliveryChannel;
    _sending = true;
    _deliveryMessage = null;
    final attempt = DeliveryAttempt(
      id: '$id-d${_deliveryAttempts.length + 1}',
      snapshot: snapshot,
      channel: channel,
      recipient: contact,
      startedAt: clock(),
    );
    final attemptIndex = _deliveryAttempts.length;
    _deliveryAttempts.add(attempt);
    DeliveryAttempt finish(DeliveryAttemptStatus status, DateTime at) {
      final finished = attempt.finish(status, at);
      _deliveryAttempts[attemptIndex] = finished;
      return finished;
    }

    _event('demo_delivery_started', {
      'revision': '$revision',
      'channel': channel.name,
      'attempt': attempt.id,
      'recipient': contact,
    });
    bool current() =>
        reportCurrent &&
        identical(snapshot, _reportSnapshot) &&
        revision == reportRevision &&
        contact == recipient &&
        channel == deliveryChannel &&
        _deliveryConfirmations.every((v) => v);
    try {
      if (persistenceEnabled && !await flush()) {
        finish(DeliveryAttemptStatus.failed, clock());
        _deliveryMessage = 'Save failed — retry required. Simulation was not started. Nothing was sent.';
        _event('demo_delivery_not_started_save_failed');
        return false;
      }
      if (!current()) {
        finish(DeliveryAttemptStatus.stale, clock());
        _event('demo_delivery_stale', {'revision': '$revision'});
        return false;
      }
      await service.simulate(
        inspectionId: id,
        revision: revision,
        channel: channel.name,
        recipient: contact,
      );
      if (!current()) {
        finish(DeliveryAttemptStatus.stale, clock());
        _deliveryMessage = 'Session changed. Review the updated report and recipient again. Nothing was sent.';
        _event('demo_delivery_stale', {'revision': '$revision'});
        return false;
      }
      _deliveryMessage =
          'Simulation complete. Nothing was sent to the customer.';
      final at = clock();
      final delivered = finish(DeliveryAttemptStatus.succeeded, at);
      _completion = InspectionCompletion(snapshot, delivered, at);
      _completedRevisions.add(_completion!);
      _event(
        'demo_inspection_completed',
        {
          'revision': '$revision',
          'attempt': attempt.id,
          'realInspectionApproval': 'false',
        },
        null,
        at,
      );
      _event(
        'demo_delivery_completed',
        {'revision': '$revision', 'actualSend': 'false'},
        null,
        at,
      );
      if (persistenceEnabled && !await flush()) {
        _deliveryMessage = 'Simulation finished, but saving failed. Retry saving before continuing. Nothing was sent.';
        return false;
      }
      return true;
    } catch (_) {
      finish(DeliveryAttemptStatus.failed, clock());
      _deliveryMessage =
          'Simulation failed. Nothing was sent. Review and try again.';
      _event('demo_delivery_failed', {
        'revision': '$revision',
        'actualSend': 'false',
      });
      return false;
    } finally {
      _sending = false;
      _deliveryConfirmations.fillRange(0, 2, false);
      notifyListeners();
    }
  }

  final List<InspectionStep> _steps = [
    InspectionStep(
      id: 'drain_plug',
      label: 'Drain Plug',
      guidance:
          'Simulate a targeted final-verification clip. Minimum 5 seconds.',
      minimumSeconds: 5,
    ),
    InspectionStep(
      id: 'oil_filter',
      label: 'Oil Filter',
      guidance: 'Simulate the filter and surrounding area. Minimum 5 seconds.',
      minimumSeconds: 5,
    ),
    InspectionStep(
      id: 'axle_area',
      label: 'Differential / Axle Area',
      guidance: 'Simulate a short sweep for visible leaks.',
    ),
    InspectionStep(
      id: 'engine_underside',
      label: 'Engine Underside',
      guidance: 'Simulate a short sweep for leaks or residual oil.',
    ),
    InspectionStep(
      id: 'clean_residual_oil',
      label: 'Residual Oil Cleaned',
      guidance: 'Technician statement: spilled oil has been cleaned from surrounding areas.',
    ),
    InspectionStep(
      id: 'top_filter',
      label: 'Oil Filter (Top-Mounted)',
      guidance: 'Simulate the under-hood filter clip. Minimum 5 seconds.',
      minimumSeconds: 5,
    ),
    InspectionStep(
      id: 'dipstick',
      label: 'Oil Level / Dipstick',
      guidance: 'Simulate an oil-level photo, then separately confirm complete dipstick reinsertion.',
    ),
    InspectionStep(
      id: 'caps_touch',
      label: 'Cap & Component Touch Sequence',
      guidance: 'After dipstick reinsertion, touch and check oil cap, coolant cap, brake fluid, washer-fluid cap, and battery terminals.',
    ),
    InspectionStep(
      id: 'engine_bay',
      label: 'Engine Bay Leak Sweep',
      guidance: 'Simulate a targeted engine-bay sweep.',
    ),
    InspectionStep(
      id: 'tire_pressure',
      label: 'Tire Pressure Check',
      guidance: 'Technician statement, not an AI measurement: pressures checked and adjusted to specification or no adjustment needed.',
    ),
    InspectionStep(
      id: 'oil_light',
      label: 'Oil Change Light Reset',
      guidance: 'Technician statement: oil-change reminder reset.',
    ),
  ];

  InspectionSession({
    required this.id,
    required this.technician,
    this.location = 'Costa Oil Change - Chalmette',
    SessionClock? clock,
    DateTime? restoredCreatedAt,
  }) : clock = clock ?? DateTime.now,
       createdAt = restoredCreatedAt ?? (clock ?? DateTime.now)() {
    updatedAt = createdAt;
    _event('session_created', {'mode': 'demo'});
  }

  InspectionStep step(String id) => _steps.singleWhere((s) => s.id == id);
  List<InspectionStep> get underVehicleSteps => _steps
      .take(5)
      .where((s) => !(filterUnderHood && s.id == 'oil_filter'))
      .toList();
  List<InspectionStep> get underHoodSteps => _steps
      .skip(5)
      .where((s) => filterUnderHood || s.id != 'top_filter')
      .toList();
  List<InspectionStep> get requiredSteps => [
    ...underVehicleSteps,
    ...underHoodSteps,
  ];
  List<InspectionStep> get currentSteps =>
      underHoodStage ? underHoodSteps : underVehicleSteps;
  bool get stageComplete => currentSteps.every((s) => s.isComplete);
  bool get allChecksComplete =>
      mediaReady && requiredSteps.every((s) => s.isComplete);
  bool get demoReady =>
      active &&
      customer != null &&
      vehicle != null &&
      verificationItems.isNotEmpty &&
      squareSimulated;
  bool get flagsResolved =>
      observationsLoaded && observations.every((o) => o.resolved);
  bool get canCompleteDemo =>
      demoReady &&
      allChecksComplete &&
      flagsResolved &&
      _acknowledgmentRevision == reportRevision &&
      _approvals.every((value) => value);

  void _event(
    String action, [
    Map<String, String> details = const {},
    String? actor,
    DateTime? at,
  ]) {
    updatedAt = at ?? clock();
    _audit.add(AuditEvent(updatedAt, actor ?? technician, action, details));
    notifyListeners();
  }

  void _invalidate(String reason) {
    _approvedRevision = null;
    _acknowledgmentRevision = null;
    _reportRevision++;
    _resetDeliveryReview();
    _approvals.fillRange(0, _approvals.length, false);
    _demoApproved = false;
    _event('approval_invalidated', {'reason': reason});
  }

  void setCustomer(Customer value) {
    if (!editable) return;
    _customer = value;
    _invalidate('customer changed');
    _event('demo_customer_selected', {
      'name': value.displayName,
      'phone': value.phone,
    });
  }

  void setVehicle(Vehicle value, List<VerificationItem> items) {
    if (!editable) return;
    _vehicle = value;
    _verificationItems = List.of(items);
    // Evidence from a previous vehicle cannot qualify the changed intake.
    for (final attempt in _attempts) {
      if (attempt.status == CaptureStatus.accepted) {
        attempt.status = CaptureStatus.superseded;
      } else if (attempt.status == CaptureStatus.starting ||
          attempt.status == CaptureStatus.recording ||
          attempt.status == CaptureStatus.review) {
        attempt.status = CaptureStatus.cancelled;
        attempt.finishedAt = clock();
      }
    }
    for (final s in _steps) {
      s.status = InspectionStepStatus.pending;
    }
    _dipstickReinserted = false;
    _underHoodStage = false;
    _observations.clear();
    observationsLoaded = false;
    _invalidate('vehicle changed');
    _event('demo_vehicle_selected', {'vin': value.vin});
  }

  void simulateSquare() {
    if (!editable) return;
    _squareSimulated = true;
    _invalidate('simulated POS changed');
    _event('square_simulated');
  }

  void setFilterUnderHood(bool value) {
    if (!editable || _filterUnderHood == value) return;
    _filterUnderHood = value;
    for (final id in ['oil_filter', 'top_filter']) {
      step(id).status = InspectionStepStatus.pending;
      for (final a in _attempts.where(
        (a) => a.stepId == id && a.status == CaptureStatus.accepted,
      )) {
        a.status = CaptureStatus.superseded;
      }
    }
    _invalidate('filter location changed');
    _event('filter_location', {'underHood': '$value'});
  }

  void setStage(bool hood) {
    if (!editable) return;
    if (hood && !underVehicleSteps.every((s) => s.isComplete)) return;
    _underHoodStage = hood;
    _event('stage_changed', {'underHood': '$hood'});
  }

  bool usesVideo(String id) => const {
    'drain_plug',
    'oil_filter',
    'axle_area',
    'engine_underside',
    'top_filter',
    'caps_touch',
    'engine_bay',
  }.contains(id);
  CaptureAttempt? currentCapture(String stepId) {
    final matches = _attempts.where(
      (a) => a.stepId == stepId && a.status == CaptureStatus.accepted,
    );
    return matches.isEmpty ? null : matches.last;
  }

  bool canCapture(String stepId) =>
      editable &&
      demoReady &&
      currentSteps.any((s) => s.id == stepId) &&
      (stepId != 'oil_filter' || step('drain_plug').isComplete) &&
      (stepId != 'caps_touch' ||
          (currentCapture('dipstick') != null &&
              step('dipstick').isComplete &&
              dipstickReinserted));

  CaptureAttempt beginCapture(
    String stepId,
    CaptureKind kind, {
    bool realMedia = false,
  }) {
    if (!canCapture(stepId) ||
        (kind == CaptureKind.photo
            ? stepId != 'dipstick'
            : !usesVideo(stepId))) {
      throw StateError('This capture is not available yet.');
    }
    if (_attempts.any(
      (a) =>
          a.status == CaptureStatus.starting ||
          a.status == CaptureStatus.recording ||
          a.status == CaptureStatus.review,
    )) {
      throw StateError('Finish the current capture first.');
    }
    final attempt = CaptureAttempt(
      id: '$id-c${_attempts.length + 1}',
      inspectionId: id,
      stepId: stepId,
      technician: technician,
      createdAt: clock(),
      kind: kind,
    );
    attempt.realMedia = realMedia;
    _attempts.add(attempt);
    step(stepId).status = InspectionStepStatus.recording;
    if (stepId == 'dipstick') {
      _dipstickReinserted = false;
      step('caps_touch').status = InspectionStepStatus.pending;
      for (final old in _attempts.where(
        (a) => a.stepId == 'caps_touch' && a.status == CaptureStatus.accepted,
      )) {
        old.status = CaptureStatus.superseded;
      }
    }
    // A recheck is tied to the previous evidence; new evidence requires review.
    for (final observation in _observations.where((o) => o.requiresAction)) {
      observation.status = AiObservationStatus.pending;
      observation.correctiveAction = null;
      observation.recheck = null;
      observation.addressedAt = null;
      observation.addressedBy = null;
      observation.recheckPassed = false;
      observation.decisionReason = null;
      observation.decidedBy = null;
      observation.decidedAt = null;
    }
    _invalidate('evidence changed');
    _event(realMedia ? 'camera_capture_started' : 'simulated_capture_started', {
      'attempt': attempt.id,
      'step': stepId,
      'kind': kind.name,
    });
    return attempt;
  }

  void recordingStarted(CaptureAttempt a) {
    if (!editable ||
        !_attempts.contains(a) ||
        a.status != CaptureStatus.starting) {
      return;
    }
    a.status = CaptureStatus.recording;
    _event(
      a.realMedia ? 'camera_recording_ready' : 'simulated_recording_ready',
      {'attempt': a.id},
    );
  }

  void finishCapture(CaptureAttempt a, Duration duration) {
    if (!editable ||
        !_attempts.contains(a) ||
        !(a.status == CaptureStatus.starting ||
            a.status == CaptureStatus.recording)) {
      return;
    }
    a.duration = duration;
    a.finishedAt = clock();
    final enough =
        (!a.realMedia || a.media != null) &&
        (a.kind == CaptureKind.photo ||
            duration >= Duration(seconds: step(a.stepId).minimumSeconds));
    a.status = enough ? CaptureStatus.review : CaptureStatus.rejected;
    step(a.stepId).status = enough
        ? InspectionStepStatus.captured
        : InspectionStepStatus.needsRetry;
    _event(enough ? 'capture_awaiting_review' : 'capture_too_short', {
      'attempt': a.id,
      'milliseconds': '${duration.inMilliseconds}',
    });
  }

  void acceptCapture(CaptureAttempt a) {
    if (!editable ||
        !_attempts.contains(a) ||
        a.status != CaptureStatus.review ||
        (a.realMedia && !a.mediaSaved)) {
      return;
    }
    for (final previous in _attempts.where(
      (p) =>
          p.stepId == a.stepId && p != a && p.status == CaptureStatus.accepted,
    )) {
      previous.status = CaptureStatus.superseded;
    }
    a.status = CaptureStatus.accepted;
    step(a.stepId).capturedSeconds = a.duration.inSeconds;
    step(a.stepId).status = a.stepId == 'dipstick'
        ? InspectionStepStatus.captured
        : InspectionStepStatus.confirmed;
    _invalidate('capture accepted');
    _event(a.realMedia ? 'real_media_kept_in_demo' : 'simulated_capture_kept', {
      'attempt': a.id,
    });
  }

  void finishRealCapture(CaptureAttempt a, CapturedMedia result) {
    if (!editable ||
        !_attempts.contains(a) ||
        !a.realMedia ||
        !(a.status == CaptureStatus.starting ||
            a.status == CaptureStatus.recording)) {
      return;
    }
    if (result.bytes.isEmpty ||
        !result.playable ||
        result.duration.isNegative ||
        (a.kind == CaptureKind.video && result.duration == Duration.zero)) {
      cancelCapture(a, failed: true);
      throw StateError(
        'Empty, unplayable, or unknown-duration media cannot be accepted.',
      );
    }
    final m = LocalMedia(
      id: a.id,
      inspectionId: id,
      stepId: a.stepId,
      stage:
          {
            'top_filter',
            'dipstick',
            'caps_touch',
            'engine_bay',
          }.contains(a.stepId)
          ? 'Under Hood'
          : 'Under Vehicle',
      technician: technician,
      source: result.source,
      mimeType: result.mimeType,
      revision: reportRevision,
      byteSize: result.bytes.length,
      durationMs: result.duration.inMilliseconds,
      capturedAt: a.createdAt,
      checksum: mediaChecksum(result.bytes),
    );
    LocalMedia.fromMap(m.toMap());
    if ((a.kind == CaptureKind.photo) != m.mimeType.startsWith('image/')) {
      throw StateError('Media format does not match this step.');
    }
    a.media = m;
    pendingMedia[a.id] = Uint8List.fromList(result.bytes);
    finishCapture(a, result.duration);
  }

  void mediaWriteConfirmed(Iterable<String> ids) {
    for (final a in _attempts.where((a) => ids.contains(a.id))) {
      a.mediaSaved = true;
      pendingMedia.remove(a.id);
    }
    notifyListeners();
  }

  void retryCapture(CaptureAttempt a) {
    if (!editable ||
        !_attempts.contains(a) ||
        a.status != CaptureStatus.review) {
      return;
    }
    a.status = CaptureStatus.superseded;
    step(a.stepId).status = InspectionStepStatus.pending;
    _invalidate('retake requested');
    _event('capture_superseded_internal_only', {'attempt': a.id});
  }

  void cancelCapture(CaptureAttempt a, {bool failed = false}) {
    if (!_attempts.contains(a)) return;
    if (a.status != CaptureStatus.starting &&
        a.status != CaptureStatus.recording) {
      return;
    }
    a.status = failed ? CaptureStatus.failed : CaptureStatus.cancelled;
    a.finishedAt = clock();
    step(a.stepId).status = InspectionStepStatus.needsRetry;
    _invalidate('capture interrupted');
    _event(failed ? 'capture_failed' : 'capture_cancelled', {'attempt': a.id});
  }

  void confirmStatement(String id) {
    if (!editable || !currentSteps.any((s) => s.id == id) || usesVideo(id)) {
      return;
    }
    if (id == 'dipstick' &&
        (currentCapture(id) == null ||
            step(id).status != InspectionStepStatus.captured)) {
      return;
    }
    if (id == 'dipstick') _dipstickReinserted = true;
    step(id).status = InspectionStepStatus.confirmed;
    _invalidate('technician statement changed');
    _event('technician_statement', {
      'step': id,
      'statement': id == 'dipstick'
          ? 'dipstick fully reinserted'
          : step(id).guidance,
    });
  }

  void failCheck(String id, String reason) {
    if (!editable) return;
    if (reason.trim().isEmpty) {
      throw ArgumentError('A failure reason is required.');
    }
    step(id).status = InspectionStepStatus.needsRetry;
    if (id == 'dipstick') {
      _dipstickReinserted = false;
      step('caps_touch').status = InspectionStepStatus.pending;
    }
    _invalidate('required check failed');
    _event('required_check_failed', {'step': id, 'reason': reason.trim()});
  }

  void loadObservations(List<AiObservation> values) {
    if (!editable || observationsLoaded) return;
    _observations.addAll(values);
    observationsLoaded = true;
    _invalidate('demo observations loaded');
    _event('demo_ai_loaded', {
      'count': '${values.length}',
      'actualMediaAnalyzed': 'false',
    });
  }

  void decide(
    AiObservation o,
    AiObservationStatus assessment,
    String reason, {
    bool notActualConcern = false,
  }) {
    if (!editable || !_observations.contains(o)) return;
    if (reason.trim().isEmpty) {
      throw ArgumentError('A technician reason is required.');
    }
    if (assessment == AiObservationStatus.dismissed && !notActualConcern) {
      throw ArgumentError(
        'A dismissal must explicitly determine this is not an actual concern.',
      );
    }
    final previousAssessment = o.status;
    o.status = assessment;
    o.concernEstablished =
        o.requiresAction && assessment == AiObservationStatus.confirmed;
    o.decisionReason = reason.trim();
    o.decidedBy = technician;
    o.decidedAt = clock();
    o.correctiveAction = null;
    o.recheck = null;
    o.addressedAt = null;
    o.addressedBy = null;
    o.recheckPassed = false;
    _invalidate('review decision changed');
    _event('observation_assessed', {
      'observation': o.id,
      'assessment': assessment.name,
      'reason': reason.trim(),
      'previousAssessment': previousAssessment.name,
      'notActualConcern': '$notActualConcern',
    });
  }

  void addressConcern(
    AiObservation o,
    String action,
    String recheck, {
    required bool recheckPassed,
  }) {
    if (!editable ||
        !_observations.contains(o) ||
        !o.concernEstablished ||
        o.status != AiObservationStatus.confirmed ||
        action.trim().isEmpty ||
        recheck.trim().isEmpty) {
      throw ArgumentError(
        'Confirm the concern and document both corrective action and recheck.',
      );
    }
    o.correctiveAction = action.trim();
    o.recheck = recheck.trim();
    o.addressedBy = technician;
    o.addressedAt = clock();
    o.recheckPassed = recheckPassed;
    _invalidate('corrective action documented');
    _event('concern_addressed', {
      'observation': o.id,
      'action': action.trim(),
      'recheck': recheck.trim(),
      'recheckPassed': '$recheckPassed',
    });
  }

  void setNote(String text, {required bool customerVisible, String? author}) {
    if (!editable) return;
    final actor = (author ?? technician).trim();
    if (actor.isEmpty) throw ArgumentError('An author is required.');
    final note = SessionNote(text, actor, clock());
    if (customerVisible) {
      customerRecommendation = note;
      _invalidate('customer recommendation changed');
    } else {
      internalNote = note;
    }
    _event('note_updated', {
      'visibility': customerVisible ? 'customer' : 'internal',
      'text': text,
    }, actor);
  }

  void setApproval(int index, bool value) {
    if (!editable ||
        (value && (!allChecksComplete || !flagsResolved || !demoReady))) {
      return;
    }
    _approvals[index] = value;
    _demoApproved = false;
    _reportRevision++;
    _acknowledgmentRevision = _reportRevision;
    _resetDeliveryReview();
    _event('demo_acknowledgment', {'index': '$index', 'checked': '$value'});
  }

  bool completeDemo() {
    if (!editable || !canCompleteDemo) return false;
    _demoApproved = true;
    _approvedRevision = reportRevision;
    _event('demo_review_completed', {
      'realApproval': 'false',
      'revision': '$reportRevision',
    });
    return true;
  }

  void abandon() {
    if (!editable) return;
    _active = false;
    for (final a in _attempts) {
      cancelCapture(a);
    }
    _invalidate('session abandoned');
    _event('session_abandoned');
  }
}

/// Explicit allow-list: no audit, internal notes, raw AI, or synthetic facts.
Map<String, Object?> projectCustomerReport(InspectionSession session) => {
  'inspectionId': session.id,
  'revision': session.reportRevision,
  'product': 'Project Verify',
  'location': session.location,
  'technician': session.technician,
  'createdAt': session.createdAt.toIso8601String(),
  'reportStatus': 'DEMO — NOT A LIVE SERVICE REPORT',
  'playbackAvailable': session.attempts.any(
    (a) =>
        a.status == CaptureStatus.accepted && a.media != null && a.mediaSaved,
  ),
  if (session.attempts.any(
    (a) =>
        a.status == CaptureStatus.accepted && a.media != null && a.mediaSaved,
  ))
    'media': session.attempts
        .where(
          (a) =>
              a.status == CaptureStatus.accepted &&
              a.media != null &&
              a.mediaSaved,
        )
        .map((a) => a.media!.toMap())
        .toList(),
  'documentedChecks': session.requiredSteps
      .where((s) => s.isComplete)
      .map(
        (s) => {
          'label': s.label,
          'result': session.usesVideo(s.id) || s.id == 'dipstick'
              ? (session.currentCapture(s.id)?.realMedia == true
                    ? 'Real captured media in a demo — not proof of service condition'
                    : 'Simulated evidence metadata only — no media captured')
              : 'Demo technician statement — not independently verified',
          'provenance': DataProvenance.sample.name,
        },
      )
      .toList(),
  'isDemo': session.isDemo,
  'realApproved': session.realApproved,
  'customer': {
    'name': session.customer?.displayName,
    'provenance': session.intakeProvenance.name,
  },
  'vehicle': {
    'description': session.vehicle?.displayName,
    'vin': session.vehicle?.vin,
    'provenance': session.intakeProvenance.name,
  },
  'recommendation': session.customerRecommendation == null
      ? null
      : {
          'text': session.customerRecommendation!.text,
          'author': session.customerRecommendation!.author,
          'updatedAt': session.customerRecommendation!.updatedAt
              .toIso8601String(),
          'provenance': DataProvenance.technicianStatement.name,
        },
  'verifiedFacts': session.verificationItems
      .where((v) => !session.isDemo && v.genuinelyVerified)
      .map((v) => {'label': v.label, 'value': v.value, 'source': v.source})
      .toList(),
};
