import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class VideoService {
  static final VideoService _instance = VideoService._internal();
  factory VideoService() => _instance;
  VideoService._internal();

  // Video player controller management
  VideoPlayerController? _currentController;

  // Playback restrictions
  bool _restrictionsEnabled = true;
  double _maxPlaybackSpeed = 2.0;
  int _maxRewindSeconds = 10;

  // Error handling
  String? _lastError;

  // Initialization status
  bool _isInitialized = false;

  // Getters
  VideoPlayerController? get currentController => _currentController;
  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;
  bool get restrictionsEnabled => _restrictionsEnabled;
  double get maxPlaybackSpeed => _maxPlaybackSpeed;
  int get maxRewindSeconds => _maxRewindSeconds;

  /// Initialize video service with settings
  Future<void> initialize() async {
    try {
      await _loadSettings();
      _isInitialized = true;
    } catch (e) {
      _lastError = 'Failed to initialize video service: ${e.toString()}';
      _isInitialized = false;
    }
  }

  /// Load playback settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _restrictionsEnabled =
          prefs.getBool('playback_restrictions_enabled') ?? true;
      _maxPlaybackSpeed = prefs.getDouble('max_playback_speed') ?? 2.0;
      _maxRewindSeconds = prefs.getInt('max_rewind_seconds') ?? 10;
    } catch (e) {
      _lastError = 'Failed to load settings: ${e.toString()}';
    }
  }

  /// Create and initialize video player controller
  Future<VideoPlayerController?> createController(File videoFile) async {
    try {
      // Dispose previous controller if exists
      await disposeController();

      // Validate video file
      if (!videoFile.existsSync()) {
        throw Exception('Video file does not exist');
      }

      // Check file size (limit to 2GB for safety)
      int fileSize = await videoFile.length();
      if (fileSize > 2 * 1024 * 1024 * 1024) {
        throw Exception('Video file too large (max 2GB)');
      }

      // Create controller
      _currentController = VideoPlayerController.file(videoFile);

      // Initialize controller
      await _currentController!.initialize();

      // Verify video properties
      if (!_currentController!.value.isInitialized) {
        throw Exception('Failed to initialize video player');
      }

      // Check video resolution support (max 1080p)
      final size = _currentController!.value.size;
      if (size.width > 1920 || size.height > 1080) {
        print(
          'Warning: Video resolution ${size.width}x${size.height} may not perform optimally',
        );
      }

      _lastError = null;
      return _currentController;
    } catch (e) {
      _lastError = 'Failed to create video controller: ${e.toString()}';
      await disposeController();
      return null;
    }
  }

  /// Dispose current video controller
  Future<void> disposeController() async {
    try {
      if (_currentController != null) {
        await _currentController!.dispose();
        _currentController = null;
      }
    } catch (e) {
      _lastError = 'Error disposing controller: ${e.toString()}';
    }
  }

  /// Play video with restrictions
  Future<bool> play() async {
    try {
      if (_currentController == null ||
          !_currentController!.value.isInitialized) {
        throw Exception('Video controller not initialized');
      }

      await _currentController!.play();
      return true;
    } catch (e) {
      _lastError = 'Failed to play video: ${e.toString()}';
      return false;
    }
  }

  /// Pause video
  Future<bool> pause() async {
    try {
      if (_currentController == null ||
          !_currentController!.value.isInitialized) {
        throw Exception('Video controller not initialized');
      }

      await _currentController!.pause();
      return true;
    } catch (e) {
      _lastError = 'Failed to pause video: ${e.toString()}';
      return false;
    }
  }

  /// Seek to position with restrictions
  Future<bool> seekTo(Duration position) async {
    try {
      if (_currentController == null ||
          !_currentController!.value.isInitialized) {
        throw Exception('Video controller not initialized');
      }

      final duration = _currentController!.value.duration;

      // Clamp position to valid range
      Duration clampedPosition = position;
      if (position < Duration.zero) {
        clampedPosition = Duration.zero;
      } else if (position > duration) {
        clampedPosition = duration;
      }

      await _currentController!.seekTo(clampedPosition);
      return true;
    } catch (e) {
      _lastError = 'Failed to seek: ${e.toString()}';
      return false;
    }
  }

  /// Set playback speed with restrictions
  Future<bool> setPlaybackSpeed(double speed) async {
    try {
      if (_currentController == null ||
          !_currentController!.value.isInitialized) {
        throw Exception('Video controller not initialized');
      }

      // Apply restrictions if enabled
      double finalSpeed = speed;
      if (_restrictionsEnabled) {
        if (speed > _maxPlaybackSpeed) {
          finalSpeed = _maxPlaybackSpeed;
        } else if (speed < 0.25) {
          finalSpeed = 0.25; // Minimum speed
        }
      }

      await _currentController!.setPlaybackSpeed(finalSpeed);
      return true;
    } catch (e) {
      _lastError = 'Failed to set playback speed: ${e.toString()}';
      return false;
    }
  }

  /// Set volume
  Future<bool> setVolume(double volume) async {
    try {
      if (_currentController == null ||
          !_currentController!.value.isInitialized) {
        throw Exception('Video controller not initialized');
      }

      // Clamp volume to valid range
      double clampedVolume = volume.clamp(0.0, 1.0);

      await _currentController!.setVolume(clampedVolume);
      return true;
    } catch (e) {
      _lastError = 'Failed to set volume: ${e.toString()}';
      return false;
    }
  }

  /// Rewind with restrictions
  Future<bool> rewind({int seconds = 10}) async {
    try {
      if (_currentController == null ||
          !_currentController!.value.isInitialized) {
        throw Exception('Video controller not initialized');
      }

      // Apply restrictions if enabled
      int rewindSeconds = seconds;
      if (_restrictionsEnabled && seconds > _maxRewindSeconds) {
        rewindSeconds = _maxRewindSeconds;
      }

      final currentPosition = _currentController!.value.position;
      final newPosition = currentPosition - Duration(seconds: rewindSeconds);

      return await seekTo(newPosition);
    } catch (e) {
      _lastError = 'Failed to rewind: ${e.toString()}';
      return false;
    }
  }

  /// Fast forward
  Future<bool> fastForward({int seconds = 10}) async {
    try {
      if (_currentController == null ||
          !_currentController!.value.isInitialized) {
        throw Exception('Video controller not initialized');
      }

      final currentPosition = _currentController!.value.position;
      final newPosition = currentPosition + Duration(seconds: seconds);

      return await seekTo(newPosition);
    } catch (e) {
      _lastError = 'Failed to fast forward: ${e.toString()}';
      return false;
    }
  }

  /// Get video information
  Map<String, dynamic> getVideoInfo() {
    if (_currentController == null ||
        !_currentController!.value.isInitialized) {
      return {'error': 'Video controller not initialized'};
    }

    final value = _currentController!.value;
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

  /// Check if video format is supported
  static bool isSupportedFormat(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    const supportedFormats = ['mp4', 'avi', 'mov', 'mkv', 'wmv', 'flv', 'm4v'];
    return supportedFormats.contains(extension);
  }

  /// Get readable file size
  static String getReadableFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Format duration to readable string
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

  /// Update settings and reload configuration
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
    } catch (e) {
      _lastError = 'Failed to update settings: ${e.toString()}';
    }
  }

  /// Validate video file before playing
  Future<Map<String, dynamic>> validateVideoFile(File videoFile) async {
    try {
      // Check if file exists
      if (!videoFile.existsSync()) {
        return {'valid': false, 'error': 'File does not exist'};
      }

      // Check file size
      int fileSize = await videoFile.length();
      if (fileSize == 0) {
        return {'valid': false, 'error': 'File is empty'};
      }

      if (fileSize > 2 * 1024 * 1024 * 1024) {
        return {'valid': false, 'error': 'File too large (max 2GB)'};
      }

      // Check file format
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

  /// Clean up resources
  Future<void> cleanup() async {
    await disposeController();
    _lastError = null;
    _isInitialized = false;
  }
}