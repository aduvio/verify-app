class StorageConflict implements Exception {
  const StorageConflict();
  @override
  String toString() =>
      'Another tab saved a newer version. No data was overwritten.';
}

abstract class InspectionStore {
  Future<List<Object?>> readAll();

  /// Compare and replace one complete aggregate in one atomic transaction.
  Future<int> write(
    String id,
    int expectedVersion,
    Map<String, Object?> session,
  );
  void close();
}
