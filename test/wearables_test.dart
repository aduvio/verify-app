import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verify_app/services/wearables_service.dart';
import 'package:verify_app/screens/wearables_test_screen.dart';

class FakeWearables implements WearablesService {
  final updates = StreamController<Map<String, dynamic>>.broadcast();
  final calls = <String>[];
  Future<Map<String, dynamic>> Function(String)? handler;
  Map<String, dynamic> state = {
    'available': true,
    'registered': false,
    'registration': 'Available',
    'session': 'stopped',
    'camera': 'Not requested',
    'stream': 'stopped',
  };
  @override
  Stream<Map<String, dynamic>> get events => updates.stream;
  @override
  Future<Map<String, dynamic>> invoke(String operation) async {
    calls.add(operation);
    return handler == null ? state : await handler!(operation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'iOS adapter sends the requested operation and preserves native status',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        messenger.setMockMethodCallHandler(IOSWearablesService.methods, null);
      });
      final calls = <String>[];
      messenger.setMockMethodCallHandler(IOSWearablesService.methods, (
        call,
      ) async {
        calls.add(call.method);
        return {
          'available': true,
          'registered': false,
          'session': 'stopped',
          'error': 'No eligible glasses',
        };
      });
      final result = await IOSWearablesService().invoke('startSession');
      expect(calls, ['startSession']);
      expect(result['registered'], false);
      expect(result['error'], 'No eligible glasses');
    },
  );

  test(
    'unsupported platform reports unavailable without native operations',
    () async {
      final service = IOSWearablesService();
      final result = await service.invoke('register');
      expect(result['available'], false);
      expect(result['error'], contains('native iOS'));
    },
  );

  test(
    'initialization observes state without registering or capturing',
    () async {
      final fake = FakeWearables();
      final controller = WearablesController(fake);
      await controller.initialize();
      expect(fake.calls, ['status']);
      expect(controller.available, true);
      expect(controller.registered, false);
      fake.updates.add({
        ...fake.state,
        'registered': true,
        'session': 'started',
      });
      await Future<void>.delayed(Duration.zero);
      expect(controller.registered, true);
      expect(controller.sessionStarted, true);
      fake.updates.add({
        ...fake.state,
        'available': false,
        'error': 'Glasses disconnected',
      });
      await Future<void>.delayed(Duration.zero);
      expect(controller.sessionStarted, false);
      expect(controller.error, 'Glasses disconnected');
      controller.dispose();
      await fake.updates.close();
    },
  );

  test(
    'pending operations cannot overlap; stop invalidates late replies',
    () async {
      final fake = FakeWearables();
      final pending = Completer<Map<String, dynamic>>();
      fake.handler = (method) =>
          method == 'requestCamera' ? pending.future : Future.value(fake.state);
      final controller = WearablesController(fake);
      final first = controller.run('requestCamera');
      await controller.run('requestCamera');
      expect(fake.calls, ['requestCamera']);
      await controller.run('stopSession');
      pending.complete({...fake.state, 'session': 'started'});
      await first;
      expect(controller.sessionStarted, false);
      expect(controller.busy, false);
      controller.dispose();
      await fake.updates.close();
    },
  );

  test('native errors unlock controls and remain actionable', () async {
    final fake = FakeWearables();
    fake.handler = (_) => Future.error(
      PlatformException(code: 'denied', message: 'Allow access in Meta AI'),
    );
    final controller = WearablesController(fake);
    await controller.run('requestCamera');
    expect(controller.busy, false);
    expect(controller.error, 'Allow access in Meta AI');
    controller.dispose();
    await fake.updates.close();
  });

  test(
    'dispose during pending action stops session and ignores result',
    () async {
      final fake = FakeWearables();
      final pending = Completer<Map<String, dynamic>>();
      fake.handler = (method) =>
          method == 'register' ? pending.future : Future.value(fake.state);
      final controller = WearablesController(fake);
      var notifications = 0;
      controller.addListener(() => notifications++);
      final operation = controller.run('register');
      controller.dispose();
      final atDispose = notifications;
      pending.complete(fake.state);
      await operation;
      expect(notifications, atDispose);
      expect(fake.calls.last, 'stopSession');
      await fake.updates.close();
    },
  );

  testWidgets(
    'page exposes explicit actions and never automatically starts capture',
    (tester) async {
      final fake = FakeWearables();
      await tester.pumpWidget(
        MaterialApp(home: WearablesTestScreen(service: fake)),
      );
      await tester.pumpAndSettle();
      expect(fake.calls, ['status']);
      expect(find.textContaining('No audio capture'), findsOneWidget);
      ElevatedButton button(String label) => tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, label),
      );
      expect(button('Start glasses session').onPressed, isNull);
      await tester.tap(find.text('Register with Meta AI'));
      await tester.pumpAndSettle();
      expect(fake.calls.last, 'register');
      fake.updates.add({...fake.state, 'registered': true});
      await tester.pumpAndSettle();
      expect(button('Start glasses session').onPressed, isNotNull);
      expect(button('Capture test photo (memory only)').onPressed, isNull);
      fake.updates.add({
        ...fake.state,
        'registered': true,
        'session': 'started',
        'camera': 'started',
        'stream': 'streaming',
      });
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Capture test photo (memory only)'));
      await tester.tap(find.text('Capture test photo (memory only)'));
      await tester.pumpAndSettle();
      expect(fake.calls.last, 'capturePhoto');
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();
      expect(fake.calls.last, 'stopSession');
      expect(tester.takeException(), isNull);
      await fake.updates.close();
    },
  );
}
