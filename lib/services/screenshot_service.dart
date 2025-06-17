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
  bool _preventScreenshots = true; // Re-enable secure overlay

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
    print('ScreenshotService: Initializing');
    await _loadSettings();
    await _setupPlatformChannel();
    await _loadAttemptHistory();

    if (_detectionEnabled) {
      await startMonitoring();
    }

    if (_preventScreenshots && Platform.isIOS) {
      await enableSecureOverlay();
    }
    print('ScreenshotService: Initialization completed');
  }

  Future<void> enableSecureOverlay() async {
    try {
      print('ScreenshotService: Enabling secure overlay');
      await _channel.invokeMethod('enableSecureOverlay');
      print('ScreenshotService: Secure overlay enabled');
    } catch (e) {
      print('ScreenshotService: Error enabling secure overlay: $e');
    }
  }

  Future<void> disableSecureOverlay() async {
    try {
      print('ScreenshotService: Disabling secure overlay');
      await _channel.invokeMethod('disableSecureOverlay');
      print('ScreenshotService: Secure overlay disabled');
    } catch (e) {
      print('ScreenshotService: Error disabling secure overlay: $e');
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
      print('ScreenshotService: Settings loaded');
    } catch (e) {
      print('ScreenshotService: Error loading settings: $e');
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
      print('ScreenshotService: Attempt history saved');
    } catch (e) {
      print('ScreenshotService: Error saving attempt history: $e');
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
      print('ScreenshotService: Attempt history loaded');
    } catch (e) {
      print('ScreenshotService: Error loading attempt history: $e');
      _attempts = [];
    }
  }

  Future<void> _setupPlatformChannel() async {
    try {
      _channel.setMethodCallHandler(_handleMethodCall);
      print('ScreenshotService: Platform channel set up');
    } catch (e) {
      print('ScreenshotService: Error setting up platform channel: $e');
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onScreenshotDetected':
        await _handleScreenshotDetected();
        break;
      default:
        print('ScreenshotService: Unknown method call: ${call.method}');
    }
  }

  Future<void> startMonitoring() async {
    try {
      if (_detectionEnabled) {
        await _channel.invokeMethod('startDetection');
        print('ScreenshotService: Monitoring started');
      }
    } catch (e) {
      print('ScreenshotService: Error starting monitoring: $e');
    }
  }

  Future<void> stopMonitoring() async {
    try {
      await _channel.invokeMethod('stopDetection');
      print('ScreenshotService: Monitoring stopped');
    } catch (e) {
      print('ScreenshotService: Error stopping monitoring: $e');
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

    if (_onScreenshotDetected != null) {
      _onScreenshotDetected!();
    }
    print(
      'ScreenshotService: Screenshot detected and logged: ${attempt.timestamp}',
    );
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
        if (Platform.isIOS) {
          if (_preventScreenshots) {
            await enableSecureOverlay();
          } else {
            await disableSecureOverlay();
          }
        }
      }
      print('ScreenshotService: Settings updated');
    } catch (e) {
      print('ScreenshotService: Error updating settings: $e');
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
      print('ScreenshotService: History cleared');
    } catch (e) {
      print('ScreenshotService: Error clearing history: $e');
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
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1C1C1E).withOpacity(0.95)
                  : Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Color(0xFFFF3B30),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Content Protected',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF1D1D1F),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'This content is protected from screenshots and screen recording to maintain privacy and security.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF8E8E93)
                        : const Color(0xFF6D6D70),
                    height: 1.4,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.of(context).pop(),
                      child: const Center(
                        child: Text(
                          'I Understand',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> dispose() async {
    print('ScreenshotService: Disposing');
    await stopMonitoring();
    if (Platform.isIOS) {
      await disableSecureOverlay();
    }
    if (!_screenshotController.isClosed) {
      _screenshotController.close();
    }
    print('ScreenshotService: Dispose completed');
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
