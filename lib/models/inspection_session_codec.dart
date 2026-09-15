part of 'inspection_session.dart';

/// Schema 1 stores domain fields, never reconstructed UI strings. Future schema
/// migrations must be explicit and non-destructive; unknown versions are rejected.
extension InspectionSessionCodec on InspectionSession {
  Map<String, Object?> toRecord() => {
    'schema': 2,
    'id': id,
    'revision': reportRevision,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'technician': technician,
    'location': location,
    'demo': isDemo,
    'provenance': intakeProvenance.name,
    'active': active,
    'customer': customer == null
        ? null
        : {
            'firstName': customer!.firstName,
            'lastName': customer!.lastName,
            'phone': customer!.phone,
            'email': customer!.email,
          },
    'vehicle': vehicle == null
        ? null
        : {
            'vin': vehicle!.vin,
            'year': vehicle!.year,
            'make': vehicle!.make,
            'model': vehicle!.model,
            'trim': vehicle!.trim,
            'engine': vehicle!.engine,
            'drivetrain': vehicle!.drivetrain,
          },
    'verification': verificationItems
        .map(
          (v) => {
            'label': v.label,
            'value': v.value,
            'source': v.source,
            'status': v.status.name,
            'provenance': v.provenance.name,
          },
        )
        .toList(),
    'square': squareSimulated,
    'filterUnderHood': filterUnderHood,
    'underHoodStage': underHoodStage,
    'dipstickReinserted': dipstickReinserted,
    'steps': _steps
        .map(
          (s) => {
            'id': s.id,
            'status': s.status.name,
            'capturedSeconds': s.capturedSeconds,
          },
        )
        .toList(),
    'captures': attempts
        .map(
          (a) => {
            'id': a.id,
            'inspectionId': a.inspectionId,
            'stepId': a.stepId,
            'technician': a.technician,
            'createdAt': a.createdAt.toIso8601String(),
            'kind': a.kind.name,
            'realMedia': a.realMedia,
            'media': a.media?.toMap(),
            'provenance': a.provenance.name,
            'status': a.status.name,
            'durationMs': a.duration.inMilliseconds,
            'finishedAt': a.finishedAt?.toIso8601String(),
          },
        )
        .toList(),
    'observationsLoaded': observationsLoaded,
    'observations': observations
        .map(
          (o) => {
            'id': o.id,
            'title': o.title,
            'description': o.description,
            'stage': o.stage,
            'confidencePercent': o.confidencePercent,
            'requiresAction': o.requiresAction,
            'provenance': o.provenance.name,
            'status': o.status.name,
            'decisionReason': o.decisionReason,
            'decidedBy': o.decidedBy,
            'decidedAt': o.decidedAt?.toIso8601String(),
            'correctiveAction': o.correctiveAction,
            'recheck': o.recheck,
            'addressedBy': o.addressedBy,
            'addressedAt': o.addressedAt?.toIso8601String(),
            'recheckPassed': o.recheckPassed,
            'concernEstablished': o.concernEstablished,
          },
        )
        .toList(),
    'internalNote': _noteRecord(internalNote),
    'recommendation': _noteRecord(customerRecommendation),
    'approvals': approvals,
    'approved': _demoApproved,
    'approvedRevision': _approvedRevision,
    'acknowledgmentRevision': _acknowledgmentRevision,
    'snapshot': _reportSnapshot?.data,
    'deliveryChannel': deliveryChannel.name,
    'deliveryConfirmations': deliveryConfirmations,
    'deliveryMessage': deliveryMessage,
    'deliveries': deliveryAttempts
        .map(
          (a) => {
            'id': a.id,
            'snapshot': a.snapshot.data,
            'channel': a.channel.name,
            'recipient': a.recipient,
            'startedAt': a.startedAt.toIso8601String(),
            'finishedAt': a.finishedAt?.toIso8601String(),
            'status': a.status.name,
          },
        )
        .toList(),
    'completed': completedRevisions
        .map(
          (c) => {
            'attemptId': c.delivery.id,
            'completedAt': c.completedAt.toIso8601String(),
          },
        )
        .toList(),
    'currentCompletion': completion?.delivery.id,
    'audit': audit
        .map(
          (e) => {
            'at': e.at.toIso8601String(),
            'actor': e.actor,
            'action': e.action,
            'details': e.details,
          },
        )
        .toList(),
  };
}

