import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../models/local_media.dart';
import 'camera_service.dart';

@JS('verifyMedia.createCamera')
external _Camera _create();

extension type _Camera(JSObject _) implements JSObject {
  external JSObject get preview;
  external JSPromise<JSAny?> open(bool audio);
  external JSPromise<_Result> photo();
  external JSPromise<JSAny?> start();
  external JSPromise<_Result> stop();
  external void dispose();
}

extension type _Result(JSObject _) implements JSObject {
  external JSUint8Array get bytes;
  external String get mimeType;
  external int get durationMs;
}

CameraService createCameraService() => BrowserCameraService();

class BrowserCameraService implements CameraService {
  final _Camera _handle = _create();
  @override
  Widget preview() => HtmlElementView.fromTagName(
    tagName: 'div',
    onElementCreated: (e) {
      final host = e as web.HTMLElement;
      host.style.width = '100%';
      host.style.height = '100%';
      host.appendChild(_handle.preview as web.Node);
    },
  );
  @override
  Future<void> open({required bool audio}) async {
    await _handle.open(audio).toDart;
  }

  @override
  Future<void> start() async {
    await _handle.start().toDart;
  }

  CapturedMedia _convert(_Result r) => CapturedMedia(
    bytes: r.bytes.toDart,
    mimeType: r.mimeType,
    duration: Duration(milliseconds: r.durationMs),
    playable: true,
  );
  @override
  Future<CapturedMedia> photo() async => _convert(await _handle.photo().toDart);
  @override
  Future<CapturedMedia> stop() async => _convert(await _handle.stop().toDart);
  @override
  void dispose() => _handle.dispose();
}
