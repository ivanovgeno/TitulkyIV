import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:universal_io/io.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:file_picker/file_picker.dart';
import '../models/caption_model.dart';
import '../services/mock_data_provider.dart';
import '../main.dart';
import 'caption_overlay.dart';
import 'timeline_widget.dart';
import 'inspector_widget.dart';
import '../services/api_service.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with TickerProviderStateMixin {
  CaptionProject? project;
  double _currentTime = 0.0;
  double _videoDuration = 5.0;
  bool _isPlaying = false;
  String? _selectedCaptionId;
  String? _videoPath;
  Uint8List? _videoBytes;
  String? _videoName;
  bool _isTranscribing = false;
  bool _isMasking = false;
  String? _maskPath;
  String? _maskBwPath;
  bool _mobileCanvasRegistered = false;
  final List<CaptionStyle> _presets = [];
  bool _inspectorCollapsed = false;

  // Media Kit
  late final Player _player;
  late final Player _maskPlayer;
  late final VideoController _videoController;
  late final VideoController _maskController;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _maskPlayer = Player();
    _videoController = VideoController(_player);
    _maskController = VideoController(
      _maskPlayer,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: false,
      ),
    );

    _player.stream.duration.listen((duration) {
      if (duration.inMilliseconds > 0) {
        setState(() {
          _videoDuration = duration.inMilliseconds / 1000.0;
        });
      }
    });

    _player.stream.playing.listen((playing) {
      setState(() {
        _isPlaying = playing;
      });
      if (playing) {
        _maskPlayer.play();
      } else {
        _maskPlayer.pause();
      }
      if (kIsWeb && _mobileCanvasRegistered) {
        _callMaskCanvasJS('setPlaying', [playing.toJS]);
      }
    });

    _player.stream.position.listen((position) {
      setState(() {
        _currentTime = position.inMilliseconds / 1000.0;
      });
    });

    _loadData();
  }

  Future<void> _loadData() async {
    final data = await MockDataProvider.loadMockProject();
    setState(() {
      project = data;
    });
  }

  Future<void> _openVideoFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        withData: kIsWeb,
        dialogTitle: 'Vyber video soubor',
      );

      if (result != null && result.files.single.name.isNotEmpty) {
        final file = result.files.single;
        final name = file.name;
        String? sourceToPlay;

        if (kIsWeb) {
          if (file.bytes != null) {
            final blob = html.Blob([file.bytes!], 'video/mp4');
            sourceToPlay = html.Url.createObjectUrlFromBlob(blob);
            setState(() {
              _videoBytes = file.bytes;
              _videoName = name;
              _videoPath = sourceToPlay;
            });
          } else {
            if (mounted) {
              _showSnackBar('Chyba: Nepodařilo se načíst data videa z prohlížeče.');
            }
          }
        } else {
          if (file.path != null) {
            sourceToPlay = file.path!;
            final bytes = await File(sourceToPlay).readAsBytes();
            setState(() {
              _videoPath = sourceToPlay;
              _videoName = name;
              _videoBytes = bytes;
            });
          }
        }

        if (sourceToPlay != null) {
          await _player.open(Media(sourceToPlay));
          await _player.pause();
        }
      }
    } catch (e) {
      print('Error picking video: $e');
      if (mounted) {
        _showSnackBar('Chyba při nahrávání videa: $e');
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        backgroundColor: AppColors.bgElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _runTranscription() async {
    if (_videoPath == null) return;

    setState(() {
      _isTranscribing = true;
    });

    try {
      final api = ApiService();
      
      if (_videoBytes == null) {
        if (mounted) _showSnackBar('Chyba: Nemáme k dispozici data videa k odeslání.');
        return;
      }

      if (mounted) _showSnackBar('Nahrávám video do cloudu...');
      
      final projectId = await api.uploadVideoForTranscription(_videoBytes!, _videoName ?? 'video.mp4');
      
      if (projectId == null) {
        if (mounted) _showSnackBar('Chyba: Nepodařilo se nahrát video na server.');
        return;
      }

      if (mounted) _showSnackBar('Video nahráno! Čekám na přepis...');
      
      bool completed = false;
      int attempts = 0;
      
      while (!completed && attempts < 500 && mounted) {
        await Future.delayed(const Duration(seconds: 3));
        attempts++;
        
        final result = await api.checkTranscriptionStatus(projectId);
        if (result != null) {
          setState(() {
            project = result;
            _selectedCaptionId = null;
            _isTranscribing = false;
          });
          if (mounted) _showSnackBar('Přepis dokončen!');
          completed = true;
        }
      }
      
      if (!completed && mounted) {
        _showSnackBar('Časový limit vypršel. Server možná stále pracuje.');
      }
    } catch (e) {
      if (mounted) _showSnackBar('Chyba: $e');
    } finally {
      if (mounted) setState(() => _isTranscribing = false);
    }
  }

  void _togglePlay() {
    _player.playOrPause();
  }

  void _seekTo(double time) {
    final pos = Duration(milliseconds: (time * 1000).toInt());
    _player.seek(pos);
    _maskPlayer.seek(pos);
    if (kIsWeb && _mobileCanvasRegistered) {
      _callMaskCanvasJS('seek', [time.toJS]);
    }
  }

  void _callMaskCanvasJS(String method, [List<JSAny?>? args]) {
    if (!kIsWeb) return;
    try {
      final mc = globalContext.getProperty('MaskCanvas'.toJS);
      if (mc == null || mc.isUndefinedOrNull) return;
      final fn = (mc as JSObject).getProperty(method.toJS);
      if (fn == null || fn.isUndefinedOrNull) return;
      final jsFn = fn as JSFunction;
      if (args == null || args.isEmpty) {
        jsFn.callAsFunction(mc);
      } else if (args.length == 1) {
        jsFn.callAsFunction(mc, args[0]);
      } else {
        jsFn.callAsFunction(mc, args[0], args[1]);
      }
    } catch (e) {
      print('MaskCanvas JS call error ($method): $e');
    }
  }

  void _setupMobileCanvas(String originalVideoUrl, String bwMaskUrl) {
    if (!kIsWeb) return;
    try {
      _callMaskCanvasJS('create', [originalVideoUrl.toJS, bwMaskUrl.toJS]);
      setState(() { _mobileCanvasRegistered = true; });
      if (_isPlaying) _callMaskCanvasJS('play');
    } catch (e) {
      print('Error setting up mobile canvas: $e');
    }
  }

  Future<void> _generateMask() async {
    if (_videoPath == null) return;
    setState(() => _isMasking = true);

    try {
      final api = ApiService();
      
      if (_videoBytes == null) {
        if (mounted) _showSnackBar('Chyba: Nemáme data videa.');
        return;
      }

      if (mounted) _showSnackBar('Nahrávám video pro maskování...');
      
      final projectId = await api.uploadVideoForMasking(_videoBytes!, _videoName ?? 'video.mp4');
      
      if (projectId == null) {
        if (mounted) _showSnackBar('Chyba: Nepodařilo se nahrát video.');
        return;
      }

      if (mounted) _showSnackBar('Generuji masku (SAM 2)...');
      
      bool completed = false;
      int attempts = 0;
      
      while (!completed && attempts < 500 && mounted) {
        await Future.delayed(const Duration(seconds: 5));
        attempts++;
        
        final maskUrls = await api.checkMaskStatus(projectId);
        if (maskUrls != null) {
          final serverUrl = ApiService.baseUrl.replaceAll('/api/v1', '');
          
          final bwPath = maskUrls['bw'] ?? '';
          final fullBwUrl = bwPath.isNotEmpty ? '$serverUrl$bwPath' : '';
          
          String maskPathToUse = maskUrls['webm']!;
          if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
            maskPathToUse = maskUrls['mov']!;
          }
          
          final fullMaskUrl = '$serverUrl$maskPathToUse';
          
          final isMobilePlatform = defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android;
          final isMobileWeb = kIsWeb && (MediaQuery.of(context).size.width < 800 || isMobilePlatform);
          
          setState(() {
            _maskPath = fullMaskUrl;
            _maskBwPath = fullBwUrl;
            _isMasking = false;
          });
          
          if (isMobileWeb && fullBwUrl.isNotEmpty && _videoPath != null) {
            _setupMobileCanvas(_videoPath!, fullBwUrl);
          } else {
            await _maskPlayer.setVolume(0);
            await _maskPlayer.open(Media(fullMaskUrl), play: false);
            await _maskPlayer.seek(_player.state.position);
            if (_player.state.playing) await _maskPlayer.play();
          }
          
          if (mounted) _showSnackBar('Maska vygenerována!');
          completed = true;
        }
      }
      
      if (!completed && mounted) _showSnackBar('Časový limit vypršel.');
    } catch (e) {
      if (mounted) _showSnackBar('Chyba: $e');
    } finally {
      if (mounted) setState(() => _isMasking = false);
    }
  }

  void _addCaption() {
    if (project == null) return;
    final idx = project!.captions.length;
    final newCaption = Caption(
      id: 'word_${idx.toString().padLeft(4, '0')}',
      text: 'Nový titulek',
      startTime: _currentTime,
      endTime: _currentTime + 1.0,
      category: 'Main',
      style: CaptionStyle(),
      transform3D: Transform3D(
        position: {'x': project!.resolution.width / 2, 'y': project!.resolution.height / 2, 'z': 0},
        rotation: {'x': 0.0, 'y': 0.0, 'z': 0.0},
        meshBendEnabled: false,
      ),
    );
    setState(() {
      project!.captions.add(newCaption);
      _selectedCaptionId = newCaption.id;
    });
  }

  void _deleteCaption() {
    if (project == null || _selectedCaptionId == null) return;
    setState(() {
      project!.captions.removeWhere((c) => c.id == _selectedCaptionId);
      _selectedCaptionId = null;
    });
  }

  void _savePreset(CaptionStyle style) {
    setState(() { _presets.add(style.copy()); });
  }

  void _applyPreset(CaptionStyle style) {
    if (_selectedCaptionId == null || project == null) return;
    final caption = project!.captions.where((c) => c.id == _selectedCaptionId).firstOrNull;
    if (caption != null) {
      setState(() { caption.style = style.copy(); });
    }
  }

  // ─────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (project == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48, height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 16),
              Text('Načítám projekt...', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    final bool isMobile = MediaQuery.of(context).size.width < 800 ||
        (Theme.of(context).platform == TargetPlatform.iOS || Theme.of(context).platform == TargetPlatform.android);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
    );
  }

  // ─────────────────────────────────────
  // DESKTOP LAYOUT (new sidebar approach)
  // ─────────────────────────────────────

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left sidebar (tool icons)
        _buildSidebar(),
        // Main content area
        Expanded(
          child: Column(
            children: [
              // Top toolbar
              _buildTopToolbar(),
              // Video preview + optional inspector
              Expanded(
                child: Row(
                  children: [
                    // Video area
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                        child: _buildVideoPreview(),
                      ),
                    ),
                    // Inspector (collapsible)
                    if (!_inspectorCollapsed)
                      SizedBox(
                        width: 340,
                        child: _buildInspector(),
                      ),
                  ],
                ),
              ),
              // Timeline
              _buildTimeline(isMobile: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 56,
      decoration: BoxDecoration(
        color: AppColors.bgPanel,
        border: Border(right: BorderSide(color: AppColors.border.withOpacity(0.5))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Logo / brand
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accent, AppColors.accentLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text('IV', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 20),
          _sidebarBtn(Icons.movie_outlined, 'Nahrát video', _openVideoFile, isActive: _videoPath != null),
          _sidebarBtn(Icons.subtitles_outlined, 'Přepis', _videoPath != null ? _runTranscription : null, isLoading: _isTranscribing),
          _sidebarBtn(Icons.person_outline_rounded, 'Maska', _videoPath != null ? _generateMask : null, isLoading: _isMasking),
          if (_maskPath != null)
            _sidebarBtn(Icons.layers_clear_outlined, 'Zrušit masku', () {
              setState(() { _maskPath = null; _maskPlayer.pause(); });
            }, color: AppColors.danger),
          const Spacer(),
          _sidebarBtn(
            _inspectorCollapsed ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
            _inspectorCollapsed ? 'Otevřít panel' : 'Zavřít panel',
            () => setState(() => _inspectorCollapsed = !_inspectorCollapsed),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _sidebarBtn(IconData icon, String tooltip, VoidCallback? onTap, {bool isActive = false, bool isLoading = false, Color? color}) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: isActive ? AppColors.accent.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isActive ? Border.all(color: AppColors.accent.withOpacity(0.3)) : null,
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                  : Icon(icon, size: 20, color: onTap == null ? AppColors.textMuted : (color ?? (isActive ? AppColors.accent : AppColors.textSecondary))),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopToolbar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.bgPanel,
        border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Text(
            'IvCaptions',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: 0.5,
            ),
          ),
          if (_videoName != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_outlined, size: 14, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text(_videoName!, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ],
          const Spacer(),
          // Time display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              "${_currentTime.toStringAsFixed(1)}s / ${_videoDuration.toStringAsFixed(1)}s",
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────
  // MOBILE LAYOUT
  // ─────────────────────────────────────

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Safe area top
        Container(
          color: AppColors.bgPanel,
          child: SafeArea(
            bottom: false,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  // Logo
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accentLight]),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Center(child: Text('IV', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10))),
                  ),
                  const SizedBox(width: 10),
                  Text('IvCaptions', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                  const Spacer(),
                  // Time
                  Text(
                    "${_currentTime.toStringAsFixed(1)}s",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Video Preview
        Expanded(
          child: Container(
            color: Colors.black,
            child: _buildVideoPreview(),
          ),
        ),
        // Mobile Action Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.bgPanel,
            border: Border(top: BorderSide(color: AppColors.border.withOpacity(0.5))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMobileActionBtn(Icons.movie_outlined, 'Nahrát', _openVideoFile),
              if (_videoPath != null) ...[
                _isTranscribing
                    ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                    : _buildMobileActionBtn(Icons.subtitles_outlined, 'Přepis', _runTranscription),
                _isMasking
                    ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                    : _buildMobileActionBtn(Icons.person_outline_rounded, 'Maska', _generateMask),
                if (_maskPath != null)
                  _buildMobileActionBtn(Icons.layers_clear_outlined, 'Zrušit', () {
                    setState(() { _maskPath = null; _maskPlayer.pause(); });
                  }, color: AppColors.danger),
              ],
            ],
          ),
        ),
        // Timeline + Inspector (tabs)
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.35,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bgPanel,
              border: Border(top: BorderSide(color: AppColors.border.withOpacity(0.5))),
            ),
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    indicatorColor: AppColors.accent,
                    indicatorWeight: 2,
                    labelColor: AppColors.accent,
                    unselectedLabelColor: AppColors.textMuted,
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    tabs: const [
                      Tab(text: 'Timeline'),
                      Tab(text: 'Inspektor'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildTimeline(isMobile: true),
                        _buildInspector(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileActionBtn(IconData icon, String label, VoidCallback onTap, {Color color = AppColors.accent}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────
  // VIDEO PREVIEW
  // ─────────────────────────────────────

  Widget _buildVideoPreview() {
    final bool isMobile = MediaQuery.of(context).size.width < 800 ||
        (Theme.of(context).platform == TargetPlatform.iOS || Theme.of(context).platform == TargetPlatform.android);

    return Center(
      child: GestureDetector(
        onTap: () {
          if (_videoPath != null) _togglePlay();
        },
        child: AspectRatio(
          aspectRatio: project!.resolution.width / project!.resolution.height,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(isMobile ? 0 : 14),
              border: isMobile ? null : Border.all(color: AppColors.border, width: 1),
              boxShadow: isMobile ? null : [
                BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 30, spreadRadius: -5),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isMobile ? 0 : 13),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_videoPath != null)
                    Video(
                      controller: _videoController,
                      controls: NoVideoControls,
                    )
                  else
                    _buildUploadPrompt(),
                  CaptionOverlay(
                    captions: project!.captions.where((c) => c.style.behindPerson).toList(),
                    currentTime: _currentTime,
                    resolution: project!.resolution,
                    selectedCaptionId: _selectedCaptionId,
                    onCaptionSelected: (id) { setState(() { _selectedCaptionId = id; }); },
                    onCaptionUpdate: () { setState(() {}); },
                  ),
                  if (_maskPath != null && !(_mobileCanvasRegistered && isMobile))
                    IgnorePointer(
                      child: Video(
                        controller: _maskController,
                        controls: NoVideoControls,
                        fill: Colors.transparent,
                      ),
                    ),
                  if (_mobileCanvasRegistered && isMobile)
                    IgnorePointer(
                      child: HtmlElementView.fromTagName(
                        tagName: 'div',
                        onElementCreated: (element) {
                          try {
                            final mc = globalContext.getProperty('MaskCanvas'.toJS) as JSObject?;
                            if (mc != null) {
                              final appendToFn = mc.getProperty('appendTo'.toJS) as JSFunction?;
                              if (appendToFn != null) {
                                appendToFn.callAsFunction(mc, element as JSAny);
                              }
                            }
                          } catch (e) {
                            print('Error attaching MaskCanvas: $e');
                          }
                        },
                      ),
                    ),
                  CaptionOverlay(
                    captions: project!.captions.where((c) => !c.style.behindPerson).toList(),
                    currentTime: _currentTime,
                    resolution: project!.resolution,
                    selectedCaptionId: _selectedCaptionId,
                    onCaptionSelected: (id) { setState(() { _selectedCaptionId = id; }); },
                    onCaptionUpdate: () { setState(() {}); },
                  ),
                  // Play button overlay (mobile)
                  if (isMobile && _videoPath != null && !_isPlaying)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black26,
                        child: Center(
                          child: Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.9),
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 20)],
                            ),
                            child: const Icon(Icons.play_arrow_rounded, size: 36, color: Colors.black),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadPrompt() {
    return Material(
      color: AppColors.bgCard,
      child: InkWell(
        onTap: _openVideoFile,
        hoverColor: AppColors.bgHover,
        splashColor: AppColors.accent.withOpacity(0.1),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 2),
                ),
                child: const Icon(Icons.cloud_upload_outlined, size: 36, color: AppColors.accent),
              ),
              const SizedBox(height: 20),
              const Text(
                "Nahrát video",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                "MP4, MOV nebo WebM",
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────
  // TIMELINE
  // ─────────────────────────────────────

  Widget _buildTimeline({required bool isMobile}) {
    final controls = Row(
      children: [
        // Play/Pause button
        InkWell(
          onTap: _videoPath != null ? _togglePlay : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: isMobile ? 40 : 44,
            height: isMobile ? 40 : 44,
            decoration: BoxDecoration(
              gradient: _videoPath != null
                  ? const LinearGradient(colors: [AppColors.accent, AppColors.accentLight])
                  : null,
              color: _videoPath == null ? AppColors.bgCard : null,
              borderRadius: BorderRadius.circular(12),
              boxShadow: _videoPath != null ? [
                BoxShadow(color: AppColors.accent.withOpacity(0.25), blurRadius: 12, spreadRadius: -2),
              ] : null,
            ),
            child: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: isMobile ? 24 : 26,
              color: _videoPath != null ? Colors.black : AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (!isMobile)
          Text(
            "${_currentTime.toStringAsFixed(1)}s / ${_videoDuration.toStringAsFixed(1)}s",
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );

    final timeline = SizedBox(
      height: 120,
      child: TimelineWidget(
        captions: project!.captions,
        currentTime: _currentTime,
        maxDuration: _videoDuration,
        selectedCaptionId: _selectedCaptionId,
        onCaptionSelected: (id) { setState(() { _selectedCaptionId = id; }); },
        onTimeChanged: (newTime) { _seekTo(newTime); },
        onCaptionChanged: () { setState(() {}); },
      ),
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 16,
        vertical: isMobile ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgPanel,
        border: Border(top: BorderSide(color: AppColors.border.withOpacity(0.5))),
      ),
      child: isMobile
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                controls,
                const SizedBox(height: 8),
                timeline,
              ],
            )
          : Row(
              children: [
                controls,
                const SizedBox(width: 16),
                Expanded(child: timeline),
              ],
            ),
    );
  }

  Widget _buildInspector() {
    return InspectorWidget(
      selectedCaption: project!.captions.where((c) => c.id == _selectedCaptionId).firstOrNull,
      allCaptions: project!.captions,
      currentTime: _currentTime,
      presets: _presets,
      onCaptionChanged: () { setState(() {}); },
      onCaptionSelected: (id) { setState(() { _selectedCaptionId = id; }); },
      onAddCaption: _addCaption,
      onDeleteCaption: _deleteCaption,
      onSavePreset: _savePreset,
      onApplyPreset: _applyPreset,
    );
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _player.dispose();
    _maskPlayer.dispose();
    if (kIsWeb && _mobileCanvasRegistered) {
      _callMaskCanvasJS('dispose');
    }
    super.dispose();
  }
}