Map<String, Object?>? _noteRecord(SessionNote? n) => n == null
    ? null
    : {
        'text': n.text,
        'author': n.author,
        'updatedAt': n.updatedAt.toIso8601String(),
      };
Map<String, dynamic> _recordMap(Object? v) =>
    Map<String, dynamic>.from(v as Map);
DateTime _date(Object? v) => DateTime.parse(v as String);
DateTime? _maybeDate(Object? v) => v == null ? null : _date(v);
SessionNote? _readNote(Object? value) {
  if (value == null) return null;
  final v = _recordMap(value);
  return SessionNote(
    v['text'] as String,
    v['author'] as String,
    _date(v['updatedAt']),
  );
}

ReportSnapshot _readSnapshot(Object? value, String inspectionId) {
  final v = _recordMap(value);
  for (final key in [
    'product',
    'location',
    'technician',
    'createdAt',
    'reportStatus',
  ]) {
    if (v[key] is! String) {
      throw const FormatException('Invalid snapshot field');
    }
  }
  _date(v['createdAt']);
  if (v['product'] != 'Project Verify' ||
      v['reportStatus'] != 'DEMO — NOT A LIVE SERVICE REPORT') {
    throw const FormatException('Invalid report identity');
  }
  final customer = _recordMap(v['customer']);
  final vehicle = _recordMap(v['vehicle']);
  if (customer['name'] is! String ||
      customer['provenance'] != 'sample' ||
      vehicle['description'] is! String ||
      vehicle['vin'] is! String ||
      vehicle['provenance'] != 'sample') {
    throw const FormatException('Invalid snapshot intake');
  }
  if (v['recommendation'] != null) {
    final note = _recordMap(v['recommendation']);
    if (note['text'] is! String ||
        note['author'] is! String ||
        note['provenance'] != 'technicianStatement') {
      throw const FormatException('Invalid snapshot recommendation');
    }
    _date(note['updatedAt']);
  }
  const allowed = {
    'inspectionId',
    'revision',
    'product',
    'location',
    'technician',
    'createdAt',
    'reportStatus',
    'playbackAvailable',
    'documentedChecks',
    'isDemo',
    'realApproved',
    'customer',
    'vehicle',
    'recommendation',
    'verifiedFacts',
    'media',
  };
  if (v.keys.any((k) => !allowed.contains(k)) ||
      v['inspectionId'] != inspectionId ||
      v['isDemo'] != true ||
      v['realApproved'] != false ||
      v['playbackAvailable'] !=
          (v['media'] is List && (v['media'] as List).isNotEmpty) ||
      (v['verifiedFacts'] as List).isNotEmpty ||
      (v['revision'] as int) < 0) {
    throw const FormatException('Invalid demo snapshot');
  }
  void keys(Object? value, Set<String> keys) {
    if (value != null && _recordMap(value).keys.any((k) => !keys.contains(k))) {
      throw const FormatException('Unexpected customer projection fields');
    }
  }

  keys(v['customer'], {'name', 'provenance'});
  keys(v['vehicle'], {'description', 'vin', 'provenance'});
  keys(v['recommendation'], {'text', 'author', 'updatedAt', 'provenance'});
  for (final value in (v['media'] as List? ?? [])) {
    final m = LocalMedia.fromMap(value as Map);
    if (m.inspectionId != inspectionId) {
      throw const FormatException('Report media owner mismatch');
    }
    keys(value, m.toMap().keys.toSet());
  }
  for (final c in v['documentedChecks'] as List) {
    keys(c, {'label', 'result', 'provenance'});
    if (_recordMap(c)['provenance'] != 'sample') {
      throw const FormatException('Non-demo check');
    }
  }
  return ReportSnapshot(inspectionId, v['revision'] as int, v);
}

