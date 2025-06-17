import 'package:flutter/cupertino.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'player_screen.dart';
import 'settings_screen.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List<File> videoFiles = [];
  bool isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Map<String, Uint8List?> videoThumbnails = {};
  bool isGeneratingThumbnails = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Request storage permissions
  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      var status = await Permission.storage.request();
      return status.isGranted;
    }
    return true;
  }

  // Pick video files from device
  Future<void> _pickVideoFiles() async {
    setState(() => isLoading = true);

    try {
      bool hasPermission = await _requestPermissions();

      if (!hasPermission) {
        _showErrorDialog('Storage permission required to access video files');
        return;
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mov', 'avi', 'mkv'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          videoFiles = result.paths
              .where((path) => path != null)
              .map((path) => File(path!))
              .where((file) => file.existsSync())
              .toList();
        });

        if (videoFiles.isEmpty) {
          _showErrorDialog('No valid video files found');
        }
        if (videoFiles.isNotEmpty) {
          _generateThumbnails();
        }
      }
    } catch (e) {
      _showErrorDialog('Error picking files: ${e.toString()}');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<File> copyFileToDocumentsDirectory(File originalFile) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final newPath = '${directory.path}/${originalFile.path.split('/').last}';
      final newFile = await originalFile.copy(newPath);
      print('Copied file to: $newPath');
      return newFile;
    } catch (e) {
      print('Error copying file: $e');
      return originalFile; // Fallback to original file if copying fails
    }
  }

  // Show error dialog with Apple-style design
  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Error'),
        content: Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(message),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // Navigate to video player
  Future<void> _playVideo(File videoFile) async {
    final persistentFile = await copyFileToDocumentsDirectory(videoFile);
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => PlayerScreen(videoFile: persistentFile),
      ),
    );
  }

  // Navigate to settings
  void _openSettings() {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (context) => SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
      child: CustomScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        slivers: [
          // Apple-style navigation bar
          CupertinoSliverNavigationBar(
            backgroundColor: CupertinoColors.systemBackground.withOpacity(0.9),
            border: Border(),
            largeTitle: Text(
              'Studio',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _openSettings,
              child: Icon(
                CupertinoIcons.settings,
                color: CupertinoColors.systemBlue,
                size: 22,
              ),
            ),
          ),

          // Main content
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 8),

                      // Hero section with Apple-style card
                      _buildHeroSection(),

                      SizedBox(height: 32),

                      // Action button
                      _buildActionButton(),

                      SizedBox(height: 32),

                      // Videos section
                      if (videoFiles.isNotEmpty) ...[
                        Text(
                          'Your Videos',
                          style: CupertinoTheme.of(context)
                              .textTheme
                              .navTitleTextStyle
                              .copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.label,
                              ),
                        ),
                        SizedBox(height: 16),
                      ],

                      // Video list or empty state
                      videoFiles.isEmpty
                          ? _buildEmptyState()
                          : _buildVideoGrid(),

                      SizedBox(height: 32),

                      // Feature cards section
                      _buildFeatureCards(),

                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Apple-style hero section
  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CupertinoColors.systemBlue.withOpacity(0.1),
            CupertinoColors.systemPurple.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: CupertinoColors.separator.withOpacity(0.5),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  CupertinoColors.systemBlue,
                  CupertinoColors.systemPurple,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.systemBlue.withOpacity(0.3),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              CupertinoIcons.play_rectangle_fill,
              color: CupertinoColors.white,
              size: 28,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'SecureVideo Player',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.label,
              letterSpacing: -0.5,
              decoration: TextDecoration.none,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Professional video playback with\nadvanced security & watermarking',
            style: TextStyle(
              fontSize: 15,
              color: CupertinoColors.secondaryLabel,
              height: 1.4,
              decoration: TextDecoration.none,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Apple-style action button
  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: isLoading ? null : _pickVideoFiles,
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: isLoading
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      CupertinoColors.systemBlue,
                      CupertinoColors.systemBlue.darkColor,
                    ],
                  ),
            color: isLoading ? CupertinoColors.quaternarySystemFill : null,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isLoading
                ? null
                : [
                    BoxShadow(
                      color: CupertinoColors.systemBlue.withOpacity(0.3),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading) ...[
                CupertinoActivityIndicator(color: CupertinoColors.systemGrey),
                SizedBox(width: 12),
              ] else ...[
                Icon(
                  CupertinoIcons.folder_badge_plus,
                  color: CupertinoColors.white,
                  size: 20,
                ),
                SizedBox(width: 8),
              ],
              Text(
                isLoading ? 'Loading...' : 'Browse Videos',
                style: TextStyle(
                  color: isLoading
                      ? CupertinoColors.systemGrey
                      : CupertinoColors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Apple-style empty state
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey5,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              CupertinoIcons.video_camera,
              size: 36,
              color: CupertinoColors.systemGrey2,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No Videos Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.label,
              decoration: TextDecoration.none,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Tap "Browse Videos" to add your first video\nfrom your device library',
            style: TextStyle(
              fontSize: 15,
              color: CupertinoColors.secondaryLabel,
              height: 1.4,
              decoration: TextDecoration.none,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Apple-style video grid
  Widget _buildVideoGrid() {
    return Column(
      children: videoFiles.asMap().entries.map((entry) {
        int index = entry.key;
        File file = entry.value;
        return _buildVideoCard(file, index);
      }).toList(),
    );
  }

  // Individual video card with Apple design
  Widget _buildVideoCard(File file, int index) {
    final fileName = file.path.split('/').last;
    final fileSize = _getFileSize(file);
    final fileExtension = fileName.split('.').last.toUpperCase();
    final thumbnail = videoThumbnails[file.path];

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => _playVideo(file),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemGroupedBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: CupertinoColors.separator.withOpacity(0.3),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.systemGrey.withOpacity(0.06),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Video thumbnail with play overlay
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: CupertinoColors.systemGrey5,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Thumbnail or gradient background
                      if (thumbnail != null)
                        Image.memory(
                          thumbnail,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        )
                      else
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                CupertinoColors.systemBlue.withOpacity(0.8),
                                CupertinoColors.systemPurple.withOpacity(0.8),
                              ],
                            ),
                          ),
                        ),

                      // Play button overlay
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: CupertinoColors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          CupertinoIcons.play_fill,
                          color: CupertinoColors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(width: 16),

              // File info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.label,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            fileExtension,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.systemBlue,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          fileSize,
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow indicator
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: CupertinoColors.tertiaryLabel,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Feature cards section
  Widget _buildFeatureCards() {
    final features = [
      {
        'icon': CupertinoIcons.shield_fill,
        'title': 'Screenshot Protection',
        'description':
            'Advanced detection and prevention of unauthorized screenshots',
        'color': CupertinoColors.systemRed,
      },
      {
        'icon': CupertinoIcons.textformat,
        'title': 'Dynamic Watermarking',
        'description':
            'Real-time overlay with timestamps updating every 30 seconds',
        'color': CupertinoColors.systemBlue,
      },
      {
        'icon': CupertinoIcons.lock_fill,
        'title': 'Playback Restrictions',
        'description': 'Controlled speed limits and secure viewing modes',
        'color': CupertinoColors.systemGreen,
      },
      {
        'icon': CupertinoIcons.eye_fill,
        'title': 'Security Monitoring',
        'description': 'Real-time tracking of security events and attempts',
        'color': CupertinoColors.systemOrange,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Security Features',
          style: CupertinoTheme.of(context).textTheme.navTitleTextStyle
              .copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label,
                decoration: TextDecoration.none,
              ),
        ),
        SizedBox(height: 16),
        ...features.asMap().entries.map((entry) {
          int index = entry.key;
          Map<String, dynamic> feature = entry.value;

          return Container(
            width: double.infinity,
            margin: EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CupertinoColors.secondarySystemGroupedBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CupertinoColors.separator.withOpacity(0.3),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.systemGrey.withOpacity(0.06),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: feature['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    feature['icon'],
                    color: feature['color'],
                    size: 22,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature['title'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.label,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        feature['description'],
                        style: TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.secondaryLabel,
                          height: 1.3,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // Generate video thumbnails
  Future<void> _generateThumbnails() async {
    if (videoFiles.isEmpty || isGeneratingThumbnails) return;

    setState(() => isGeneratingThumbnails = true);

    for (File videoFile in videoFiles) {
      try {
        final thumbnail = await VideoThumbnail.thumbnailData(
          video: videoFile.path,
          imageFormat: ImageFormat.PNG,
          maxWidth: 120,
          maxHeight: 120,
          quality: 75,
        );

        if (mounted) {
          setState(() {
            videoThumbnails[videoFile.path] = thumbnail;
          });
        }
      } catch (e) {
        print('Error generating thumbnail for ${videoFile.path}: $e');
      }
    }

    setState(() => isGeneratingThumbnails = false);
  }

  // Get file size in readable format
  String _getFileSize(File file) {
    try {
      int bytes = file.lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      if (bytes < 1024 * 1024 * 1024) {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } catch (e) {
      return 'Unknown size';
    }
  }
}
