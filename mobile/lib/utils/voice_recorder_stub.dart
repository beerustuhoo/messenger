class VoiceRecorder {
  Future<void> dispose() async {}

  Future<bool> hasPermission() async => false;

  Future<String?> preparePath() async => null;

  Future<void> start(String path) async {}

  Future<List<int>?> stopAndReadBytes() async => null;
}