InspectionSession restoreInspection(
  Object? record, {
  SessionClock? clock,
  Set<String> availableMedia = const {},
}) {
  final v = _recordMap(record);
  if (v['schema'] != 1 && v['schema'] != 2) {
    throw const FormatException(
      'Unsupported inspection schema; record preserved',
    );
  }
  if (v['demo'] != true || v['provenance'] != 'sample') {
    throw const FormatException('Unsupported provenance');
  }
  final created = _date(v['createdAt']);
  // Constructor time is the original creation time, then restore the live clock.
  final s = InspectionSession(
    id: v['id'] as String,
    technician: v['technician'] as String,
    location: v['location'] as String,
    clock: clock,
    restoredCreatedAt: created,
  );
  s.updatedAt = _date(v['updatedAt']);
  s._reportRevision = v['revision'] as int;
  if (s.id.isEmpty || s.technician.isEmpty || s._reportRevision < 0) {
    throw const FormatException('Invalid identity');
  }
  s._active = v['active'] as bool;
  if (v['customer'] != null) {
    final c = _recordMap(v['customer']);
    s._customer = Customer(
      firstName: c['firstName'] as String,
      lastName: c['lastName'] as String,
      phone: c['phone'] as String,
      email: c['email'] as String?,
    );
  }
  if (v['vehicle'] != null) {
    final c = _recordMap(v['vehicle']);
    s._vehicle = Vehicle(
      vin: c['vin'] as String,
      year: c['year'] as int,
      make: c['make'] as String,
      model: c['model'] as String,
      trim: c['trim'] as String,
      engine: c['engine'] as String,
      drivetrain: c['drivetrain'] as String,
    );
  }
  s._verificationItems = (v['verification'] as List).map((value) {
    final c = _recordMap(value);
    if (c['provenance'] != 'sample') {
      throw const FormatException('Unsupported verification source');
    }
    return VerificationItem(
      label: c['label'] as String,
      value: c['value'] as String,
      source: c['source'] as String,
      status: VerificationStatus.values.byName(c['status'] as String),
    );
  }).toList();
  s._squareSimulated = v['square'] as bool;
  s._filterUnderHood = v['filterUnderHood'] as bool;
  s._underHoodStage = v['underHoodStage'] as bool;
  s._dipstickReinserted = v['dipstickReinserted'] as bool;
  final steps = v['steps'] as List;
  final ids = <String>{};
  for (final value in steps) {
    final c = _recordMap(value);
    final id = c['id'] as String;
    if (!ids.add(id)) throw const FormatException('Duplicate step');
    s.step(id).status = InspectionStepStatus.values.byName(
      c['status'] as String,
    );
    s.step(id).capturedSeconds = c['capturedSeconds'] as int;
  }
  if (ids.length != s._steps.length) {
    throw const FormatException('Missing inspection steps');
  }
  for (final value in v['captures'] as List) {
    final c = _recordMap(value);
    if (c['inspectionId'] != s.id || c['provenance'] != 'sample') {
      throw const FormatException('Invalid capture owner');
    }
    s.step(c['stepId'] as String);
    final a = CaptureAttempt(
      id: c['id'] as String,
      inspectionId: s.id,
      stepId: c['stepId'] as String,
      technician: c['technician'] as String,
      createdAt: _date(c['createdAt']),
      kind: CaptureKind.values.byName(c['kind'] as String),
    );
    a.status = CaptureStatus.values.byName(c['status'] as String);
    a.realMedia = c['realMedia'] as bool? ?? false;
    if (c['media'] != null) {
      a.media = LocalMedia.fromMap(c['media'] as Map);
      if (!a.realMedia ||
          a.media!.id != a.id ||
          a.media!.inspectionId != s.id ||
          a.media!.stepId != a.stepId ||
          a.media!.stage !=
              ({
                    'top_filter',
                    'dipstick',
                    'caps_touch',
                    'engine_bay',
                  }.contains(a.stepId)
                  ? 'Under Hood'
                  : 'Under Vehicle') ||
          (a.kind == CaptureKind.photo) !=
              a.media!.mimeType.startsWith('image/') ||
          a.media!.technician != a.technician ||
          a.media!.capturedAt != a.createdAt) {
        throw const FormatException('Media association mismatch');
      }
      a.mediaSaved = availableMedia.contains(a.id);
    }
    a.duration = Duration(milliseconds: c['durationMs'] as int);
    a.finishedAt = _maybeDate(c['finishedAt']);
    if (a.media != null && a.media!.durationMs != a.duration.inMilliseconds) {
      throw const FormatException('Media duration mismatch');
    }
    if (s._attempts.any((old) => old.id == a.id) || a.duration.isNegative) {
      throw const FormatException('Invalid capture metadata');
    }
    s._attempts.add(a);
  }
  s.observationsLoaded = v['observationsLoaded'] as bool;
  for (final value in v['observations'] as List) {
    final c = _recordMap(value);
    if (c['provenance'] != 'sample') {
      throw const FormatException('Invalid AI provenance');
    }
    final o = AiObservation(
      id: c['id'] as String,
      title: c['title'] as String,
      description: c['description'] as String,
      stage: c['stage'] as String,
      confidencePercent: c['confidencePercent'] as int,
      requiresAction: c['requiresAction'] as bool,
      status: AiObservationStatus.values.byName(c['status'] as String),
    );
    o.decisionReason = c['decisionReason'] as String?;
    o.decidedBy = c['decidedBy'] as String?;
    o.decidedAt = _maybeDate(c['decidedAt']);
    o.correctiveAction = c['correctiveAction'] as String?;
    o.recheck = c['recheck'] as String?;
    o.addressedBy = c['addressedBy'] as String?;
    o.addressedAt = _maybeDate(c['addressedAt']);
    o.recheckPassed = c['recheckPassed'] as bool;
    o.concernEstablished = c['concernEstablished'] as bool;
    if (s._observations.any((old) => old.id == o.id)) {
      throw const FormatException('Duplicate observation');
    }
    s._observations.add(o);
  }
  s.internalNote = _readNote(v['internalNote']);
  s.customerRecommendation = _readNote(v['recommendation']);
  final approvals = List<bool>.from(v['approvals'] as List);
  if (approvals.length != 4) throw const FormatException('Invalid approvals');
  s._approvals.setAll(0, approvals);
  s._demoApproved = v['approved'] as bool;
  s._approvedRevision = v['approvedRevision'] as int?;
  s._acknowledgmentRevision = v['acknowledgmentRevision'] as int?;
  s._reportSnapshot = v['snapshot'] == null
      ? null
      : _readSnapshot(v['snapshot'], s.id);
  s._deliveryChannel = DeliveryChannel.values.byName(
    v['deliveryChannel'] as String,
  );
  final confirmations = List<bool>.from(v['deliveryConfirmations'] as List);
  if (confirmations.length != 2) {
    throw const FormatException('Invalid delivery review');
  }
  s._deliveryConfirmations.setAll(0, confirmations);
  s._deliveryMessage = v['deliveryMessage'] as String?;
  for (final value in v['deliveries'] as List) {
    final c = _recordMap(value);
    final a = DeliveryAttempt(
      id: c['id'] as String,
      snapshot: _readSnapshot(c['snapshot'], s.id),
      channel: DeliveryChannel.values.byName(c['channel'] as String),
      recipient: c['recipient'] as String,
      startedAt: _date(c['startedAt']),
      finishedAt: _maybeDate(c['finishedAt']),
      status: DeliveryAttemptStatus.values.byName(c['status'] as String),
    );
    if (s._deliveryAttempts.any((old) => old.id == a.id)) {
      throw const FormatException('Duplicate delivery');
    }
    s._deliveryAttempts.add(a);
  }
  for (final value in v['completed'] as List) {
    final c = _recordMap(value);
    final a = s._deliveryAttempts.singleWhere((a) => a.id == c['attemptId']);
    final at = _date(c['completedAt']);
    if (a.status != DeliveryAttemptStatus.succeeded || a.finishedAt != at) {
      throw const FormatException('Invalid completion');
    }
    s._completedRevisions.add(InspectionCompletion(a.snapshot, a, at));
  }
  if (v['currentCompletion'] != null) {
    s._completion = s._completedRevisions.singleWhere(
      (c) => c.delivery.id == v['currentCompletion'],
    );
  }
  s._audit.clear();
  for (final value in v['audit'] as List) {
    final c = _recordMap(value);
    s._audit.add(
      AuditEvent(
        _date(c['at']),
        c['actor'] as String,
        c['action'] as String,
        Map<String, String>.from(c['details'] as Map),
      ),
    );
  }
  var recovered = false;
  for (final a in s._attempts) {
    if (a.status == CaptureStatus.starting ||
        a.status == CaptureStatus.recording ||
        (a.status == CaptureStatus.review && !a.realMedia)) {
      a.status = CaptureStatus.cancelled;
      a.finishedAt = s.clock();
      s.step(a.stepId).status = InspectionStepStatus.needsRetry;
      recovered = true;
    }
  }
  for (var i = 0; i < s._deliveryAttempts.length; i++) {
    final a = s._deliveryAttempts[i];
    if (a.status == DeliveryAttemptStatus.pending) {
      s._deliveryAttempts[i] = a.finish(DeliveryAttemptStatus.stale, s.clock());
      recovered = true;
    }
  }
  // Recheck actual accepted metadata and the sequence, not stored completion flags.
  for (final step in s.requiredSteps.where((step) => step.isComplete)) {
    if (s.usesVideo(step.id) || step.id == 'dipstick') {
      final a = s.currentCapture(step.id);
      if (a == null ||
          a.finishedAt == null ||
          (a.realMedia && !a.mediaSaved) ||
          a.kind !=
              (step.id == 'dipstick' ? CaptureKind.photo : CaptureKind.video) ||
          a.duration < Duration(seconds: step.minimumSeconds) ||
          (step.id == 'dipstick' && !s.dipstickReinserted)) {
        step.status = InspectionStepStatus.needsRetry;
        recovered = true;
      }
    }
  }
  final photo = s.currentCapture('dipstick');
  final caps = s.currentCapture('caps_touch');
  if (s.step('caps_touch').isComplete &&
      (!s.step('dipstick').isComplete ||
          photo == null ||
          caps == null ||
          s._attempts.indexOf(photo) >= s._attempts.indexOf(caps))) {
    s.step('caps_touch').status = InspectionStepStatus.needsRetry;
    recovered = true;
  }
  final lastInvalidation = s.audit.lastIndexWhere(
    (e) => e.action == 'approval_invalidated',
  );
  var auditApprovalValid = true;
  for (var i = 0; i < 4; i++) {
    if (s._approvals[i]) {
      final index = s.audit.lastIndexWhere(
        (e) => e.action == 'demo_acknowledgment' && e.details['index'] == '$i',
      );
      if (index <= lastInvalidation ||
          index < 0 ||
          s.audit[index].details['checked'] != 'true') {
        auditApprovalValid = false;
      }
    }
  }
  if (s._demoApproved &&
      !s.audit.any(
        (e) =>
            e.action == 'demo_review_completed' &&
            e.details['revision'] == '${s.reportRevision}',
      )) {
    auditApprovalValid = false;
  }
  if (!auditApprovalValid ||
      (s._demoApproved && !s.demoApproved) ||
      (s._approvals.any((v) => v) &&
          (!s.allChecksComplete ||
              !s.flagsResolved ||
              s._acknowledgmentRevision != s.reportRevision)) ||
      (s._reportSnapshot != null && !s.reportCurrent)) {
    recovered = true;
  }
  if (s._completion != null &&
      (recovered ||
          !s.completionCurrent ||
          !s.audit.any(
            (e) =>
                e.action == 'demo_inspection_completed' &&
                e.at == s.completion!.completedAt &&
                e.details['revision'] == '${s.reportRevision}',
          ))) {
    throw const FormatException(
      'Completed record failed consistency checks; preserved for recovery',
    );
  }
  if (recovered) {
    s._invalidate(
      'interrupted work or inconsistent approval recovered; fresh review required',
    );
    s._event('local_restore_requires_review', {'actualSend': 'false'});
  }
  // A reload is not a fresh recipient/preview review.
  s._deliveryConfirmations.fillRange(0, 2, false);
  return s;
}
