import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class WatermarkService {
  static final WatermarkService _instance = WatermarkService._internal();
  factory WatermarkService() => _instance;
  WatermarkService._internal();

  // Watermark configuration
  bool _isEnabled = true;
  String _username = 'User';
  double _opacity = 0.7;
  Color _textColor = Colors.white;
  double _fontSize = 14.0;
  WatermarkPosition _position = WatermarkPosition.topRight;

  // Update timer
  Timer? _updateTimer;
  String _currentTimestamp = '';

  // Stream controller for watermark updates
  final StreamController<WatermarkData> _watermarkController =
      StreamController<WatermarkData>.broadcast();

  // Getters
  bool get isEnabled => _isEnabled;
  String get username => _username;
  double get opacity => _opacity;
  Color get textColor => _textColor;
  double get fontSize => _fontSize;
  WatermarkPosition get position => _position;
  String get currentTimestamp => _currentTimestamp;
  Stream<WatermarkData> get watermarkStream => _watermarkController.stream;

  /// Initialize watermark service
  Future<void> initialize() async {
    await _loadSettings();
    _updateTimestamp();
    _startTimer();
  }

  /// Load watermark settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool('watermark_enabled') ?? true;
      _username = prefs.getString('watermark_username') ?? 'User';
      _opacity = prefs.getDouble('watermark_opacity') ?? 0.7;

      // Load color from stored RGB values
      int colorValue = prefs.getInt('watermark_color') ?? Colors.white.value;
      _textColor = Color(colorValue);

      _fontSize = prefs.getDouble('watermark_font_size') ?? 14.0;

      // Load position from stored index
      int positionIndex = prefs.getInt('watermark_position') ?? 1;
      _position = WatermarkPosition.values[positionIndex];
    } catch (e) {
      print('Error loading watermark settings: $e');
    }
  }

  /// Start the 30-second update timer
  void _startTimer() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateTimestamp();
      _broadcastUpdate();
    });
  }

  /// Update the current timestamp
  void _updateTimestamp() {
    final now = DateTime.now();
    _currentTimestamp =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  /// Broadcast watermark update to listeners
  void _broadcastUpdate() {
    if (!_watermarkController.isClosed) {
      _watermarkController.add(
        WatermarkData(
          text: '$_username\n$_currentTimestamp',
          opacity: _opacity,
          color: _textColor,
          fontSize: _fontSize,
          position: _position,
          isEnabled: _isEnabled,
        ),
      );
    }
  }

  /// Get current watermark data
  WatermarkData getCurrentWatermarkData() {
    _updateTimestamp();
    return WatermarkData(
      text: '$_username\n$_currentTimestamp',
      opacity: _opacity,
      color: _textColor,
      fontSize: _fontSize,
      position: _position,
      isEnabled: _isEnabled,
    );
  }

  /// Update watermark settings
  Future<void> updateSettings({
    bool? enabled,
    String? username,
    double? opacity,
    Color? textColor,
    double? fontSize,
    WatermarkPosition? position,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (enabled != null) {
        _isEnabled = enabled;
        await prefs.setBool('watermark_enabled', enabled);
      }

      if (username != null && username.isNotEmpty) {
        _username = username;
        await prefs.setString('watermark_username', username);
      }

      if (opacity != null) {
        _opacity = opacity.clamp(0.0, 1.0);
        await prefs.setDouble('watermark_opacity', _opacity);
      }

      if (textColor != null) {
        _textColor = textColor;
        await prefs.setInt('watermark_color', textColor.value);
      }

      if (fontSize != null) {
        _fontSize = fontSize.clamp(8.0, 24.0);
        await prefs.setDouble('watermark_font_size', _fontSize);
      }

      if (position != null) {
        _position = position;
        await prefs.setInt('watermark_position', position.index);
      }

      // Broadcast the update immediately
      _broadcastUpdate();
    } catch (e) {
      print('Error updating watermark settings: $e');
    }
  }

  /// Build watermark widget
  Widget buildWatermarkWidget(BuildContext context, Size screenSize) {
    if (!_isEnabled) return const SizedBox.shrink();

    return StreamBuilder<WatermarkData>(
      stream: watermarkStream,
      initialData: getCurrentWatermarkData(),
      builder: (context, snapshot) {
        final data = snapshot.data!;
        if (!data.isEnabled) return const SizedBox.shrink();

        return Positioned(
          top: _getTopPosition(data.position, screenSize),
          bottom: _getBottomPosition(data.position, screenSize),
          left: _getLeftPosition(data.position, screenSize),
          right: _getRightPosition(data.position, screenSize),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              data.text,
              style: TextStyle(
                color: data.color.withOpacity(data.opacity),
                fontSize: data.fontSize,
                fontWeight: FontWeight.w500,
                shadows: [
                  Shadow(
                    offset: const Offset(1, 1),
                    blurRadius: 2,
                    color: Colors.black.withOpacity(0.8),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }

  /// Calculate top position based on watermark position
  double? _getTopPosition(WatermarkPosition position, Size screenSize) {
    switch (position) {
      case WatermarkPosition.topLeft:
      case WatermarkPosition.topCenter:
      case WatermarkPosition.topRight:
        return 20;
      case WatermarkPosition.center:
        return (screenSize.height - 60) / 2;
      default:
        return null;
    }
  }

  /// Calculate bottom position based on watermark position
  double? _getBottomPosition(WatermarkPosition position, Size screenSize) {
    switch (position) {
      case WatermarkPosition.bottomLeft:
      case WatermarkPosition.bottomCenter:
      case WatermarkPosition.bottomRight:
        return 20;
      default:
        return null;
    }
  }

  /// Calculate left position based on watermark position
  double? _getLeftPosition(WatermarkPosition position, Size screenSize) {
    switch (position) {
      case WatermarkPosition.topLeft:
      case WatermarkPosition.bottomLeft:
        return 20;
      case WatermarkPosition.topCenter:
      case WatermarkPosition.center:
      case WatermarkPosition.bottomCenter:
        return (screenSize.width - 120) / 2;
      default:
        return null;
    }
  }

  /// Calculate right position based on watermark position
  double? _getRightPosition(WatermarkPosition position, Size screenSize) {
    switch (position) {
      case WatermarkPosition.topRight:
      case WatermarkPosition.bottomRight:
        return 20;
      default:
        return null;
    }
  }

  /// Dispose resources
  void dispose() {
    _updateTimer?.cancel();
    _watermarkController.close();
  }

  String getWatermarkText() {
    final now = DateTime.now();
    return 'User • ${now.toString().substring(0, 19)}';
  }

  Widget buildWatermark(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        getWatermarkText(),
        style: TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Watermark position enum
enum WatermarkPosition {
  topLeft,
  topCenter,
  topRight,
  center,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

/// Extension for watermark position display names
extension WatermarkPositionExtension on WatermarkPosition {
  String get displayName {
    switch (this) {
      case WatermarkPosition.topLeft:
        return 'Top Left';
      case WatermarkPosition.topCenter:
        return 'Top Center';
      case WatermarkPosition.topRight:
        return 'Top Right';
      case WatermarkPosition.center:
        return 'Center';
      case WatermarkPosition.bottomLeft:
        return 'Bottom Left';
      case WatermarkPosition.bottomCenter:
        return 'Bottom Center';
      case WatermarkPosition.bottomRight:
        return 'Bottom Right';
    }
  }
}

/// Watermark data class
class WatermarkData {
  final String text;
  final double opacity;
  final Color color;
  final double fontSize;
  final WatermarkPosition position;
  final bool isEnabled;

  const WatermarkData({
    required this.text,
    required this.opacity,
    required this.color,
    required this.fontSize,
    required this.position,
    required this.isEnabled,
  });
}
