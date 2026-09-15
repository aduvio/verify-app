import 'dart:typed_data';

/// Integrity check for accidental corruption, not a security signature.
String mediaChecksum(List<int> bytes) {
  var hash = 0x811c9dc5;
  for (final byte in bytes) {
    hash ^= byte;
    hash =
        (hash +
            (hash << 1) +
            (hash << 4) +
            (hash << 7) +
            (hash << 8) +
            (hash << 24)) &
        0xffffffff;
  }
  return hash.toRadixString(16);
}

class LocalMedia {
  final String id, inspectionId, stepId, stage, technician, source, mimeType;
  final int revision, byteSize, durationMs;
  final DateTime capturedAt;
  final String checksum;
  const LocalMedia({
    required this.id,
    required this.inspectionId,
    required this.stepId,
    required this.stage,
    required this.technician,
    required this.source,
    required this.mimeType,
    required this.revision,
    required this.byteSize,
    required this.durationMs,
    required this.capturedAt,
    required this.checksum,
  });
  Map<String, Object?> toMap() => {
    'id': id,
    'inspectionId': inspectionId,
    'stepId': stepId,
    'stage': stage,
    'technician': technician,
    'source': source,
    'mimeType': mimeType,
    'revision': revision,
    'byteSize': byteSize,
    'durationMs': durationMs,
    'capturedAt': capturedAt.toIso8601String(),
    'checksum': checksum,
  };
  factory LocalMedia.fromMap(Map v) {
    final m = LocalMedia(
      id: v['id'] as String,
      inspectionId: v['inspectionId'] as String,
      stepId: v['stepId'] as String,
      stage: v['stage'] as String,
      technician: v['technician'] as String,
      source: v['source'] as String,
      mimeType: v['mimeType'] as String,
      revision: v['revision'] as int,
      byteSize: v['byteSize'] as int,
      durationMs: v['durationMs'] as int,
      capturedAt: DateTime.parse(v['capturedAt'] as String),
      checksum: v['checksum'] as String,
    );
    if (m.byteSize <= 0 ||
        m.durationMs < 0 ||
        m.revision < 0 ||
        !{'camera', 'fixture'}.contains(m.source) ||
        !{
          'image/jpeg',
          'image/png',
          'video/webm',
          'video/mp4',
        }.contains(m.mimeType.split(';').first)) {
      throw const FormatException('Invalid local media');
    }
    return m;
  }
  bool matches(Uint8List bytes) =>
      bytes.length == byteSize && mediaChecksum(bytes) == checksum;
}

/// Finalized, browser-decodable payload. Duration comes from the recorded media
/// timeline, never the recording UI timer. Fixtures must identify themselves.
class CapturedMedia {
  final Uint8List bytes;
  final String mimeType, source;
  final Duration duration;
  final bool playable;
  CapturedMedia({
    required this.bytes,
    required this.mimeType,
    required this.duration,
    required this.playable,
    this.source = 'camera',
  });
}
