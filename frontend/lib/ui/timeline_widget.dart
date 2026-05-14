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

  const TimelineWidget({
    super.key,
    required this.captions,
    required this.currentTime,
    required this.maxDuration,
    required this.selectedCaptionId,
    required this.onCaptionSelected,
    required this.onTimeChanged,
    required this.onCaptionChanged,
  });

  @override
  State<TimelineWidget> createState() => _TimelineWidgetState();
}

class _TimelineWidgetState extends State<TimelineWidget> {
  final int maxTracks = 3;
  final double trackHeight = 36.0;
  double _zoom = 1.0;
  final ScrollController _scrollCtrl = ScrollController();

  String? _resizingId;
  bool _resizingLeft = false;
  bool _isInteracting = false;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Zoom controls
        SizedBox(
          height: 22,
          child: Row(
            children: [
              Icon(Icons.zoom_out_rounded, size: 14, color: AppColors.textMuted),
              SizedBox(
                width: 100,
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppColors.accent,
                    inactiveTrackColor: AppColors.border,
                    thumbColor: AppColors.accent,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    trackHeight: 2,
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: _zoom,
                    min: 1.0,
                    max: 10.0,
                    onChanged: (v) => setState(() => _zoom = v),
                  ),
                ),
              ),
              Icon(Icons.zoom_in_rounded, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_zoom.toStringAsFixed(1)}x',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),

        // Timeline body
        Expanded(
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                setState(() {
                  _zoom = (_zoom + (event.scrollDelta.dy > 0 ? -0.3 : 0.3)).clamp(1.0, 10.0);
                });
              }
            },
            child: LayoutBuilder(
              builder: (context, outerConstraints) {
                final viewportWidth = outerConstraints.maxWidth > 0 ? outerConstraints.maxWidth : 800.0;
                return RawScrollbar(
                  controller: _scrollCtrl,
                  thumbColor: AppColors.accent.withOpacity(0.5),
                  radius: const Radius.circular(8),
                  thickness: 6,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _scrollCtrl,
                    scrollDirection: Axis.horizontal,
                    physics: _isInteracting ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
                    child: _buildTimelineContent(viewportWidth),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineContent(double viewportWidth) {
    final totalWidth = viewportWidth * _zoom;
    final pps = totalWidth / widget.maxDuration;

    return SizedBox(
      width: totalWidth,
      height: maxTracks * trackHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Track backgrounds
          ...List.generate(maxTracks, (i) => Positioned(
            top: i * trackHeight,
            left: 0,
            width: totalWidth,
            height: trackHeight,
            child: Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.3))),
              ),
            ),
          )),

          // Time markers
          ...List.generate(
            widget.maxDuration.ceil() + 1,
            (i) => Positioned(
              left: i * pps,
              top: 0,
              bottom: 0,
              child: Container(
                width: 1,
                color: i % 5 == 0
                    ? AppColors.border.withOpacity(0.6)
                    : AppColors.border.withOpacity(0.2),
              ),
            ),
          ),

          // Second labels
          ...List.generate(
            (widget.maxDuration / (_zoom > 3 ? 1 : 5)).ceil() + 1,
            (i) {
              final sec = i * (_zoom > 3 ? 1 : 5);
              if (sec > widget.maxDuration) return const SizedBox.shrink();
              return Positioned(
                left: sec * pps + 3,
                top: 1,
                child: Text(
                  '${sec.toStringAsFixed(0)}s',
                  style: TextStyle(color: AppColors.textMuted.withOpacity(0.5), fontSize: 9, fontFamily: 'monospace'),
                ),
              );
            },
          ),

          // Caption blocks
          ...widget.captions.map((c) => _buildCaptionBlock(c, pps)),

