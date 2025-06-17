import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _watermarkEnabled = true;
  bool _screenshotDetectionEnabled = true;
  bool _pauseOnScreenshot = true;
  bool _preventScreenshots = true; // New setting
  bool _playbackRestrictionsEnabled = true;
  double _maxPlaybackSpeed = 2.0;
  int _maxRewindSeconds = 10;
  String _watermarkText = 'SecurePlayer';
  double _watermarkOpacity = 0.7;

  bool _isLoading = true;

  final Color _primaryColor = const Color(0xFF007AFF);
  final Color _cardColor = Colors.white;
  final TextStyle _headerStyle = const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: Color(0xFF007AFF),
    letterSpacing: 0.5,
  );
  final TextStyle _titleStyle = const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Color(0xFF1C1C1E),
  );
  final TextStyle _subtitleStyle = const TextStyle(
    fontSize: 14,
    color: Color(0xFF8E8E93),
  );

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadSettings();
  }

  void _initializeAnimations() {
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

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        _watermarkEnabled = prefs.getBool('watermark_enabled') ?? true;
        _screenshotDetectionEnabled =
            prefs.getBool('screenshot_detection_enabled') ?? true;
        _pauseOnScreenshot = prefs.getBool('pause_on_screenshot') ?? true;
        _preventScreenshots =
            prefs.getBool('screenshot_prevent_enabled') ?? true;
        _playbackRestrictionsEnabled =
            prefs.getBool('playback_restrictions_enabled') ?? true;
        _maxPlaybackSpeed = prefs.getDouble('max_playback_speed') ?? 2.0;
        _maxRewindSeconds = prefs.getInt('max_rewind_seconds') ?? 10;
        _watermarkText = prefs.getString('watermark_text') ?? 'SecurePlayer';
        _watermarkOpacity = prefs.getDouble('watermark_opacity') ?? 0.7;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('Failed to load settings: ${e.toString()}');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('watermark_enabled', _watermarkEnabled);
      await prefs.setBool(
        'screenshot_detection_enabled',
        _screenshotDetectionEnabled,
      );
      await prefs.setBool('pause_on_screenshot', _pauseOnScreenshot);
      await prefs.setBool('screenshot_prevent_enabled', _preventScreenshots);
      await prefs.setBool(
        'playback_restrictions_enabled',
        _playbackRestrictionsEnabled,
      );
      await prefs.setDouble('max_playback_speed', _maxPlaybackSpeed);
      await prefs.setInt('max_rewind_seconds', _maxRewindSeconds);
      await prefs.setString('watermark_text', _watermarkText);
      await prefs.setDouble('watermark_opacity', _watermarkOpacity);

      _showSaveConfirmation();
    } catch (e) {
      _showErrorDialog('Failed to save settings: ${e.toString()}');
    }
  }

  void _showSaveConfirmation() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Icon(
          CupertinoIcons.checkmark_circle_fill,
          color: CupertinoColors.systemGreen,
          size: 32,
        ),
        content: Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('Settings saved successfully'),
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

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              color: CupertinoColors.systemRed,
              size: 24,
            ),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
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

  void _resetToDefaults() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Reset Settings'),
        content: Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Are you sure you want to reset all settings to default values?',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _watermarkEnabled = true;
                _screenshotDetectionEnabled = true;
                _pauseOnScreenshot = true;
                _preventScreenshots = true;
                _playbackRestrictionsEnabled = true;
                _maxPlaybackSpeed = 2.0;
                _maxRewindSeconds = 10;
                _watermarkText = 'SecurePlayer';
                _watermarkOpacity = 0.7;
              });
              _saveSettings();
            },
            child: Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showTextFieldDialog({
    required String title,
    required String value,
    required Function(String) onChanged,
  }) {
    TextEditingController controller = TextEditingController(text: value);
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: EdgeInsets.only(top: 8),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'Enter watermark text',
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: CupertinoColors.tertiarySystemGroupedBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: CupertinoColors.separator.withOpacity(0.3),
                width: 0.5,
              ),
            ),
            style: TextStyle(color: CupertinoColors.label, fontSize: 16),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              onChanged(controller.text);
              Navigator.pop(context);
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            'Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          scrolledUnderElevation: 1,
          elevation: 0,
          shadowColor: Colors.black.withOpacity(0.7),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: Icon(
                CupertinoIcons.refresh,
                color: _primaryColor,
                size: 22,
              ),
              onPressed: _resetToDefaults,
            ),
          ],
        ),
        body: Center(child: CupertinoActivityIndicator(radius: 20)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            centerTitle: true,
            title: const Text(
              'Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1E),
              ),
            ),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 1,
            shadowColor: Colors.black.withOpacity(0.7),
            leading: IconButton(
              icon: const Icon(
                CupertinoIcons.back,
                color: Color(0xFF007AFF),
                size: 28,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  CupertinoIcons.refresh,
                  color: _primaryColor,
                  size: 22,
                ),
                onPressed: _resetToDefaults,
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection(
                      title: 'Security',
                      children: [
                        _buildSwitchTile(
                          title: 'Screenshot Detection',
                          subtitle:
                              'Monitor and prevent unauthorized screenshots',
                          icon: CupertinoIcons.camera_viewfinder,
                          value: _screenshotDetectionEnabled,
                          onChanged: (value) {
                            setState(() => _screenshotDetectionEnabled = value);
                          },
                          showDivider: true,
                        ),
                        _buildSwitchTile(
                          title: 'Pause on Screenshot',
                          subtitle:
                              'Automatically pause when screenshot detected',
                          icon: CupertinoIcons.pause_circle,
                          value: _pauseOnScreenshot,
                          onChanged: _screenshotDetectionEnabled
                              ? (value) {
                                  setState(() => _pauseOnScreenshot = value);
                                }
                              : null,
                          enabled: _screenshotDetectionEnabled,
                          showDivider: true,
                        ),
                        _buildSwitchTile(
                          title: 'Prevent Screenshots',
                          subtitle: 'Block screenshots during video playback',
                          icon: CupertinoIcons.lock_shield,
                          value: _preventScreenshots,
                          onChanged: (value) {
                            setState(() => _preventScreenshots = value);
                          },
                        ),
                      ],
                    ),
                    _buildSection(
                      title: 'Watermark',
                      children: [
                        _buildSwitchTile(
                          title: 'Enable Watermark',
                          subtitle: 'Show overlay on video content',
                          icon: CupertinoIcons.textformat,
                          value: _watermarkEnabled,
                          onChanged: (value) {
                            setState(() => _watermarkEnabled = value);
                          },
                          showDivider: true,
                        ),
                        _buildListTile(
                          title: 'Watermark Text',
                          subtitle: _watermarkText,
                          icon: CupertinoIcons.textformat_abc,
                          enabled: _watermarkEnabled,
                          onTap: _watermarkEnabled
                              ? () {
                                  _showTextFieldDialog(
                                    title: 'Watermark Text',
                                    value: _watermarkText,
                                    onChanged: (value) {
                                      setState(() => _watermarkText = value);
                                    },
                                  );
                                }
                              : null,
                          showDivider: true,
                        ),
                        _buildSliderTile(
                          title: 'Opacity',
                          subtitle: 'Watermark transparency',
                          icon: CupertinoIcons.circle_lefthalf_fill,
                          value: _watermarkOpacity,
                          min: 0.1,
                          max: 1.0,
                          divisions: 9,
                          enabled: _watermarkEnabled,
                          onChanged: (value) {
                            setState(() => _watermarkOpacity = value);
                          },
                          valueLabel: '${(_watermarkOpacity * 100).round()}%',
                        ),
                      ],
                    ),
                    _buildSection(
                      title: 'Playback',
                      children: [
                        _buildSwitchTile(
                          title: 'Playback Restrictions',
                          subtitle: 'Enable speed and rewind limits',
                          icon: CupertinoIcons.slider_horizontal_3,
                          value: _playbackRestrictionsEnabled,
                          onChanged: (value) {
                            setState(
                              () => _playbackRestrictionsEnabled = value,
                            );
                          },
                          showDivider: true,
                        ),
                        _buildSliderTile(
                          title: 'Max Speed',
                          subtitle: 'Maximum playback speed',
                          icon: CupertinoIcons.speedometer,
                          value: _maxPlaybackSpeed,
                          min: 1.0,
                          max: 3.0,
                          divisions: 8,
                          enabled: _playbackRestrictionsEnabled,
                          onChanged: (value) {
                            setState(() => _maxPlaybackSpeed = value);
                          },
                          valueLabel:
                              '${_maxPlaybackSpeed.toStringAsFixed(1)}×',
                          showDivider: true,
                        ),
                        _buildSliderTile(
                          title: 'Max Rewind',
                          subtitle: 'Maximum rewind duration',
                          icon: CupertinoIcons.gobackward,
                          value: _maxRewindSeconds.toDouble(),
                          min: 5.0,
                          max: 30.0,
                          divisions: 5,
                          enabled: _playbackRestrictionsEnabled,
                          onChanged: (value) {
                            setState(() => _maxRewindSeconds = value.round());
                          },
                          valueLabel: '${_maxRewindSeconds}s',
                        ),
                      ],
                    ),
                    _buildSaveButton(),
                    _buildAppInfoSection(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(title.toUpperCase(), style: _headerStyle),
          ),
          Container(
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool>? onChanged,
    bool enabled = true,
    bool showDivider = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: enabled ? _primaryColor : CupertinoColors.inactiveGray,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: enabled
                          ? _titleStyle
                          : _titleStyle.copyWith(
                              color: CupertinoColors.inactiveGray,
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        subtitle,
                        style: enabled
                            ? _subtitleStyle
                            : _subtitleStyle.copyWith(
                                color: CupertinoColors.inactiveGray,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoSwitch(
                value: value,
                activeTrackColor: enabled ? _primaryColor : null,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 68),
            child: Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
          ),
      ],
    );
  }

  Widget _buildListTile({
    required String title,
    String? subtitle,
    required IconData icon,
    bool showDivider = false,
    bool enabled = true,
    required VoidCallback? onTap,
    String? valueLabel,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: enabled
                        ? _primaryColor
                        : CupertinoColors.inactiveGray,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: enabled
                            ? _titleStyle
                            : _titleStyle.copyWith(
                                color: CupertinoColors.inactiveGray,
                              ),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            subtitle,
                            style: enabled
                                ? _subtitleStyle
                                : _subtitleStyle.copyWith(
                                    color: CupertinoColors.inactiveGray,
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (valueLabel != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      valueLabel,
                      style: TextStyle(
                        color: enabled
                            ? _primaryColor
                            : CupertinoColors.inactiveGray,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  const Icon(
                    CupertinoIcons.chevron_right,
                    color: CupertinoColors.systemGrey,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 68),
            child: Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
          ),
      ],
    );
  }

  Widget _buildSliderTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required bool enabled,
    required Function(double) onChanged,
    String? valueLabel,
    bool showDivider = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: enabled
                          ? _primaryColor
                          : CupertinoColors.inactiveGray,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: enabled
                              ? _titleStyle
                              : _titleStyle.copyWith(
                                  color: CupertinoColors.inactiveGray,
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            subtitle,
                            style: enabled
                                ? _subtitleStyle
                                : _subtitleStyle.copyWith(
                                    color: CupertinoColors.inactiveGray,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      valueLabel ?? value.toStringAsFixed(1),
                      style: TextStyle(
                        color: enabled
                            ? _primaryColor
                            : CupertinoColors.inactiveGray,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 68),
            child: Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
          ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 12),
        color: _primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        onPressed: _saveSettings,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.floppy_disk, size: 18, color: _primaryColor),
            const SizedBox(width: 8),
            Text(
              'Save Settings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppInfoSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primaryColor, _primaryColor.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              CupertinoIcons.play_rectangle_fill,
              color: CupertinoColors.white,
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Studio - Secure Video Player',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Version 1.0.0',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {},
                child: Text(
                  'Terms of Service',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ),
              Text(
                '•',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  'Privacy Policy',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
