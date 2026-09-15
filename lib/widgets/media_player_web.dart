import 'dart:typed_data';
import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

@JS('verifyMedia.player')
external _Player _player(JSUint8Array bytes, String mimeType);

extension type _Player(JSObject _) implements JSObject {
  external JSObject get element;
  external void dispose();
}

Widget mediaPlayer(Uint8List bytes, String mimeType) =>
    _MediaPlayer(bytes, mimeType);

class _MediaPlayer extends StatefulWidget {
  final Uint8List bytes;
  final String mimeType;
  const _MediaPlayer(this.bytes, this.mimeType);
  @override
  State<_MediaPlayer> createState() => _MediaPlayerState();
}

class _MediaPlayerState extends State<_MediaPlayer> {
  late final _Player player = _player(widget.bytes.toJS, widget.mimeType);
  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
    tagName: 'div',
    onElementCreated: (e) {
      final host = e as web.HTMLElement;
      host.style.width = '100%';
      host.style.height = '100%';
      host.appendChild(player.element as web.Node);
    },
  );
  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}
