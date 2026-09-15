import 'dart:typed_data';

abstract interface class MediaStore {
  Future<int> writeWithMedia(
    String id,
    int expectedVersion,
    Map<String, Object?> session,
    Map<String, Uint8List> media,
  );
  Future<Uint8List?> readMedia(String inspectionId, String attemptId);
}
