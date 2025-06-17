import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class VideoService {
  static final VideoService _instance = VideoService._internal();
  factory VideoService() => _instance;
  VideoService._internal();

  ChewieController? _chewieController;
  VideoPlayerController? _videoPlayerController;
  bool _restrictionsEnabled = true;
  double _maxPlaybackSpeed = 2.0;
  int _maxRewindSeconds = 10;
  String? _lastError;
  bool _isInitialized = false;

  ChewieController? get chewieController => _chewieController;
  VideoPlayerController? get currentController => _videoPlayerController;
  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;
  bool get restrictionsEnabled => _restrictionsEnabled;
  double get maxPlaybackSpeed => _maxPlaybackSpeed;
  int get maxRewindSeconds => _maxRewindSeconds;

  Future<void> initialize() async {
    if (!_isInitialized) {
      try {
        await _loadSettings();
        _isInitialized = true;
        print('VideoService: Initialized successfully');
      } catch (e) {
        _lastError = 'Failed to initialize video service: ${e.toString()}';
        _isInitialized = false;
        print('VideoService: Initialization failed: $e');
      }
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _restrictionsEnabled =
          prefs.getBool('playback_restrictions_enabled') ?? true;
      _maxPlaybackSpeed = prefs.getDouble('max_playback_speed') ?? 2.0;
      _maxRewindSeconds = prefs.getInt('max_rewind_seconds') ?? 10;
      print('VideoService: Settings loaded');
    } catch (e) {
      _lastError = 'Failed to load settings: ${e.toString()}';
      print('VideoService: Failed to load settings: $e');
    }
  }

  Future<ChewieController?> createController(File videoFile) async {
    try {
      print('VideoService: Creating controller for file: ${videoFile.path}');
      await disposeController(); // Ensure previous controller is disposed
      if (!videoFile.existsSync()) {
        throw Exception('Video file does not exist');
      }
      int fileSize = await videoFile.length();
      if (fileSize > 2 * 1024 * 1024 * 1024) {
        throw Exception('Video file too large (max 2GB)');
      }

      _videoPlayerController = VideoPlayerController.file(videoFile);
      await _videoPlayerController!.initialize();
      if (!_videoPlayerController!.value.isInitialized) {
        throw Exception('Failed to initialize video player');
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoInitialize: true,
        autoPlay: false,
        looping: false,
        allowMuting: true,
        allowedScreenSleep: false,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              'Error playing video: $errorMessage',
              style: TextStyle(color: Colors.white),
            ),
          );
        },
      );

      final size = _videoPlayerController!.value.size;
      if (size.width > 1920 || size.height > 1080) {
        print(
          'VideoService: Warning: Video resolution ${size.width}x${size.height} may not perform optimally',
        );
      }
      _lastError = null;
      print('VideoService: Controller created successfully');
      return _chewieController;
    } catch (e) {
      _lastError = 'Failed to create video controller: ${e.toString()}';
      print('VideoService: Failed to create controller: $e');
      await disposeController();
      return null;
    }
  }

  Future<void> disposeController() async {
    try {
      if (_chewieController != null) {
        print('VideoService: Disposing Chewie controller');
        _chewieController!.pause();
        _chewieController!.dispose();
        _chewieController = null;
      }
      if (_videoPlayerController != null) {
        print('VideoService: Disposing VideoPlayer controller');
        if (_videoPlayerController!.value.isPlaying) {
          await _videoPlayerController!.pause();
        }
        await _videoPlayerController!.dispose();
        // Add a small delay to ensure native resources are released
        await Future.delayed(Duration(milliseconds: 300));
        print('VideoService: Controller disposed successfully');
      }
    } catch (e) {
      _lastError = 'Error disposing controller: ${e.toString()}';
      print('VideoService: Error disposing controller: $e');
    } finally {
      _videoPlayerController = null;
      _chewieController = null;
    }
  }

  Future<bool> play() async {
    try {
      if (_chewieController == null || !_chewieController!.isPlaying) {
        _chewieController?.play();
        print('VideoService: Playback started');
        return true;
      }
      return false;
    } catch (e) {
      _lastError = 'Failed to play video: ${e.toString()}';
      print('VideoService: Failed to play video: $e');
      return false;
    }
  }

  Future<bool> pause() async {
    try {
      if (_chewieController == null || _chewieController!.isPlaying) {
        _chewieController?.pause();
        print('VideoService: Playback paused');
        return true;
      }
      return false;
    } catch (e) {
      _lastError = 'Failed to pause video: ${e.toString()}';
      print('VideoService: Failed to pause video: $e');
      return false;
    }
  }

  Future<bool> seekTo(Duration position) async {
    try {
      if (_videoPlayerController == null ||
          !_videoPlayerController!.value.isInitialized) {
        throw Exception('Video controller not initialized');
      }
      final duration = _videoPlayerController!.value.duration;
      Duration clampedPosition = position;
      if (position < Duration.zero) {
        clampedPosition = Duration.zero;
      } else if (position > duration) {
        clampedPosition = duration;
      }
      await _videoPlayerController!.seekTo(clampedPosition);
      print('VideoService: Seek to $clampedPosition');
      return true;
    } catch (e) {
      _lastError = 'Failed to seek: ${e.toString()}';
      print('VideoService: Failed to seek: $e');
      return false;
    }
  }

  Future<bool> setPlaybackSpeed(double speed) async {
    try {
      if (_videoPlayerController == null ||
          !_videoPlayerController!.value.isInitialized) {
        throw Exception('Video controller not initialized');
      }
      double finalSpeed = speed;
      if (_restrictionsEnabled) {
        if (speed > _maxPlaybackSpeed) {
          finalSpeed = _maxPlaybackSpeed;
        } else if (speed < 0.25) {
          finalSpeed = 0.25;
        }
      }
      await _videoPlayerController!.setPlaybackSpeed(finalSpeed);
      print('VideoService: Playback speed set to $finalSpeed');
      return true;
    } catch (e) {
      _lastError = 'Failed to set playback speed: ${e.toString()}';
      print('VideoService: Failed to set playback speed: $e');
      return false;
    }
  }

  Future<bool> setVolume(double volume) async {
    try {
      if (_videoPlayerController == null ||
          !_videoPlayerController!.value.isInitialized) {
        throw Exception('Video controller not initialized');
      }
      double clampedVolume = volume.clamp(0.0, 1.0);
      await _videoPlayerController!.setVolume(clampedVolume);
      print('VideoService: Volume set to $clampedVolume');
      return true;
    } catch (e) {
      _lastError = 'Failed to set volume: ${e.toString()}';
      print('VideoService: Failed to set volume: $e');
      return false;
    }
  }

  Future<bool> rewind({int seconds = 10}) async {
    try {
      if (_videoPlayerController == null ||
          !_videoPlayerController!.value.isInitialized) {
        throw Exception('Video controller not initialized');
      }
      int rewindSeconds = seconds;
      if (_restrictionsEnabled && seconds > _maxRewindSeconds) {
        rewindSeconds = _maxRewindSeconds;
      }
      final currentPosition = _videoPlayerController!.value.position;
      final newPosition = currentPosition - Duration(seconds: rewindSeconds);
      return await seekTo(newPosition);
    } catch (e) {
      _lastError = 'Failed to rewind: ${e.toString()}';
      print('VideoService: Failed to rewind: $e');
      return false;
    }
  }

  Future<bool> fastForward({int seconds = 10}) async {
    try {
      if (_videoPlayerController == null ||
          !_videoPlayerController!.value.isInitialized) {
        throw Exception('Video controller not initialized');
      }
      final currentPosition = _videoPlayerController!.value.position;
      final newPosition = currentPosition + Duration(seconds: seconds);
      return await seekTo(newPosition);
    } catch (e) {
      _lastError = 'Failed to fast forward: ${e.toString()}';
      print('VideoService: Failed to fast forward: $e');
      return false;
    }
  }

  Map<String, dynamic> getVideoInfo() {
    if (_videoPlayerController == null ||
        !_videoPlayerController!.value.isInitialized) {
      return {'error': 'Video controller not initialized'};
    }
    final value = _videoPlayerController!.value;
    return {
      'duration': value.duration.inMilliseconds,
      'position': value.position.inMilliseconds,
      'isPlaying': value.isPlaying,
      'isBuffering': value.isBuffering,
      'volume': value.volume,
      'playbackSpeed': value.playbackSpeed,
      'size': {'width': value.size.width, 'height': value.size.height},
      'aspectRatio': value.aspectRatio,
      'hasError': value.hasError,
      'errorDescription': value.errorDescription,
    };
  }

  static bool isSupportedFormat(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    const supportedFormats = ['mp4', 'avi', 'mov', 'mkv', 'wmv', 'flv', 'm4v'];
    return supportedFormats.contains(extension);
  }

  static String getReadableFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Future<void> updateSettings({
    bool? restrictionsEnabled,
    double? maxPlaybackSpeed,
    int? maxRewindSeconds,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (restrictionsEnabled != null) {
        _restrictionsEnabled = restrictionsEnabled;
        await prefs.setBool(
          'playback_restrictions_enabled',
          restrictionsEnabled,
        );
      }
      if (maxPlaybackSpeed != null) {
        _maxPlaybackSpeed = maxPlaybackSpeed;
        await prefs.setDouble('max_playback_speed', maxPlaybackSpeed);
      }
      if (maxRewindSeconds != null) {
        _maxRewindSeconds = maxRewindSeconds;
        await prefs.setInt('max_rewind_seconds', maxRewindSeconds);
      }
      print('VideoService: Settings updated');
    } catch (e) {
      _lastError = 'Failed to update settings: ${e.toString()}';
      print('VideoService: Failed to update settings: $e');
    }
  }

  Future<Map<String, dynamic>> validateVideoFile(File videoFile) async {
    try {
      if (!videoFile.existsSync()) {
        return {'valid': false, 'error': 'File does not exist'};
      }
      int fileSize = await videoFile.length();
      if (fileSize == 0) {
        return {'valid': false, 'error': 'File is empty'};
      }
      if (fileSize > 2 * 1024 * 1024 * 1024) {
        return {'valid': false, 'error': 'File too large (max 2GB)'};
      }
      if (!isSupportedFormat(videoFile.path)) {
        return {'valid': false, 'error': 'Unsupported file format'};
      }
      return {
        'valid': true,
        'fileSize': fileSize,
        'readableSize': getReadableFileSize(fileSize),
        'format': videoFile.path.split('.').last.toUpperCase(),
      };
    } catch (e) {
      return {'valid': false, 'error': 'Validation failed: ${e.toString()}'};
    }
  }

  Future<void> cleanup() async {
    await disposeController();
    _lastError = null;
    _isInitialized = false;
    print('VideoService: Cleanup completed');
  }

  Future<void> reset() async {
    print('VideoService: Resetting state');
    await disposeController();
    _videoPlayerController = null;
    _chewieController = null;
    _lastError = null;
    _isInitialized = false;
    await initialize(); // Reinitialize to ensure a clean state
    print('VideoService: Reset completed');
  }
}
