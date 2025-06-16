import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'dart:async';
import '../services/video_service.dart';
import '../services/watermark_service.dart';
import '../services/screenshot_service.dart';

class PlayerScreen extends StatefulWidget {
  final File videoFile;

  const PlayerScreen({super.key, required this.videoFile});

  @override
  _PlayerScreenState createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  VideoPlayerController? _controller;
  VideoService? _videoService;
  WatermarkService? _watermarkService;
  ScreenshotService? _screenshotService;

  bool _isControlsVisible = true;
  bool _isFullscreen = false;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showObstructionOverlay = false;

  Timer? _hideControlsTimer;
  Timer? _positionTimer;
  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsAnimation;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _initializeAnimations();
    _initializeVideoPlayer();
  }

  void _initializeServices() {
    _videoService = VideoService();
    _watermarkService = WatermarkService();
    _screenshotService = ScreenshotService();

    _screenshotService!.setOnScreenshotDetected(_handleScreenshotDetected);
    _screenshotService!.setOnObstructScreen(_handleObstructScreen);
    _screenshotService!.initialize();
  }

  void _initializeAnimations() {
    _controlsAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _controlsAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controlsAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _controlsAnimationController.forward();
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      _controller = VideoPlayerController.file(widget.videoFile);
      await _controller!.initialize();

      setState(() {
        _duration = _controller!.value.duration;
        _isLoading = false;
      });

      _positionTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
        if (_controller != null && _controller!.value.isInitialized) {
          setState(() {
            _position = _controller!.value.position;
          });
        }
      });

      _startHideControlsTimer();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Error loading video: ${e.toString()}';
      });
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isControlsVisible = false);
        _controlsAnimationController.reverse();
      }
    });
  }

  void _toggleControls() {
    setState(() => _isControlsVisible = !_isControlsVisible);
    if (_isControlsVisible) {
      _controlsAnimationController.forward();
      _startHideControlsTimer();
    } else {
      _controlsAnimationController.reverse();
    }
  }

  void _handleScreenshotDetected() {
    if (_controller?.value.isPlaying == true &&
        _screenshotService!.pauseOnScreenshot) {
      _controller?.pause();
    }

    if (_screenshotService!.showWarningDialog) {
      ScreenshotService.showScreenshotWarningDialog(context);
    }

    if (_screenshotService!.preventScreenshots) {
      _handleObstructScreen();
    }
  }

  void _handleObstructScreen() {
    if (Platform.isIOS) {
      setState(() => _showObstructionOverlay = true);
      Timer(Duration(seconds: 5), () {
        if (mounted) {
          setState(() => _showObstructionOverlay = false);
        }
      });
    }
  }

  void _togglePlayPause() {
    if (_controller?.value.isPlaying == true) {
      _controller?.pause();
    } else {
      _controller?.play();
    }
    _startHideControlsTimer();
  }

  void _seekTo(double value) {
    final position = Duration(
      milliseconds: (value * _duration.inMilliseconds).round(),
    );
    _controller?.seekTo(position);
  }

  void _changeVolume(double value) {
    setState(() => _volume = value);
    _controller?.setVolume(value);
  }

  void _changePlaybackSpeed(double speed) {
    if (speed > 2.0) speed = 2.0;
    setState(() => _playbackSpeed = speed);
    _controller?.setPlaybackSpeed(speed);
  }

  void _rewind() {
    final currentPosition = _controller?.value.position ?? Duration.zero;
    final newPosition = currentPosition - Duration(seconds: 10);
    final clampedPosition = newPosition < Duration.zero
        ? Duration.zero
        : newPosition;
    _controller?.seekTo(clampedPosition);
  }

  void _fastForward() {
    final currentPosition = _controller?.value.position ?? Duration.zero;
    final newPosition = currentPosition + Duration(seconds: 10);
    final clampedPosition = newPosition > _duration ? _duration : newPosition;
    _controller?.seekTo(clampedPosition);
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _positionTimer?.cancel();
    _controlsAnimationController.dispose();
    _controller?.dispose();
    _screenshotService?.stopMonitoring();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Colors.red, size: 64),
              SizedBox(height: 16),
              Text(_errorMessage, style: TextStyle(color: Colors.white)),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
              SizedBox(height: 16),
              Text('Loading video...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: GestureDetector(
                onTap: _toggleControls,
                child: Stack(
                  children: [
                    VideoPlayer(_controller!),
                    Positioned.fill(child: _WatermarkOverlay()),
                    if (_showObstructionOverlay && Platform.isIOS)
                      Container(
                        color: Colors.black.withOpacity(0.9),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.block, color: Colors.red, size: 64),
                              SizedBox(height: 16),
                              Text(
                                'Screenshot Blocked',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Screenshots are not allowed for security reasons.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _controlsAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _controlsAnimation.value,
                child: _isControlsVisible ? _buildControls() : SizedBox(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black54,
            Colors.transparent,
            Colors.transparent,
            Colors.black54,
          ],
          stops: [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: Column(
        children: [
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      widget.videoFile.path.split('/').last,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                      color: Colors.white,
                    ),
                    onPressed: _toggleFullscreen,
                  ),
                ],
              ),
            ),
          ),
          Spacer(),
          Center(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 48,
                ),
                onPressed: _togglePlayPause,
              ),
            ),
          ),
          Spacer(),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Expanded(
                      child: Slider(
                        value: _duration.inMilliseconds > 0
                            ? _position.inMilliseconds /
                                  _duration.inMilliseconds
                            : 0.0,
                        onChanged: _seekTo,
                        activeColor: Theme.of(context).primaryColor,
                        inactiveColor: Colors.white30,
                      ),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(Icons.replay_10, color: Colors.white),
                      onPressed: _rewind,
                    ),
                    IconButton(
                      icon: Icon(Icons.forward_10, color: Colors.white),
                      onPressed: _fastForward,
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.volume_up, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: Slider(
                            value: _volume,
                            onChanged: _changeVolume,
                            activeColor: Theme.of(
                              context,
                            ).colorScheme.secondary,
                            inactiveColor: Colors.white30,
                          ),
                        ),
                      ],
                    ),
                    PopupMenuButton<double>(
                      icon: Icon(Icons.speed, color: Colors.white),
                      color: Theme.of(context).cardColor,
                      onSelected: _changePlaybackSpeed,
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 0.5,
                          child: Text(
                            '0.5x',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        PopupMenuItem(
                          value: 1.0,
                          child: Text(
                            '1.0x',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        PopupMenuItem(
                          value: 1.25,
                          child: Text(
                            '1.25x',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        PopupMenuItem(
                          value: 1.5,
                          child: Text(
                            '1.5x',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        PopupMenuItem(
                          value: 2.0,
                          child: Text(
                            '2.0x',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WatermarkOverlay extends StatefulWidget {
  @override
  _WatermarkOverlayState createState() => _WatermarkOverlayState();
}

class _WatermarkOverlayState extends State<_WatermarkOverlay> {
  final WatermarkService _watermarkService = WatermarkService();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 50,
      right: 20,
      child: _watermarkService.buildWatermark(context),
    );
  }
}