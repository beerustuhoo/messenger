import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceRecorder {
  final _recorder = AudioRecorder();
  String? _path;

  Future<void> dispose() => _recorder.dispose();

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<String?> preparePath() async {
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    return _path;
  }

  Future<void> start(String path) => _recorder.start(const RecordConfig(), path: path);

  Future<List<int>?> stopAndReadBytes() async {
    final path = await _recorder.stop();
    if (path == null) return null;
    return File(path).readAsBytes();
  }
}
