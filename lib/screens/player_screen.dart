import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chewie/chewie.dart';
import 'dart:io';
import 'dart:async';
import '../services/video_service.dart';
import '../services/watermark_service.dart';
import '../services/screenshot_service.dart';
import 'package:path_provider/path_provider.dart';

class PlayerScreen extends StatefulWidget {
  final File videoFile;

  const PlayerScreen({super.key, required this.videoFile});

  @override
  _PlayerScreenState createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
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
    print('PlayerScreen: Initializing for video: ${widget.videoFile.path}');
    _initializeServices();
    _initializeAnimations();
    _validateAndInitializeVideoPlayer();
  }

  void _initializeServices() {
    _videoService = VideoService();
    _watermarkService = WatermarkService();
    _screenshotService = ScreenshotService();

    _screenshotService!.setOnScreenshotDetected(_handleScreenshotDetected);
    _screenshotService!.setOnObstructScreen(_handleObstructScreen);
    _watermarkService!.initialize();
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

  Future<void> _validateAndInitializeVideoPlayer() async {
    try {
      // Validate the file
      if (!widget.videoFile.existsSync()) {
        throw Exception('Video file does not exist: ${widget.videoFile.path}');
      }
      int fileSize = await widget.videoFile.length();
      if (fileSize == 0) {
        throw Exception('Video file is empty: ${widget.videoFile.path}');
      }
      print('PlayerScreen: File validated. Size: $fileSize bytes');

      // Add a small delay to ensure file is accessible
      await Future.delayed(Duration(milliseconds: 500));

      // Reset VideoService before initializing a new video
      await _videoService!.reset();
      print('PlayerScreen: VideoService reset completed');

      // Retry logic for creating the controller
      ChewieController? controller;
      int retries = 2;
      for (int attempt = 1; attempt <= retries; attempt++) {
        try {
          controller = await _videoService!.createController(widget.videoFile);
          if (controller != null) break;
          throw Exception('Controller creation failed on attempt $attempt');
        } catch (e) {
          print('PlayerScreen: Attempt $attempt failed: $e');
          if (attempt == retries) rethrow;
          await Future.delayed(Duration(milliseconds: 500));
        }
      }

      if (controller == null) {
        throw Exception(
          'Failed to create video controller after $retries attempts',
        );
      }

      setState(() {
        _duration = _videoService!.currentController!.value.duration;
        _isLoading = false;
      });

      _positionTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
        if (mounted &&
            _videoService!.currentController?.value.isInitialized == true) {
          setState(() {
            _position = _videoService!.currentController!.value.position;
          });
        }
      });

      _startHideControlsTimer();
    } catch (e) {
      print('PlayerScreen: Error initializing video player: $e');
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
    if (_videoService!.chewieController?.isPlaying == true &&
        _screenshotService!.pauseOnScreenshot) {
      _videoService!.pause();
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
    if (_videoService!.chewieController?.isPlaying == true) {
      _videoService!.pause();
    } else {
      _videoService!.play();
    }
    _startHideControlsTimer();
  }

  void _seekTo(double value) {
    final position = Duration(
      milliseconds: (value * _duration.inMilliseconds).round(),
    );
    _videoService!.seekTo(position);
  }

  void _changeVolume(double value) {
    setState(() => _volume = value);
    _videoService!.setVolume(value);
  }

  void _changePlaybackSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    _videoService!.setPlaybackSpeed(speed);
  }

  void _rewind() {
    _videoService!.rewind();
  }

  void _fastForward() {
    _videoService!.fastForward();
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
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
    print('PlayerScreen: Disposing for video: ${widget.videoFile.path}');
    _hideControlsTimer?.cancel();
    _positionTimer?.cancel();
    _controlsAnimationController.dispose();

    _videoService
        ?.disposeController()
        .then((_) {
          print('PlayerScreen: VideoService controller disposed');
          _videoService?.reset().then((_) {
            print('PlayerScreen: VideoService reset on dispose');
          });
        })
        .catchError((e) {
          print('PlayerScreen: Error disposing VideoService: $e');
        });

    _screenshotService
        ?.stopMonitoring()
        .then((_) {
          print('PlayerScreen: ScreenshotService monitoring stopped');
          if (Platform.isIOS) {
            _screenshotService?.disableSecureOverlay().then((_) {
              print('PlayerScreen: Secure overlay disabled');
            });
          }
        })
        .catchError((e) {
          print('PlayerScreen: Error stopping ScreenshotService: $e');
        });

    _watermarkService?.dispose();
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }

    getApplicationDocumentsDirectory().then((directory) {
      final filePath = widget.videoFile.path;
      if (filePath.startsWith(directory.path)) {
        widget.videoFile
            .delete()
            .then((_) {
              print('PlayerScreen: Deleted copied file: $filePath');
            })
            .catchError((e) {
              print('PlayerScreen: Error deleting copied file: $e');
            });
      }
    });

    super.dispose();
    print('PlayerScreen: Dispose completed');
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
            child: GestureDetector(
              onTap: _toggleControls,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Use AspectRatio to maintain video proportions
                  AspectRatio(
                    aspectRatio:
                        _videoService!.currentController!.value.aspectRatio,
                    child: Chewie(
                      controller: _videoService!.chewieController!.copyWith(
                        showControls:
                            false, // Disable Chewie's built-in controls
                        autoPlay: false,
                        allowFullScreen: false,
                        deviceOrientationsAfterFullScreen: [
                          DeviceOrientation.portraitUp,
                        ],
                      ),
                    ),
                  ),
                  _watermarkService!.buildWatermarkWidget(
                    context,
                    MediaQuery.of(context).size,
                  ),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        widget.videoFile.path.split('/').last,
                        style: TextStyle(color: Colors.white, fontSize: 16),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: _toggleFullscreen,
                  ),
                ],
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.replay_10, color: Colors.white, size: 40),
                onPressed: _rewind,
              ),
              SizedBox(width: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    _videoService!.chewieController!.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: Colors.white,
                    size: 48,
                  ),
                  onPressed: _togglePlayPause,
                ),
              ),
              SizedBox(width: 20),
              IconButton(
                icon: Icon(Icons.forward_10, color: Colors.white, size: 40),
                onPressed: _fastForward,
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    SizedBox(width: 8),
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
                    SizedBox(width: 8),
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.volume_up, color: Colors.white, size: 24),
                        SizedBox(width: 8),
                        SizedBox(
                          width: 100,
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
                      icon: Icon(Icons.speed, color: Colors.white, size: 24),
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
  @override
  Widget build(BuildContext context) {
    return WatermarkService().buildWatermarkWidget(
      context,
      MediaQuery.of(context).size,
    );
  }
}
