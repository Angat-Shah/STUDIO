import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class ScreenshotService {
  static final ScreenshotService _instance = ScreenshotService._internal();
  factory ScreenshotService() => _instance;
  ScreenshotService._internal();

  static const MethodChannel _channel = MethodChannel('screenshot_detector');

  bool _detectionEnabled = true;
  bool _pauseOnScreenshot = true;
  bool _showWarningDialog = true;
  bool _preventScreenshots = true;

  List<ScreenshotAttempt> _attempts = [];
  int _totalAttempts = 0;

  final StreamController<ScreenshotEvent> _screenshotController =
      StreamController<ScreenshotEvent>.broadcast();

  Function? _onScreenshotDetected;
  Function? _onObstructScreen;

  bool get detectionEnabled => _detectionEnabled;
  bool get pauseOnScreenshot => _pauseOnScreenshot;
  bool get showWarningDialog => _showWarningDialog;
  bool get preventScreenshots => _preventScreenshots;
  List<ScreenshotAttempt> get attempts => List.unmodifiable(_attempts);
  int get totalAttempts => _totalAttempts;
  Stream<ScreenshotEvent> get screenshotStream => _screenshotController.stream;

  Future<void> initialize() async {
    await _loadSettings();
    await _setupPlatformChannel();
    await _loadAttemptHistory();

    if (_detectionEnabled) {
      await startMonitoring();
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _detectionEnabled = prefs.getBool('screenshot_detection_enabled') ?? true;
      _pauseOnScreenshot = prefs.getBool('screenshot_pause_enabled') ?? true;
      _showWarningDialog = prefs.getBool('screenshot_warning_enabled') ?? true;
      _preventScreenshots = prefs.getBool('screenshot_prevent_enabled') ?? true;
      _totalAttempts = prefs.getInt('screenshot_total_attempts') ?? 0;
    } catch (e) {
      print('Error loading screenshot settings: $e');
    }
  }

  Future<void> _saveAttemptHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final attemptsJson = _attempts.map((attempt) {
        return '${attempt.timestamp.toIso8601String()}|${attempt.videoFile}|${attempt.position}';
      }).toList();

      await prefs.setStringList('screenshot_attempts', attemptsJson);
      await prefs.setInt('screenshot_total_attempts', _totalAttempts);
    } catch (e) {
      print('Error saving screenshot attempt history: $e');
    }
  }

  Future<void> _loadAttemptHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final attemptsJson = prefs.getStringList('screenshot_attempts') ?? [];
      _attempts = attemptsJson.map((entry) {
        final parts = entry.split('|');
        if (parts.length == 3) {
          return ScreenshotAttempt(
            timestamp: DateTime.tryParse(parts[0]) ?? DateTime.now(),
            videoFile: parts[1],
            position: parts[2],
          );
        } else {
          return ScreenshotAttempt(
            timestamp: DateTime.now(),
            videoFile: 'Unknown',
            position: 'Unknown',
          );
        }
      }).toList();
    } catch (e) {
      print('Error loading screenshot attempt history: $e');
      _attempts = [];
    }
  }

  Future<void> _setupPlatformChannel() async {
    try {
      _channel.setMethodCallHandler(_handleMethodCall);
    } catch (e) {
      print('Error setting up platform channel: $e');
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onScreenshotDetected':
        await _handleScreenshotDetected();
        break;
      default:
        print('Unknown method call: ${call.method}');
    }
  }

  Future<void> startMonitoring() async {
    try {
      if (_detectionEnabled) {
        await _channel.invokeMethod('startDetection');
      }
    } catch (e) {
      print('Error starting screenshot detection: $e');
    }
  }

  Future<void> stopMonitoring() async {
    try {
      await _channel.invokeMethod('stopDetection');
    } catch (e) {
      print('Error stopping screenshot detection: $e');
    }
  }

  Future<void> _handleScreenshotDetected() async {
    if (!_detectionEnabled) return;

    final attempt = ScreenshotAttempt(
      timestamp: DateTime.now(),
      videoFile: 'Current Video',
      position: 'Unknown',
    );

    _attempts.add(attempt);
    _totalAttempts++;
    await _saveAttemptHistory();

    final event = ScreenshotEvent(
      attempt: attempt,
      shouldPause: _pauseOnScreenshot,
      shouldShowWarning: _showWarningDialog,
    );

    if (!_screenshotController.isClosed) {
      _screenshotController.add(event);
    }

    if (Platform.isIOS && _preventScreenshots && _onObstructScreen != null) {
      _onObstructScreen!();
    }

    if (_onScreenshotDetected != null) {
      _onScreenshotDetected!();
    }
    print('Screenshot detected and logged: ${attempt.timestamp}');
  }

  void setOnScreenshotDetected(Function callback) {
    _onScreenshotDetected = callback;
  }

  void setOnObstructScreen(Function callback) {
    _onObstructScreen = callback;
  }

  Future<void> updateSettings({
    bool? detectionEnabled,
    bool? pauseOnScreenshot,
    bool? showWarningDialog,
    bool? preventScreenshots,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (detectionEnabled != null) {
        _detectionEnabled = detectionEnabled;
        await prefs.setBool('screenshot_detection_enabled', detectionEnabled);
        if (detectionEnabled) {
          await startMonitoring();
        } else {
          await stopMonitoring();
        }
      }

      if (pauseOnScreenshot != null) {
        _pauseOnScreenshot = pauseOnScreenshot;
        await prefs.setBool('screenshot_pause_enabled', pauseOnScreenshot);
      }

      if (showWarningDialog != null) {
        _showWarningDialog = showWarningDialog;
        await prefs.setBool('screenshot_warning_enabled', showWarningDialog);
      }

      if (preventScreenshots != null) {
        _preventScreenshots = preventScreenshots;
        await prefs.setBool('screenshot_prevent_enabled', preventScreenshots);
      }
    } catch (e) {
      print('Error updating screenshot settings: $e');
    }
  }

  Future<void> triggerScreenshotDetection({
    String? videoFile,
    String? position,
  }) async {
    final attempt = ScreenshotAttempt(
      timestamp: DateTime.now(),
      videoFile: videoFile ?? 'Test Video',
      position: position ?? 'Test Position',
    );

    _attempts.add(attempt);
    _totalAttempts++;
    await _saveAttemptHistory();

    final event = ScreenshotEvent(
      attempt: attempt,
      shouldPause: _pauseOnScreenshot,
      shouldShowWarning: _showWarningDialog,
    );

    if (!_screenshotController.isClosed) {
      _screenshotController.add(event);
    }
  }

  Future<void> clearHistory() async {
    try {
      _attempts.clear();
      _totalAttempts = 0;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('screenshot_attempts');
      await prefs.setInt('screenshot_total_attempts', 0);
    } catch (e) {
      print('Error clearing screenshot history: $e');
    }
  }

  List<ScreenshotAttempt> getAttemptsForDate(DateTime date) {
    return _attempts.where((attempt) {
      return attempt.timestamp.year == date.year &&
          attempt.timestamp.month == date.month &&
          attempt.timestamp.day == date.day;
    }).toList();
  }

  int getAttemptsCountForLastDays(int days) {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    return _attempts
        .where((attempt) => attempt.timestamp.isAfter(cutoffDate))
        .length;
  }

  static Future<void> showScreenshotWarningDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(Icons.security, color: Colors.red, size: 48),
          title: const Text(
            'Screenshot Blocked',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
          content: const Text(
            'Screenshots are blocked while watching this video for security reasons.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('I Understand'),
            ),
          ],
        );
      },
    );
  }
}

class ScreenshotAttempt {
  final DateTime timestamp;
  final String videoFile;
  final String position;

  const ScreenshotAttempt({
    required this.timestamp,
    required this.videoFile,
    required this.position,
  });

  String get formattedTimestamp {
    return '${timestamp.day.toString().padLeft(2, '0')}/'
        '${timestamp.month.toString().padLeft(2, '0')}/'
        '${timestamp.year} '
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }
}

class ScreenshotEvent {
  final ScreenshotAttempt attempt;
  final bool shouldPause;
  final bool shouldShowWarning;

  const ScreenshotEvent({
    required this.attempt,
    required this.shouldPause,
    required this.shouldShowWarning,
  });
}
