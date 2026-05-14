import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../models/caption_model.dart';
import '../main.dart';
import 'dart:math' as math;

class TimelineWidget extends StatefulWidget {
  final List<Caption> captions;
  final double currentTime;
  final double maxDuration;
  final String? selectedCaptionId;
  final ValueChanged<String> onCaptionSelected;
  final ValueChanged<double> onTimeChanged;
  final VoidCallback onCaptionChanged;

  const TimelineWidget({super.key, required this.captions, required this.currentTime, required this.maxDuration, required this.selectedCaptionId, required this.onCaptionSelected, required this.onTimeChanged, required this.onCaptionChanged});

  @override
  State<TimelineWidget> createState() => _TimelineWidgetState();
}

class _TimelineWidgetState extends State<TimelineWidget> {
  final int maxTracks = 3;
  final double trackHeight = 34.0;
  double _zoom = 1.0;
  final ScrollController _scrollCtrl = ScrollController();
  bool _isInteracting = false;

  @override
  void dispose() { _scrollCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Zoom
      SizedBox(height: 20, child: Row(children: [
        Icon(Icons.zoom_out_rounded, size: 12, color: AppColors.textMuted),
        SizedBox(width: 80, child: Slider(value: _zoom, min: 1.0, max: 10.0, onChanged: (v) => setState(() => _zoom = v))),
        Icon(Icons.zoom_in_rounded, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text('${_zoom.toStringAsFixed(1)}x', style: TextStyle(color: AppColors.textMuted.withOpacity(0.6), fontSize: 9, fontFamily: 'monospace')),
      ])),
      // Body
      Expanded(child: Listener(
        onPointerSignal: (e) { if (e is PointerScrollEvent) setState(() => _zoom = (_zoom + (e.scrollDelta.dy > 0 ? -0.3 : 0.3)).clamp(1.0, 10.0)); },
        child: LayoutBuilder(builder: (ctx, c) {
          final vw = c.maxWidth > 0 ? c.maxWidth : 800.0;
          return RawScrollbar(controller: _scrollCtrl, thumbColor: AppColors.accent.withOpacity(0.4), radius: const Radius.circular(8), thickness: 5, thumbVisibility: true,
            child: SingleChildScrollView(controller: _scrollCtrl, scrollDirection: Axis.horizontal, physics: _isInteracting ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(), child: _content(vw)));
        }),
      )),
    ]);
  }

  Widget _content(double vw) {
    final tw = vw * _zoom;
    final pps = tw / widget.maxDuration;
    return SizedBox(width: tw, height: maxTracks * trackHeight, child: Stack(clipBehavior: Clip.none, children: [
      // Track lines
      ...List.generate(maxTracks, (i) => Positioned(top: i * trackHeight, left: 0, width: tw, height: trackHeight, child: Container(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.15))))))),
      // Time markers
      ...List.generate(widget.maxDuration.ceil() + 1, (i) => Positioned(left: i * pps, top: 0, bottom: 0, child: Container(width: 1, color: i % 5 == 0 ? AppColors.border.withOpacity(0.4) : AppColors.border.withOpacity(0.1)))),
      // Second labels
      ...List.generate((widget.maxDuration / (_zoom > 3 ? 1 : 5)).ceil() + 1, (i) {
        final s = i * (_zoom > 3 ? 1 : 5);
        if (s > widget.maxDuration) return const SizedBox.shrink();
        return Positioned(left: s * pps + 3, top: 1, child: Text('${s.toStringAsFixed(0)}s', style: TextStyle(color: AppColors.textMuted.withOpacity(0.35), fontSize: 8, fontFamily: 'monospace')));
      }),
      // Captions
      ...widget.captions.map((c) => _block(c, pps)),
      // Playhead glow
      Positioned(left: widget.currentTime * pps - 6, top: 0, bottom: 0, width: 12, child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.playhead.withOpacity(0.0), AppColors.playhead.withOpacity(0.12), AppColors.playhead.withOpacity(0.0)])))),
      // Playhead
      Positioned(left: widget.currentTime * pps, top: 0, bottom: 0, width: 2, child: Container(decoration: BoxDecoration(color: AppColors.playhead, borderRadius: BorderRadius.circular(1), boxShadow: [BoxShadow(color: AppColors.playhead.withOpacity(0.4), blurRadius: 6)]))),
      // Playhead triangle
      Positioned(left: widget.currentTime * pps - 6, top: -1, child: CustomPaint(size: const Size(12, 8), painter: _HeadPainter())),
      // Scrub
      Positioned(top: 0, left: 0, right: 0, height: 28, child: GestureDetector(behavior: HitTestBehavior.opaque, onTapDown: (d) => widget.onTimeChanged((d.localPosition.dx / pps).clamp(0.0, widget.maxDuration)), onHorizontalDragUpdate: (d) => widget.onTimeChanged((d.localPosition.dx / pps).clamp(0.0, widget.maxDuration)), child: Container(color: Colors.transparent))),
    ]));
  }

  Widget _block(Caption c, double pps) {
    final l = c.startTime * pps;
    final w = math.max(8.0, (c.endTime - c.startTime) * pps);
    final t = c.track * trackHeight;
    final sel = widget.selectedCaptionId == c.id;

    return Positioned(left: l, top: t + 3, width: w, height: trackHeight - 6, child: Stack(clipBehavior: Clip.none, children: [
      Positioned.fill(child: Listener(
        onPointerDown: (_) => setState(() => _isInteracting = true),
        onPointerUp: (_) => setState(() => _isInteracting = false),
        onPointerCancel: (_) => setState(() => _isInteracting = false),
        child: GestureDetector(behavior: HitTestBehavior.opaque,
          onTap: () => widget.onCaptionSelected(c.id),
          onPanUpdate: (d) { widget.onCaptionSelected(c.id); double dt = d.delta.dx / pps; double ns = c.startTime + dt; double ne = c.endTime + dt; if (ns < 0) { ne -= ns; ns = 0; } setState(() { c.startTime = ns; c.endTime = ne; }); widget.onCaptionChanged(); },
          child: AnimatedContainer(duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              gradient: sel ? const LinearGradient(colors: [AppColors.accent, AppColors.accentLight]) : LinearGradient(colors: [AppColors.accent.withOpacity(0.55), AppColors.accent.withOpacity(0.35)]),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: sel ? Colors.white.withOpacity(0.5) : AppColors.accent.withOpacity(0.2)),
              boxShadow: sel ? [BoxShadow(color: AppColors.accent.withOpacity(0.25), blurRadius: 8, spreadRadius: -2)] : null),
            padding: const EdgeInsets.symmetric(horizontal: 6), alignment: Alignment.centerLeft,
            child: Text(c.text, overflow: TextOverflow.ellipsis, style: TextStyle(color: sel ? Colors.black : Colors.black.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ),
      )),
      // Resize handles
      if (sel) ...[
        _handle(true, c, pps), _handle(false, c, pps),
      ],
    ]));
  }

  Widget _handle(bool left, Caption c, double pps) {
    return Positioned(
      left: left ? -8 : null, right: left ? null : -8, top: 0, bottom: 0, width: 20,
      child: Listener(
        onPointerDown: (_) => setState(() => _isInteracting = true),
        onPointerUp: (_) => setState(() => _isInteracting = false),
        onPointerCancel: (_) => setState(() => _isInteracting = false),
        child: GestureDetector(behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) {
            double dt = d.delta.dx / pps;
            if (left) { double ns = (c.startTime + dt).clamp(0.0, c.endTime - 0.05); setState(() => c.startTime = ns); }
            else { double ne = c.endTime + dt; if (ne <= c.startTime + 0.05) ne = c.startTime + 0.05; setState(() => c.endTime = ne); }
            widget.onCaptionChanged();
          },
          child: MouseRegion(cursor: SystemMouseCursors.resizeLeftRight, child: Center(child: Container(width: 4, height: 20, decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(2))))),
        ),
      ),
    );
  }
}

class _HeadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = AppColors.playhead..style = PaintingStyle.fill;
    final path = Path()..moveTo(0, 0)..lineTo(size.width, 0)..lineTo(size.width / 2, size.height)..close();
    canvas.drawPath(path, p);
    canvas.drawPath(path, Paint()..color = AppColors.playhead.withOpacity(0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

