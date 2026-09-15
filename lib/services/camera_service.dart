import 'package:flutter/widgets.dart';

import '../models/local_media.dart';

abstract class CameraService {
  Widget preview();
  Future<void> open({required bool audio});
  Future<CapturedMedia> photo();
  Future<void> start();
  Future<CapturedMedia> stop();
  void dispose();
}
