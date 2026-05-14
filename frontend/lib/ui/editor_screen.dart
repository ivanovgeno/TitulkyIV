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
    _maskController = VideoController(_maskPlayer, configuration: const VideoControllerConfiguration(enableHardwareAcceleration: false));

    _player.stream.duration.listen((d) {
      if (d.inMilliseconds > 0) setState(() => _videoDuration = d.inMilliseconds / 1000.0);
    });
    _player.stream.playing.listen((playing) {
      setState(() => _isPlaying = playing);
      playing ? _maskPlayer.play() : _maskPlayer.pause();
      if (kIsWeb && _mobileCanvasRegistered) _callMaskCanvasJS('setPlaying', [playing.toJS]);
    });
    _player.stream.position.listen((p) {
      setState(() => _currentTime = p.inMilliseconds / 1000.0);
    });
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await MockDataProvider.loadMockProject();
    setState(() => project = data);
  }

  // ── File picking ──
  Future<void> _openVideoFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: false, withData: kIsWeb, dialogTitle: 'Vyber video');
      if (result != null && result.files.single.name.isNotEmpty) {
        final file = result.files.single;
        String? sourceToPlay;
        if (kIsWeb) {
          if (file.bytes != null) {
            final blob = html.Blob([file.bytes!], 'video/mp4');
            sourceToPlay = html.Url.createObjectUrlFromBlob(blob);
            setState(() { _videoBytes = file.bytes; _videoName = file.name; _videoPath = sourceToPlay; });
          } else { _snack('Chyba: Nepodařilo se načíst video.'); }
        } else {
          if (file.path != null) {
            sourceToPlay = file.path!;
            final bytes = await File(sourceToPlay).readAsBytes();
            setState(() { _videoPath = sourceToPlay; _videoName = file.name; _videoBytes = bytes; });
          }
        }
        if (sourceToPlay != null) { await _player.open(Media(sourceToPlay)); await _player.pause(); }
      }
    } catch (e) { _snack('Chyba: $e'); }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 13)),
      backgroundColor: AppColors.bgElevated,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Transcription ──
  Future<void> _runTranscription() async {
    if (_videoPath == null || _videoBytes == null) return;
    setState(() => _isTranscribing = true);
    try {
      final api = ApiService();
      _snack('Nahrávám video...');
      final pid = await api.uploadVideoForTranscription(_videoBytes!, _videoName ?? 'video.mp4');
      if (pid == null) { _snack('Chyba nahrávání.'); return; }
      _snack('Přepisuji...');
      for (int i = 0; i < 500 && mounted; i++) {
        await Future.delayed(const Duration(seconds: 3));
        final r = await api.checkTranscriptionStatus(pid);
        if (r != null) { setState(() { project = r; _selectedCaptionId = null; _isTranscribing = false; }); _snack('Přepis hotov!'); return; }
      }
      _snack('Časový limit.');
    } catch (e) { _snack('Chyba: $e'); } finally { if (mounted) setState(() => _isTranscribing = false); }
  }

  // ── Mask ──
  Future<void> _generateMask() async {
    if (_videoPath == null || _videoBytes == null) return;
    setState(() => _isMasking = true);
    try {
      final api = ApiService();
      _snack('Nahrávám pro masku...');
      final pid = await api.uploadVideoForMasking(_videoBytes!, _videoName ?? 'video.mp4');
      if (pid == null) { _snack('Chyba.'); return; }
      _snack('Generuji masku...');
      for (int i = 0; i < 500 && mounted; i++) {
        await Future.delayed(const Duration(seconds: 5));
        final urls = await api.checkMaskStatus(pid);
        if (urls != null) {
          final srv = ApiService.baseUrl.replaceAll('/api/v1', '');
          final bw = urls['bw'] ?? '';
          final fullBw = bw.isNotEmpty ? '$srv$bw' : '';
          String mp = urls['webm']!;
          if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) mp = urls['mov']!;
          final fullMask = '$srv$mp';
          final mob = kIsWeb && (MediaQuery.of(context).size.width < 800 || defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);
          setState(() { _maskPath = fullMask; _maskBwPath = fullBw; _isMasking = false; });
          if (mob && fullBw.isNotEmpty && _videoPath != null) { _setupMobileCanvas(_videoPath!, fullBw); }
          else { await _maskPlayer.setVolume(0); await _maskPlayer.open(Media(fullMask), play: false); await _maskPlayer.seek(_player.state.position); if (_player.state.playing) await _maskPlayer.play(); }
          _snack('Maska hotova!');
          return;
        }
      }
      _snack('Časový limit.');
    } catch (e) { _snack('Chyba: $e'); } finally { if (mounted) setState(() => _isMasking = false); }
  }

  void _togglePlay() {
    if (_videoPath != null) {
      _player.playOrPause();
    } else {
      // No video: simulate playback with timer for caption preview
      setState(() => _isPlaying = !_isPlaying);
      if (_isPlaying) {
        _syncTimer?.cancel();
        _syncTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
          if (!mounted || !_isPlaying) { _syncTimer?.cancel(); return; }
          setState(() {
            _currentTime += 0.033;
            if (_currentTime > _videoDuration) _currentTime = 0;
          });
        });
      } else {
        _syncTimer?.cancel();
      }
    }
  }
  void _seekTo(double t) {
    setState(() => _currentTime = t.clamp(0, _videoDuration));
    if (_videoPath != null) {
      final p = Duration(milliseconds: (t * 1000).toInt());
      _player.seek(p); _maskPlayer.seek(p);
    }
    if (kIsWeb && _mobileCanvasRegistered) _callMaskCanvasJS('seek', [t.toJS]);
  }

  void _callMaskCanvasJS(String method, [List<JSAny?>? args]) {
    if (!kIsWeb) return;
    try {
      final mc = globalContext.getProperty('MaskCanvas'.toJS);
      if (mc == null || mc.isUndefinedOrNull) return;
      final fn = (mc as JSObject).getProperty(method.toJS);
      if (fn == null || fn.isUndefinedOrNull) return;
      final jsFn = fn as JSFunction;
      if (args == null || args.isEmpty) jsFn.callAsFunction(mc);
      else if (args.length == 1) jsFn.callAsFunction(mc, args[0]);
      else jsFn.callAsFunction(mc, args[0], args[1]);
    } catch (e) { print('JS err ($method): $e'); }
  }

  void _setupMobileCanvas(String vid, String bw) {
    if (!kIsWeb) return;
    try { _callMaskCanvasJS('create', [vid.toJS, bw.toJS]); setState(() => _mobileCanvasRegistered = true); if (_isPlaying) _callMaskCanvasJS('play'); } catch (e) { print('Canvas err: $e'); }
  }

  void _addCaption() {
    if (project == null) return;
    final c = Caption(id: 'word_${project!.captions.length.toString().padLeft(4, '0')}', text: 'Nový titulek', startTime: _currentTime, endTime: _currentTime + 1.0, category: 'Main', style: CaptionStyle(), transform3D: Transform3D(position: {'x': project!.resolution.width / 2, 'y': project!.resolution.height / 2, 'z': 0}, rotation: {'x': 0.0, 'y': 0.0, 'z': 0.0}, meshBendEnabled: false));
    setState(() { project!.captions.add(c); _selectedCaptionId = c.id; });
  }
  void _deleteCaption() { if (project == null || _selectedCaptionId == null) return; setState(() { project!.captions.removeWhere((c) => c.id == _selectedCaptionId); _selectedCaptionId = null; }); }
  void _savePreset(CaptionStyle s) => setState(() => _presets.add(s.copy()));
  void _applyPreset(CaptionStyle s) {
    if (_selectedCaptionId == null || project == null) return;
    final c = project!.captions.where((c) => c.id == _selectedCaptionId).firstOrNull;
    if (c != null) setState(() => c.style = s.copy());
  }

  bool get _isMobile => MediaQuery.of(context).size.width < 800;

  // ══════════════════ BUILD ══════════════════

  @override
  Widget build(BuildContext context) {
    if (project == null) return Scaffold(backgroundColor: AppColors.bg, body: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)));
    return Scaffold(backgroundColor: AppColors.bg, body: _isMobile ? _mobileLayout() : _desktopLayout());
  }

  // ══════════════════ DESKTOP ══════════════════

  Widget _desktopLayout() {
    return Row(children: [
      _sidebar(),
      Expanded(child: Column(children: [
        _topBar(),
        Expanded(child: Row(children: [
          Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 8, 8), child: _videoPreview())),
          if (!_inspectorCollapsed) SizedBox(width: 340, child: _inspector()),
        ])),
        _timelineSection(mobile: false),
      ])),
    ]);
  }

  Widget _sidebar() {
    return Container(
      width: 54,
      decoration: BoxDecoration(color: AppColors.bgPanel, border: Border(right: BorderSide(color: AppColors.border.withOpacity(0.3)))),
      child: Column(children: [
        const SizedBox(height: 14),
        _brandLogo(32),
        const SizedBox(height: 24),
        _sideIcon(Icons.movie_outlined, 'Nahrát', _openVideoFile, active: _videoPath != null),
        _sideIcon(Icons.subtitles_outlined, 'Přepis', _videoPath != null ? _runTranscription : null, loading: _isTranscribing),
        _sideIcon(Icons.person_outline, 'Maska', _videoPath != null ? _generateMask : null, loading: _isMasking),
        if (_maskPath != null) _sideIcon(Icons.layers_clear_outlined, 'Zrušit', () => setState(() { _maskPath = null; _maskPlayer.pause(); }), color: AppColors.danger),
        const Spacer(),
        _sideIcon(_inspectorCollapsed ? Icons.chevron_left : Icons.chevron_right, 'Panel', () => setState(() => _inspectorCollapsed = !_inspectorCollapsed)),
        const SizedBox(height: 14),
      ]),
    );
  }

  Widget _brandLogo(double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accentLight], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(size * 0.28)),
      child: Center(child: Text('IV', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: size * 0.38))),
    );
  }

  Widget _sideIcon(IconData icon, String tip, VoidCallback? onTap, {bool active = false, bool loading = false, Color? color}) {
    return Tooltip(message: tip, preferBelow: false, child: Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: InkWell(
      onTap: loading ? null : onTap, borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(duration: const Duration(milliseconds: 180), width: 38, height: 38,
        decoration: BoxDecoration(color: active ? AppColors.accent.withOpacity(0.12) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: active ? Border.all(color: AppColors.accent.withOpacity(0.25)) : null),
        child: Center(child: loading ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)) : Icon(icon, size: 19, color: onTap == null ? AppColors.textMuted.withOpacity(0.4) : (color ?? (active ? AppColors.accent : AppColors.textSecondary)))),
      ),
    )));
  }

  Widget _topBar() {
    return Container(
      height: 46, padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: AppColors.bgPanel, border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.3)))),
      child: Row(children: [
        const Text('IvCaptions', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.3)),
        if (_videoName != null) ...[
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.chevron_right, size: 14, color: AppColors.textMuted)),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(6)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.videocam_outlined, size: 13, color: AppColors.accent), const SizedBox(width: 5), Text(_videoName!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))])),
        ],
        const Spacer(),
        _timePill(),
      ]),
    );
  }

  Widget _timePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border.withOpacity(0.4))),
      child: Text("${_currentTime.toStringAsFixed(1)}s / ${_videoDuration.toStringAsFixed(1)}s", style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
    );
  }

  // ══════════════════ MOBILE ══════════════════

  Widget _mobileLayout() {
    return SafeArea(child: Column(children: [
      // Minimal status bar
      Container(
        height: 38, padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: AppColors.bgPanel, border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.2)))),
        child: Row(children: [
          _brandLogo(22),
          const SizedBox(width: 8),
          if (_videoPath != null) ...[
            _chipBtn(Icons.subtitles_outlined, 'Přepis', _runTranscription, loading: _isTranscribing),
            const SizedBox(width: 4),
            _chipBtn(Icons.person_outline, 'Maska', _generateMask, loading: _isMasking),
            if (_maskPath != null) ...[const SizedBox(width: 4), _chipBtn(Icons.layers_clear_outlined, 'X', () => setState(() { _maskPath = null; _maskPlayer.pause(); }), color: AppColors.danger)],
          ] else ...[
            _chipBtn(Icons.movie_outlined, 'Nahrát video', _openVideoFile),
          ],
          const Spacer(),
          Text("${_currentTime.toStringAsFixed(1)}s", style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontFamily: 'monospace')),
        ]),
      ),
      // Video (compact)
      Expanded(flex: 5, child: Stack(children: [
        Container(color: Colors.black, child: _videoPreview()),
        // Floating play pill
        if (_videoPath != null) Positioned(left: 0, right: 0, bottom: 6, child: Center(child: GestureDetector(
          onTap: _togglePlay,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.1))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 18, color: Colors.white.withOpacity(0.9)),
              const SizedBox(width: 6),
              Text("${_currentTime.toStringAsFixed(1)}s", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, fontFamily: 'monospace')),
            ]),
          ),
        ))),
      ])),
      // Editor area (takes majority of space)
      Expanded(flex: 7, child: Container(
        decoration: BoxDecoration(color: AppColors.bgPanel, borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), border: Border(top: BorderSide(color: AppColors.border.withOpacity(0.3)))),
        child: DefaultTabController(length: 2, child: Column(children: [
          // Drag handle
          Center(child: Container(margin: const EdgeInsets.only(top: 6, bottom: 2), width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
          // Tabs
          SizedBox(height: 32, child: TabBar(
            indicatorColor: AppColors.accent, indicatorWeight: 2, indicatorSize: TabBarIndicatorSize.label,
            labelColor: AppColors.accent, unselectedLabelColor: AppColors.textMuted, dividerColor: Colors.transparent,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), labelPadding: EdgeInsets.zero,
            tabs: const [Tab(text: 'Timeline', height: 30), Tab(text: 'Inspektor', height: 30)],
          )),
          Expanded(child: TabBarView(children: [_timelineSection(mobile: true), _inspector()])),
        ])),
      )),
      // FAB for add caption
    ]));
  }

  Widget _chipBtn(IconData icon, String label, VoidCallback onTap, {bool loading = false, Color color = AppColors.accent}) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: loading
            ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: color))
            : Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: color), const SizedBox(width: 3), Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600))]),
      ),
    );
  }

  // ══════════════════ VIDEO PREVIEW ══════════════════

  Widget _videoPreview() {
    return Center(child: GestureDetector(
      onTap: () {
        if (_videoPath == null) { _openVideoFile(); return; }
        if (!_isMobile) _togglePlay();
      },
      child: AspectRatio(
        aspectRatio: project!.resolution.width / project!.resolution.height,
        child: Container(
          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(_isMobile ? 0 : 14), border: _isMobile ? null : Border.all(color: AppColors.border.withOpacity(0.3)), boxShadow: _isMobile ? null : [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, spreadRadius: -8)]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_isMobile ? 0 : 13),
            child: Stack(fit: StackFit.expand, children: [
              if (_videoPath != null) Video(controller: _videoController, controls: NoVideoControls)
              else _uploadPrompt(),
              CaptionOverlay(captions: project!.captions.where((c) => c.style.behindPerson).toList(), currentTime: _currentTime, resolution: project!.resolution, selectedCaptionId: _selectedCaptionId, onCaptionSelected: (id) => setState(() => _selectedCaptionId = id), onCaptionUpdate: () => setState(() {})),
              if (_maskPath != null && !(_mobileCanvasRegistered && _isMobile)) IgnorePointer(child: Video(controller: _maskController, controls: NoVideoControls, fill: Colors.transparent)),
              if (_mobileCanvasRegistered && _isMobile) IgnorePointer(child: HtmlElementView.fromTagName(tagName: 'div', onElementCreated: (el) { try { final mc = globalContext.getProperty('MaskCanvas'.toJS) as JSObject?; if (mc != null) { final fn = mc.getProperty('appendTo'.toJS) as JSFunction?; fn?.callAsFunction(mc, el as JSAny); } } catch (e) { print('Attach err: $e'); } })),
              CaptionOverlay(captions: project!.captions.where((c) => !c.style.behindPerson).toList(), currentTime: _currentTime, resolution: project!.resolution, selectedCaptionId: _selectedCaptionId, onCaptionSelected: (id) => setState(() => _selectedCaptionId = id), onCaptionUpdate: () => setState(() {})),
            ]),
          ),
        ),
      ),
    ));
  }

  Widget _uploadPrompt() {
    return Material(color: AppColors.bgCard, child: InkWell(
      onTap: _openVideoFile, hoverColor: AppColors.bgHover, splashColor: AppColors.accent.withOpacity(0.08),
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 64, height: 64, decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.08), shape: BoxShape.circle, border: Border.all(color: AppColors.accent.withOpacity(0.2), width: 1.5)),
          child: const Icon(Icons.add_rounded, size: 28, color: AppColors.accent)),
        const SizedBox(height: 14),
        const Text("Nahrát video", style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text("MP4, MOV, WebM", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ])),
    ));
  }

  // ══════════════════ TIMELINE ══════════════════

  Widget _timelineSection({required bool mobile}) {
    final playBtn = GestureDetector(
      onTap: _videoPath != null ? _togglePlay : null,
      child: Container(
        width: mobile ? 36 : 40, height: mobile ? 36 : 40,
        decoration: BoxDecoration(
          gradient: _videoPath != null ? const LinearGradient(colors: [AppColors.accent, AppColors.accentLight]) : null,
          color: _videoPath == null ? AppColors.bgCard : null, borderRadius: BorderRadius.circular(11),
          boxShadow: _videoPath != null ? [BoxShadow(color: AppColors.accent.withOpacity(0.2), blurRadius: 10)] : null),
        child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: mobile ? 20 : 22, color: _videoPath != null ? Colors.black : AppColors.textMuted),
      ),
    );

    final tl = Expanded(child: SizedBox(height: 110, child: TimelineWidget(
      captions: project!.captions, currentTime: _currentTime, maxDuration: _videoDuration, selectedCaptionId: _selectedCaptionId,
      onCaptionSelected: (id) => setState(() => _selectedCaptionId = id), onTimeChanged: _seekTo, onCaptionChanged: () => setState(() {}),
    )));

    return Container(
      padding: EdgeInsets.symmetric(horizontal: mobile ? 6 : 14, vertical: mobile ? 6 : 8),
      decoration: BoxDecoration(color: AppColors.bgPanel, border: Border(top: BorderSide(color: AppColors.border.withOpacity(0.2)))),
      child: mobile
          ? Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [playBtn, const SizedBox(width: 8), _timePill(), const Spacer(), _addCaptionBtn()]),
              const SizedBox(height: 6), SizedBox(height: 110, child: TimelineWidget(captions: project!.captions, currentTime: _currentTime, maxDuration: _videoDuration, selectedCaptionId: _selectedCaptionId, onCaptionSelected: (id) => setState(() => _selectedCaptionId = id), onTimeChanged: _seekTo, onCaptionChanged: () => setState(() {}))),
            ])
          : Row(children: [playBtn, const SizedBox(width: 10), _addCaptionBtn(), const SizedBox(width: 12), tl]),
    );
  }

  Widget _addCaptionBtn() {
    return GestureDetector(
      onTap: _addCaption,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.accent.withOpacity(0.3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_rounded, size: 14, color: AppColors.accent), const SizedBox(width: 4), Text('Titulek', style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w600))]),
      ),
    );
  }

  Widget _inspector() {
    return InspectorWidget(
      selectedCaption: project!.captions.where((c) => c.id == _selectedCaptionId).firstOrNull,
      allCaptions: project!.captions, currentTime: _currentTime, presets: _presets,
      onCaptionChanged: () => setState(() {}), onCaptionSelected: (id) => setState(() => _selectedCaptionId = id),
      onAddCaption: _addCaption, onDeleteCaption: _deleteCaption, onSavePreset: _savePreset, onApplyPreset: _applyPreset,
    );
  }

  @override
  void dispose() {
    _syncTimer?.cancel(); _player.dispose(); _maskPlayer.dispose();
    if (kIsWeb && _mobileCanvasRegistered) _callMaskCanvasJS('dispose');
    super.dispose();
  }
}




