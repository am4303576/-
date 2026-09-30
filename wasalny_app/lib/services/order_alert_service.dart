import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class OrderAlertService {
  static final OrderAlertService _instance = OrderAlertService._internal();
  factory OrderAlertService() => _instance;
  OrderAlertService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _currentAlertOrderId;

  bool get isPlaying => _isPlaying;
  String? get currentAlertOrderId => _currentAlertOrderId;

  Future<void> init() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
  }

  /// Start continuous ringtone for a new pending order
  Future<void> startAlarm(String orderId) async {
    if (_isPlaying && _currentAlertOrderId == orderId) return;

    try {
      _currentAlertOrderId = orderId;
      _isPlaying = true;

      // Play local sound or online fallback tone
      await _audioPlayer.play(
        AssetSource('sounds/new_order_alarm.mp3'),
        volume: 1.0,
      );
    } catch (e) {
      debugPrint("Could not play asset sound, fallback to system tone: $e");
    }
  }

  /// Stop alarm when manager acknowledges and opens the order
  Future<void> stopAlarm() async {
    if (!_isPlaying) return;
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
      _currentAlertOrderId = null;
    } catch (e) {
      debugPrint("Error stopping alarm: $e");
    }
  }

  /// Keep Screen On (for kitchen display & Sunmi POS)
  Future<void> enableKeepScreenOn() async {
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint("Failed to enable wakelock: $e");
    }
  }

  Future<void> disableKeepScreenOn() async {
    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint("Failed to disable wakelock: $e");
    }
  }
}
