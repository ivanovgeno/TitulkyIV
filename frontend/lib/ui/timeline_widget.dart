import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../models/caption_model.dart';
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

  // Resize state
  String? _resizingId;
  bool _resizingLeft = false;
  bool _isInteracting = false; // Track active thumb/drag gestures to lock scrollview

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
        // Zoom controls row
        SizedBox(
          height: 20,
          child: Row(
            children: [
              const Icon(Icons.zoom_out, size: 14, color: Colors.white38),
              SizedBox(
                width: 100,
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: const Color(0xFFD4AF37),
                    inactiveTrackColor: const Color(0xFF333333),
                    thumbColor: const Color(0xFFD4AF37),
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
              const Icon(Icons.zoom_in, size: 14, color: Colors.white38),
              const SizedBox(width: 8),
              Text('${_zoom.toStringAsFixed(1)}x', style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace')),
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
                  thumbColor: const Color(0xFFD4AF37),
                  radius: const Radius.circular(8),
                  thickness: 8,
                  thumbVisibility: true, // Always visible
                  child: SingleChildScrollView(
                    controller: _scrollCtrl,
                    scrollDirection: Axis.horizontal,
                    // Lock scrolling immediately when dragging/resizing a caption block!
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
            // Track backgrounds + time rulers
            ...List.generate(maxTracks, (i) => Positioned(
              top: i * trackHeight,
              left: 0,
              width: totalWidth,
              height: trackHeight,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
                ),
              ),
            )),

            // Time markers (every second)
            ...List.generate(
              widget.maxDuration.ceil() + 1,
              (i) => Positioned(
                left: i * pps,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 1,
                  color: i % 5 == 0 ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.05),
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
                  left: sec * pps + 2,
                  top: 1,
                  child: Text('${sec.toStringAsFixed(0)}s', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 9, fontFamily: 'monospace')),
                );
              },
            ),

            // Caption blocks
            ...widget.captions.map((c) => _buildCaptionBlock(c, pps)),

            // Playhead
            Positioned(
              left: widget.currentTime * pps,
              top: 0,
              bottom: 0,
              width: 2,
              child: Container(color: Colors.redAccent),
            ),
            Positioned(
              left: (widget.currentTime * pps) - 6,
              top: -2,
              child: CustomPaint(
                size: const Size(12, 10),
                painter: _PlayheadPainter(),
              ),
            ),
            // Dedicated scrubbing area (Top strip)
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
    
    // Generous invisible 24px touch targets for mobile thumbs
    const double touchHandleW = 24.0;
    // High-contrast visual indicator
    const double visualHandleW = 6.0;

    return Positioned(
      left: left,
      top: top + 2,
      width: width,
      height: trackHeight - 4,
      child: Stack(
        clipBehavior: Clip.none, // Allow large touch targets to expand outside boundaries
        children: [
          // Main block body (draggable)
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
                child: Container(
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFFFD700) : const Color(0xFFD4AF37).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: selected ? Colors.white : const Color(0xFFFFE066), width: selected ? 2 : 1),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    caption.text,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),

          // Left resize handle
          if (selected) Positioned(
            left: -touchHandleW / 3, // Offset slightly outward to be easily grabbable
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
                    color: Colors.transparent, // Broad invisible hit target
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: visualHandleW, 
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Right resize handle
          if (selected) Positioned(
            right: -touchHandleW / 3, // Offset slightly outward to be easily grabbable
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
                    color: Colors.transparent, // Broad invisible hit target
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: visualHandleW, 
                        color: Colors.white.withOpacity(0.6),
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
    final paint = Paint()..color = Colors.redAccent..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
