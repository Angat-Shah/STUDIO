import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class WatermarkService {
  static final WatermarkService _instance = WatermarkService._internal();
  factory WatermarkService() => _instance;
  WatermarkService._internal();

  bool _isEnabled = true;
  String _username = 'User';
  double _opacity = 0.7;
  Color _textColor = Colors.white;
  double _fontSize = 14.0;
  WatermarkPosition _position = WatermarkPosition.topRight;

  Timer? _updateTimer;
  String _currentTimestamp = '';

  final StreamController<WatermarkData> _watermarkController =
      StreamController<WatermarkData>.broadcast();

  bool get isEnabled => _isEnabled;
  String get username => _username;
  double get opacity => _opacity;
  Color get textColor => _textColor;
  double get fontSize => _fontSize;
  WatermarkPosition get position => _position;
  String get currentTimestamp => _currentTimestamp;
  Stream<WatermarkData> get watermarkStream => _watermarkController.stream;

  Future<void> initialize() async {
    await _loadSettings();
    _updateTimestamp();
    _startTimer();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool('watermark_enabled') ?? true;
      _username = prefs.getString('watermark_username') ?? 'SecurePlayer';
      _opacity = prefs.getDouble('watermark_opacity') ?? 0.7;
      int colorValue = prefs.getInt('watermark_color') ?? Colors.white.value;
      _textColor = Color(colorValue);
      _fontSize = prefs.getDouble('watermark_font_size') ?? 14.0;
      int positionIndex = prefs.getInt('watermark_position') ?? 1;
      _position = WatermarkPosition.values[positionIndex];
    } catch (e) {
      print('Error loading watermark settings: $e');
    }
  }

  void _startTimer() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateTimestamp();
      _broadcastUpdate();
    });
  }

  void _updateTimestamp() {
    final now = DateTime.now();
    _currentTimestamp =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

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

      _broadcastUpdate();
    } catch (e) {
      print('Error updating watermark settings: $e');
    }
  }

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

  double? _getRightPosition(WatermarkPosition position, Size screenSize) {
    switch (position) {
      case WatermarkPosition.topRight:
      case WatermarkPosition.bottomRight:
        return 20;
      default:
        return null;
    }
  }

  void dispose() {
    _updateTimer?.cancel();
    if (!_watermarkController.isClosed) {
      _watermarkController.close();
    }
  }

  String getWatermarkText() {
    _updateTimestamp();
    return '$_username • $_currentTimestamp';
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

enum WatermarkPosition {
  topLeft,
  topCenter,
  topRight,
  center,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

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