          // Playhead glow
          Positioned(
            left: widget.currentTime * pps - 4,
            top: 0,
            bottom: 0,
            width: 8,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.playhead.withOpacity(0.0),
                    AppColors.playhead.withOpacity(0.15),
                    AppColors.playhead.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // Playhead line
          Positioned(
            left: widget.currentTime * pps,
            top: 0,
            bottom: 0,
            width: 2,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.playhead,
                borderRadius: BorderRadius.circular(1),
                boxShadow: [
                  BoxShadow(color: AppColors.playhead.withOpacity(0.5), blurRadius: 6),
                ],
              ),
            ),
          ),

          // Playhead head (triangle)
          Positioned(
            left: (widget.currentTime * pps) - 7,
            top: -2,
            child: CustomPaint(
              size: const Size(14, 10),
              painter: _PlayheadPainter(),
            ),
          ),

          // Scrubbing area
          Positioned(
            top: 0, left: 0, right: 0, height: 28,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                double newTime = d.localPosition.dx / pps;
                widget.onTimeChanged(newTime.clamp(0.0, widget.maxDuration));
              },
              onHorizontalDragUpdate: (d) {
                double newTime = d.localPosition.dx / pps;
                widget.onTimeChanged(newTime.clamp(0.0, widget.maxDuration));
              },
              child: Container(color: Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptionBlock(Caption caption, double pps) {
    final double left = caption.startTime * pps;
    final double width = math.max(8.0, (caption.endTime - caption.startTime) * pps);
    final double top = caption.track * trackHeight;
    final bool selected = widget.selectedCaptionId == caption.id;

    const double touchHandleW = 24.0;
    const double visualHandleW = 5.0;

    return Positioned(
      left: left,
      top: top + 3,
      width: width,
      height: trackHeight - 6,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main block body
          Positioned.fill(
            child: Listener(
              onPointerDown: (_) => setState(() => _isInteracting = true),
              onPointerUp: (_) => setState(() => _isInteracting = false),
              onPointerCancel: (_) => setState(() => _isInteracting = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onCaptionSelected(caption.id),
                onPanUpdate: (details) {
                  widget.onCaptionSelected(caption.id);
                  double dt = details.delta.dx / pps;
                  double ns = caption.startTime + dt;
                  double ne = caption.endTime + dt;
                  if (ns < 0) { ne -= ns; ns = 0; }
                  setState(() { caption.startTime = ns; caption.endTime = ne; });
                  widget.onCaptionChanged();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(colors: [AppColors.accent, AppColors.accentLight])
                        : LinearGradient(colors: [AppColors.accent.withOpacity(0.7), AppColors.accent.withOpacity(0.5)]),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: selected ? Colors.white.withOpacity(0.6) : AppColors.accent.withOpacity(0.3),
                      width: selected ? 1.5 : 1,
                    ),
                    boxShadow: selected ? [
                      BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 8, spreadRadius: -2),
                    ] : null,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    caption.text,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.black : Colors.black.withOpacity(0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Left resize handle
          if (selected) Positioned(
            left: -touchHandleW / 3,
            top: 0, bottom: 0, width: touchHandleW,
            child: Listener(
              onPointerDown: (_) => setState(() => _isInteracting = true),
              onPointerUp: (_) => setState(() => _isInteracting = false),
              onPointerCancel: (_) => setState(() => _isInteracting = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) {
                  double dt = d.delta.dx / pps;
                  double ns = caption.startTime + dt;
                  if (ns < 0) ns = 0;
                  if (ns >= caption.endTime - 0.05) ns = caption.endTime - 0.05;
                  setState(() => caption.startTime = ns);
                  widget.onCaptionChanged();
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: Container(
                    color: Colors.transparent,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: visualHandleW,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Right resize handle
          if (selected) Positioned(
            right: -touchHandleW / 3,
            top: 0, bottom: 0, width: touchHandleW,
            child: Listener(
              onPointerDown: (_) => setState(() => _isInteracting = true),
              onPointerUp: (_) => setState(() => _isInteracting = false),
              onPointerCancel: (_) => setState(() => _isInteracting = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) {
                  double dt = d.delta.dx / pps;
                  double ne = caption.endTime + dt;
                  if (ne <= caption.startTime + 0.05) ne = caption.startTime + 0.05;
                  setState(() => caption.endTime = ne);
                  widget.onCaptionChanged();
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: Container(
                    color: Colors.transparent,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: visualHandleW,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayheadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.playhead
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);

    // Glow effect
    final glowPaint = Paint()
      ..color = AppColors.playhead.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

