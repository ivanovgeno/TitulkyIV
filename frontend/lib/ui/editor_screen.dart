import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:universal_io/io.dart'; // Unified cross platform safe replacement for dart:io
import 'package:universal_html/html.dart' as html; // For web blob creation
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:file_picker/file_picker.dart';
import '../models/caption_model.dart';
import '../services/mock_data_provider.dart';
import 'caption_overlay.dart';
import 'timeline_widget.dart';
import 'inspector_widget.dart';
import '../services/api_service.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
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
  String? _maskBwPath; // B&W grayscale mask URL for mobile canvas compositing
  bool _mobileCanvasRegistered = false;
  final List<CaptionStyle> _presets = [];

  // Media Kit
  late final Player _player;
  late final Player _maskPlayer; // Secondary player for mask
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

    // Listen to player state
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
      // Also sync JS canvas on mobile
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
    
    // Periodic check deactivated for web performance, relies on togglePlay sync
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
        withData: kIsWeb, // Force read bytes on Web
        dialogTitle: 'Vyber video soubor',
      );

    if (result != null && result.files.single.name.isNotEmpty) {
      final file = result.files.single;
      final name = file.name;
      String? sourceToPlay;

      if (kIsWeb) {
        // On Web, generate a blob URL for MediaKit
        if (file.bytes != null) {
          final blob = html.Blob([file.bytes!], 'video/mp4');
          sourceToPlay = html.Url.createObjectUrlFromBlob(blob);
          setState(() {
            _videoBytes = file.bytes;
            _videoName = name;
            _videoPath = sourceToPlay; // Store the playable URL as our main reference
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Chyba: Nepodařilo se načíst data videa z prohlížeče. Zkuste menší soubor.')),
            );
          }
        }
      } else {
        // On Desktop, use local path
        if (file.path != null) {
          sourceToPlay = file.path!;
          // We also read bytes eagerly for upload service
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při nahrávání videa: $e')),
        );
      }
    }
  }

  Future<void> _runTranscription() async {
    print('Button Transkribovat clicked. Path: $_videoPath');
    if (_videoPath == null) return;

    setState(() {
      _isTranscribing = true;
    });

    try {
      final api = ApiService();
      
      if (_videoBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chyba: Nemáme k dispozici data videa k odeslání.')),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nahrávám video do cloudu... Může to trvat několik minut.')),
        );
      }
      
      final projectId = await api.uploadVideoForTranscription(_videoBytes!, _videoName ?? 'video.mp4');
      
      if (projectId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chyba: Nepodařilo se nahrát video na server. Je server online?')),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video úspěšně nahráno! Nyní čekám na dokončení přepisu (AI pracuje)...')),
        );
      }
      
      // Poll for results every 3 seconds
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Přepis úspěšně dokončen a stažen!')),
            );
          }
          completed = true;
        } else {
          print('Stále se zpracovává (pokus $attempts)...');
        }
      }
      
      if (!completed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Časový limit pro přepis vypršel. Server možná stále pracuje.')),
          );
        }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při komunikaci s cloudem: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTranscribing = false;
        });
      }
    }
  }

  void _togglePlay() {
    _player.playOrPause();
  }

  void _seekTo(double time) {
    final pos = Duration(milliseconds: (time * 1000).toInt());
    _player.seek(pos);
    _maskPlayer.seek(pos);
    // Also sync JS canvas on mobile
    if (kIsWeb && _mobileCanvasRegistered) {
      _callMaskCanvasJS('seek', [time.toJS]);
    }
  }

  /// Calls a method on the global MaskCanvas JS object.
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

  /// Sets up the JavaScript Canvas compositing for mobile.
  void _setupMobileCanvas(String originalVideoUrl, String bwMaskUrl) {
    if (!kIsWeb) return;
    try {
      // Call MaskCanvas.create(originalUrl, bwMaskUrl) in JavaScript
      _callMaskCanvasJS('create', [originalVideoUrl.toJS, bwMaskUrl.toJS]);
      
      setState(() {
        _mobileCanvasRegistered = true;
      });
      
      // Sync playback state
      if (_isPlaying) {
        _callMaskCanvasJS('play');
      }
      
      print('Mobile canvas mask setup completed');
    } catch (e) {
      print('Error setting up mobile canvas: $e');
    }
  }

  Future<void> _generateMask() async {
    print('Button Behind Person clicked. Path: $_videoPath');
    if (_videoPath == null) return;
    setState(() => _isMasking = true);

    try {
      final api = ApiService();
      
      if (_videoBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chyba: Nemáme k dispozici data videa k odeslání.')),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nahrávám video pro maskování...')),
        );
      }
      
      final projectId = await api.uploadVideoForMasking(_videoBytes!, _videoName ?? 'video.mp4');
      
      if (projectId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chyba: Nepodařilo se nahrát video na server.')),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Generuji masku (AI model SAM 2 pracuje)... Může to trvat několik minut.')),
        );
      }
      
      // Poll for results every 5 seconds
      bool completed = false;
      int attempts = 0;
      
      while (!completed && attempts < 500 && mounted) {
        await Future.delayed(const Duration(seconds: 5));
        attempts++;
        
        final maskUrls = await api.checkMaskStatus(projectId);
        if (maskUrls != null) {
          final serverUrl = ApiService.baseUrl.replaceAll('/api/v1', '');
          
          // B&W mask URL for mobile canvas compositing
          final bwPath = maskUrls['bw'] ?? '';
          final fullBwUrl = bwPath.isNotEmpty ? '$serverUrl$bwPath' : '';
          
          // Transparent mask for desktop (VP9 alpha WebM or HEVC MOV)
          String maskPathToUse = maskUrls['webm']!;
          if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
            maskPathToUse = maskUrls['mov']!;
          }
          
          final fullMaskUrl = '$serverUrl$maskPathToUse';
          print('Mask generated successfully: $fullMaskUrl');
          print('B&W mask for mobile: $fullBwUrl');
          
          final isMobilePlatform = defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android;
          final isMobileWeb = kIsWeb && (MediaQuery.of(context).size.width < 800 || isMobilePlatform);
          
          setState(() {
            _maskPath = fullMaskUrl;
            _maskBwPath = fullBwUrl;
            _isMasking = false;
          });
          
          if (isMobileWeb && fullBwUrl.isNotEmpty && _videoPath != null) {
            // ── MOBILE: Use JavaScript Canvas compositing ──
            _setupMobileCanvas(_videoPath!, fullBwUrl);
          } else {
            // ── DESKTOP: Use media_kit VP9 alpha video directly ──
            await _maskPlayer.setVolume(0);
            await _maskPlayer.open(Media(fullMaskUrl), play: false); 
            await _maskPlayer.seek(_player.state.position);
            if (_player.state.playing) {
              await _maskPlayer.play();
            }
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Maska úspěšně vygenerována!')),
            );
          }
          completed = true;
        } else {
          print('Stále se generuje maska (pokus $attempts)...');
        }
      }
      
      if (!completed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Časový limit vypršel.')),
        );
      }
    } catch (e) {
      print('Mask generation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při maskování: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isMasking = false);
      }
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
    setState(() {
      _presets.add(style.copy());
    });
  }

  void _applyPreset(CaptionStyle style) {
    if (_selectedCaptionId == null || project == null) return;
    final caption = project!.captions.where((c) => c.id == _selectedCaptionId).firstOrNull;
    if (caption != null) {
      setState(() {
        caption.style = style.copy();
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    if (project == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F0F),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
      );
    }

    final bool isMobile = MediaQuery.of(context).size.width < 800 || 
                          (Theme.of(context).platform == TargetPlatform.iOS || Theme.of(context).platform == TargetPlatform.android);

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text(isMobile ? 'IvC' : 'IvCaptions - Editor', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        actions: isMobile ? [] : [
          IconButton(
            onPressed: _openVideoFile,
            icon: const Icon(Icons.video_file, color: Color(0xFFD4AF37)),
            tooltip: 'Nahrát video',
          ),
          TextButton(
            onPressed: _openVideoFile,
            child: Text(_videoName ?? 'Nahrát', style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
          if (_videoPath != null) ...[
            _isTranscribing
                ? const Padding(padding: EdgeInsets.all(8.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4AF37))))
                : IconButton(
                    onPressed: _runTranscription,
                    icon: const Icon(Icons.subtitles, color: Color(0xFFD4AF37)),
                    tooltip: 'Transkribovat',
                  ),
            if (!_isTranscribing)
              TextButton(
                onPressed: _runTranscription,
                child: const Text('Transkribovat', style: TextStyle(color: Colors.white)),
              ),
            const SizedBox(width: 8),
            _isMasking
                ? const Padding(padding: EdgeInsets.all(8.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4AF37))))
                : IconButton(
                    onPressed: _generateMask,
                    icon: const Icon(Icons.person_search, color: Color(0xFFD4AF37)),
                    tooltip: 'Behind Person Mask',
                  ),
            if (!_isMasking)
              TextButton(
                onPressed: _generateMask,
                child: const Text('Maska', style: TextStyle(color: Colors.white)),
              ),
            if (_maskPath != null)
              IconButton(
                icon: const Icon(Icons.layers_clear, color: Colors.redAccent),
                tooltip: 'Odstranit masku',
                onPressed: () {
                  setState(() {
                    _maskPath = null;
                    _maskPlayer.pause();
                  });
                },
              ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Video Preview takes up remaining space
        Expanded(
          child: Container(
            color: Colors.black,
            child: _buildVideoPreview(),
          ),
        ),
        
        // Mobile Action Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF0F0F0F),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMobileActionBtn(Icons.video_file, 'Nahrát', _openVideoFile),
              if (_videoPath != null) ...[
                _isTranscribing 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4AF37)))
                    : _buildMobileActionBtn(Icons.subtitles, 'Přepis', _runTranscription),
                _isMasking 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4AF37)))
                    : _buildMobileActionBtn(Icons.person_search, 'Maska', _generateMask),
                if (_maskPath != null)
                  _buildMobileActionBtn(Icons.layers_clear, 'Zrušit', () {
                    setState(() { _maskPath = null; _maskPlayer.pause(); });
                  }, color: Colors.redAccent),
              ],
            ],
          ),
        ),

        // Timeline and Inspector Tabs (reduced height)
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.35,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF151515),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    indicatorColor: Color(0xFFD4AF37),
                    labelColor: Color(0xFFD4AF37),
                    unselectedLabelColor: Colors.white54,
                    dividerColor: Colors.transparent,
                    labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    tabs: [
                      Tab(text: 'Timeline', iconMargin: EdgeInsets.zero),
                      Tab(text: 'Inspektor', iconMargin: EdgeInsets.zero),
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

  Widget _buildMobileActionBtn(IconData icon, String label, VoidCallback onTap, {Color color = const Color(0xFFD4AF37)}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 10, height: 1.1), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildVideoPreview(),
                ),
              ),
              _buildTimeline(isMobile: false),
            ],
          ),
        ),
        SizedBox(
          width: 360,
          child: _buildInspector(),
        ),
      ],
    );
  }

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
              borderRadius: BorderRadius.circular(isMobile ? 0 : 12),
              border: isMobile ? null : Border.all(color: const Color(0xFF2A2A35), width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isMobile ? 0 : 10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_videoPath != null)
                    Video(
                      controller: _videoController,
                      controls: NoVideoControls,
                    )
                  else
                    Material(
                      color: const Color(0xFF111116),
                      child: InkWell(
                        onTap: _openVideoFile,
                        hoverColor: Colors.white.withOpacity(0.03),
                        splashColor: const Color(0xFFD4AF37).withOpacity(0.1),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload_rounded, size: 72, color: Color(0xFFD4AF37)),
                              SizedBox(height: 16),
                              Text(
                                "Klikněte zde pro nahrání videa",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "MP4, MOV nebo WebM",
                                style: TextStyle(color: Colors.white38, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  CaptionOverlay(
                    captions: project!.captions.where((c) => c.style.behindPerson).toList(),
                    currentTime: _currentTime,
                    resolution: project!.resolution,
                    selectedCaptionId: _selectedCaptionId,
                    onCaptionSelected: (id) {
                      setState(() { _selectedCaptionId = id; });
                    },
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
                  // Mobile: JS Canvas composited mask (pixel-level alpha transparency)
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
                                // Pass the root element wrapper into JS side appending logic safely
                                appendToFn.callAsFunction(mc, element as JSAny);
                                print('MaskCanvas: attached safely via JS appendTo');
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
                    onCaptionSelected: (id) {
                      setState(() { _selectedCaptionId = id; });
                    },
                    onCaptionUpdate: () { setState(() {}); },
                  ),
                  if (isMobile && _videoPath != null && !_isPlaying)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black26,
                        child: const Center(
                          child: Icon(Icons.play_arrow_rounded, size: 80, color: Colors.white70),
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

  Widget _buildTimeline({required bool isMobile}) {
    final controls = Row(
      children: [
        IconButton(
          icon: Icon(
            _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            size: isMobile ? 36 : 48,
            color: const Color(0xFFD4AF37),
          ),
          onPressed: _videoPath != null ? _togglePlay : null,
        ),
        const SizedBox(width: 8),
        Text(
          "${_currentTime.toStringAsFixed(1)}s / ${_videoDuration.toStringAsFixed(1)}s",
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 14 : 18,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
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
        onCaptionSelected: (id) {
          setState(() {
            _selectedCaptionId = id;
          });
        },
        onTimeChanged: (newTime) {
          _seekTo(newTime);
        },
        onCaptionChanged: () {
          setState(() {});
        },
      ),
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 24, 
        vertical: isMobile ? 8 : 12
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        border: Border(top: BorderSide(color: Color(0xFF222222))),
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
    // Clean up JS canvas resources
    if (kIsWeb && _mobileCanvasRegistered) {
      _callMaskCanvasJS('dispose');
    }
    super.dispose();
  }
}



