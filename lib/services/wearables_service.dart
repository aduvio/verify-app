import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Connection diagnostics only. Does not create inspection evidence or approvals.
abstract interface class WearablesService {
  Stream<Map<String, dynamic>> get events;
  Future<Map<String, dynamic>> invoke(String operation);
}

class IOSWearablesService implements WearablesService {
  static const methods = MethodChannel('project_verify/wearables');
  static const updates = EventChannel('project_verify/wearables/events');
  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Stream<Map<String, dynamic>> get events => supported
      ? updates.receiveBroadcastStream().map(
          (event) => Map<String, dynamic>.from(event as Map),
        )
      : const Stream.empty();

  @override
  Future<Map<String, dynamic>> invoke(String operation) async {
    if (!supported) {
      return {
        'available': false,
        'error': 'Meta DAT requires the native iOS test build. Web and Windows cannot connect.',
      };
    }
    return Map<String, dynamic>.from(
      await methods.invokeMapMethod<String, dynamic>(operation) ?? {},
    );
  }
}

class WearablesController extends ChangeNotifier {
  WearablesController(this.service);
  final WearablesService service;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Map<String, dynamic> status = {};
  String? error;
  bool busy = false;
  bool _disposed = false;
  int _operation = 0;

  bool get available => status['available'] == true;
  bool get registered => status['registered'] == true;
  bool get sessionStarted => status['session'] == 'started';
  bool get streaming => status['stream'] == 'streaming';

  Future<void> initialize() async {
    _subscription ??= service.events.listen(_receive, onError: _onError);
    await run('status');
  }

  void _receive(Map<String, dynamic> value) {
    if (_disposed) return;
    status = value;
    error = value['error'] as String?;
    notifyListeners();
  }

  void _onError(Object value) {
    if (_disposed) return;
    error = value is PlatformException ? value.message : value.toString();
    notifyListeners();
  }

  Future<void> run(String operation) async {
    if (_disposed || (busy && operation != 'stopSession')) return;
    final current = ++_operation;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final result = await service.invoke(operation);
      if (current == _operation) _receive(result);
    } catch (e) {
      if (current == _operation) _onError(e);
    } finally {
      if (!_disposed && current == _operation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    // Native stopSession also invalidates permission requests still in flight.
    unawaited(
      service
          .invoke('stopSession')
          .catchError((Object _) => <String, dynamic>{}),
    );
    super.dispose();
  }
}
