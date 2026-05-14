import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/caption_model.dart';
import 'dart:math' as math;

class CaptionOverlay extends StatefulWidget {
  final List<Caption> captions;
  final double currentTime;
  final Resolution resolution;
  final String? selectedCaptionId;
  final ValueChanged<String>? onCaptionSelected;
  final VoidCallback? onCaptionUpdate;

  const CaptionOverlay({
    super.key,
    required this.captions,
    required this.currentTime,
    required this.resolution,
    this.selectedCaptionId,
    this.onCaptionSelected,
    this.onCaptionUpdate,
  });

  @override
  State<CaptionOverlay> createState() => _CaptionOverlayState();
}

class _CaptionOverlayState extends State<CaptionOverlay> {
  Caption? _draggingCaption;
  bool _isDragging = false;
  double _virtualX = 0;
  double _virtualY = 0;
  bool _isSnappedV = false;
  bool _isSnappedH = false;
  
  // Variables for Scale/Rotate gestures
  double _initialFontSize = 90;
  double _initialRotationZ = 0;

  @override
  Widget build(BuildContext context) {
    final activeCaptions = widget.captions.where((c) =>
      widget.currentTime >= c.startTime && widget.currentTime <= c.endTime
    ).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final scaleX = constraints.maxWidth / widget.resolution.width;
        final scaleY = constraints.maxHeight / widget.resolution.height;
        final scale = math.min(scaleX, scaleY);

        return Stack(
          children: [
            ...activeCaptions.map((caption) => _buildCaption(caption, scale)),
            if (_isDragging) _buildSafeZoneOverlay(constraints.maxWidth, constraints.maxHeight),
          ],
        );
      },
    );
  }

  Widget _buildSafeZoneOverlay(double width, double height) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size(width, height),
        painter: SafeZonePainter(isSnappedV: _isSnappedV, isSnappedH: _isSnappedH),
      ),
    );
  }

  Widget _buildCaption(Caption caption, double scale) {
    final pos = caption.transform3D.position;
    final rot = caption.transform3D.rotation;
    final s = caption.style;

    final rx = (rot['x'] ?? 0.0).toDouble() * math.pi / 180;
    final ry = (rot['y'] ?? 0.0).toDouble() * math.pi / 180;
    final rz = (rot['z'] ?? 0.0).toDouble() * math.pi / 180;

    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.001)
      ..translate((pos['x'] ?? 540).toDouble() * scale, (pos['y'] ?? 960).toDouble() * scale, (pos['z'] ?? 0).toDouble())
      ..rotateX(rx)
      ..rotateY(ry)
      ..rotateZ(rz);

    // Build text color
    Color textColor = _parseHexColor(s.colorSolid);

    // Build shadows list
    List<Shadow> shadows = [];
    if (s.shadowEnabled) {
      shadows.add(Shadow(
        color: Colors.black.withOpacity(0.9),
        offset: Offset(s.shadowOffsetX.toDouble(), s.shadowOffsetY.toDouble()),
        blurRadius: s.shadowBlur.toDouble(),
      ));
    }
    if (s.glowEnabled) {
      final glowColor = _parseHexColor(s.glowColor);
      shadows.add(Shadow(
        color: glowColor.withOpacity(s.glowIntensity),
        blurRadius: 20.0 * s.glowIntensity,
      ));
      // Double glow for stronger effect
      shadows.add(Shadow(
        color: glowColor.withOpacity(s.glowIntensity * 0.5),
        blurRadius: 40.0 * s.glowIntensity,
      ));
    }

    // Build text style
    TextStyle textStyle;
    try {
      textStyle = GoogleFonts.getFont(
        s.fontFamily,
        fontSize: s.fontSize * scale,
        fontWeight: FontWeight.w900,
        color: s.useGradient ? Colors.white : textColor, // White if gradient used
        shadows: shadows.isNotEmpty ? shadows : null,
      );
    } catch (e) {
      textStyle = TextStyle(
        fontFamily: 'Inter',
        fontSize: s.fontSize * scale,
        fontWeight: FontWeight.w900,
        color: s.useGradient ? Colors.white : textColor,
        shadows: shadows.isNotEmpty ? shadows : null,
      );
    }

    // Build the text widget (with optional stroke)
    Widget textWidget;
    
    // Core text content
    Widget content = Text(caption.text, style: textStyle);

    // Apply Gradient if enabled
    if (s.useGradient && s.gradientColors.length >= 2) {
      content = ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) {
          final colors = s.gradientColors.map((hex) => _parseHexColor(hex)).toList();
          final List<double> stops;
          final List<Color> gradientColorsToUse;
          
          if (colors.length == 2) {
            // Inject explicit midpoint to make gradientRatio adjust perfectly
            final midColor = Color.lerp(colors[0], colors[1], 0.5)!;
            gradientColorsToUse = [colors[0], midColor, colors[1]];
            stops = [0.0, s.gradientRatio.clamp(0.05, 0.95), 1.0];
          } else {
            gradientColorsToUse = colors;
            stops = List.generate(colors.length, (i) => i / (colors.length - 1));
          }

          if (s.gradientType == 'radial') {
            return RadialGradient(
              colors: gradientColorsToUse,
              stops: stops,
              center: Alignment.center,
              radius: 0.8,
            ).createShader(Offset.zero & bounds.size);
          } else if (s.gradientType == 'sweep') {
            return SweepGradient(
              colors: gradientColorsToUse,
              stops: stops,
              center: Alignment.center,
              startAngle: 0.0,
              endAngle: math.pi * 2,
            ).createShader(Offset.zero & bounds.size);
          } else {
            // Linear: calculate custom vector from angle
            final angleRad = (s.gradientAngle - 90) * math.pi / 180.0;
            final begin = Alignment(math.cos(angleRad + math.pi), math.sin(angleRad + math.pi));
            final end = Alignment(math.cos(angleRad), math.sin(angleRad));
            return LinearGradient(
              colors: gradientColorsToUse,
              stops: stops,
              begin: begin,
              end: end,
            ).createShader(Offset.zero & bounds.size);
          }
        },
        child: content,
      );
    }

    if (s.strokeEnabled && s.strokeWidth > 0) {
      final strokeColor = _parseHexColor(s.strokeColor);
      textWidget = Stack(
        children: [
          // Stroke
          Text(
            caption.text,
            style: textStyle.copyWith(
              color: null,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = s.strokeWidth * scale
                ..color = strokeColor,
              shadows: null,
            ),
          ),
          // Fill (with possible gradient)
          content,
        ],
      );
    } else {
      textWidget = content;
    }

    // --- ANIMATION LOGIC ---
    double animInDuration = 0.2;
    double animOutDuration = 0.2;
    double progress = 1.0;
    double scaleAnim = 1.0;
    double opacityAnim = 1.0;
    double slideX = 0.0;
    double slideY = 0.0;
    double rotateAnim = 0.0;

    final timeFromStart = widget.currentTime - caption.startTime;
    final timeFromEnd = caption.endTime - widget.currentTime;

    if (timeFromStart < animInDuration && timeFromStart >= 0) {
      progress = (timeFromStart / animInDuration).clamp(0.0, 1.0);
      final easeOut = 1.0 - math.pow(1.0 - progress, 3); // Cubic ease out

      switch(caption.animationIn) {
        case 'fade': opacityAnim = progress; break;
        case 'pop': scaleAnim = 0.5 + (0.5 * easeOut); opacityAnim = progress; break;
        case 'zoom_in': scaleAnim = easeOut; opacityAnim = progress; break;
        case 'zoom_out': scaleAnim = 2.0 - easeOut; opacityAnim = progress; break;
        case 'drop_in': scaleAnim = 3.0 - (2.0 * easeOut); opacityAnim = progress; break;
        case 'slide_up': slideY = 50 * (1.0 - easeOut); opacityAnim = progress; break;
        case 'slide_down': slideY = -50 * (1.0 - easeOut); opacityAnim = progress; break;
        case 'slide_left': slideX = 50 * (1.0 - easeOut); opacityAnim = progress; break;
        case 'slide_right': slideX = -50 * (1.0 - easeOut); opacityAnim = progress; break;
        case 'spin': rotateAnim = math.pi * (1.0 - easeOut); scaleAnim = easeOut; opacityAnim = progress; break;
        default: 
          if (caption.animationIn != 'none') {
            scaleAnim = 0.5 + (0.5 * easeOut); opacityAnim = progress; // fallback
          }
      }
    } else if (timeFromEnd < animOutDuration && timeFromEnd >= 0) {
      progress = (timeFromEnd / animOutDuration).clamp(0.0, 1.0);
      final easeIn = progress; // Linear for out
      
      switch(caption.animationOut) {
        case 'fade': opacityAnim = progress; break;
        case 'pop': scaleAnim = 0.5 + (0.5 * easeIn); opacityAnim = progress; break;
        case 'zoom_in': scaleAnim = easeIn; opacityAnim = progress; break;
        case 'zoom_out': scaleAnim = 1.0 + (1.0 - easeIn); opacityAnim = progress; break;
        case 'slide_up': slideY = -50 * (1.0 - easeIn); opacityAnim = progress; break;
        case 'slide_down': slideY = 50 * (1.0 - easeIn); opacityAnim = progress; break;
        case 'slide_left': slideX = -50 * (1.0 - easeIn); opacityAnim = progress; break;
        case 'slide_right': slideX = 50 * (1.0 - easeIn); opacityAnim = progress; break;
        default:
          if (caption.animationOut != 'none') {
            scaleAnim = 0.5 + (0.5 * easeIn); opacityAnim = progress; // fallback
          }
      }
    }

    final bool isSelected = widget.selectedCaptionId == caption.id;

    // Apply animation translations
    matrix.translate(slideX, slideY, 0.0);
    if (rotateAnim != 0.0) {
      matrix.rotateZ(rotateAnim);
    }

    return Positioned(
      left: 0,
      top: 0,
      child: Transform(
        transform: matrix,
        alignment: Alignment.center,
        child: FractionalTranslation(
          translation: const Offset(-0.5, -0.5),
          child: BlendMask(
            blendMode: _parseBlendMode(s.blendMode),
            opacity: 1.0, 
            child: Opacity(
              opacity: opacityAnim * s.opacity, // The ONE TRUE Opacity!
              child: Transform.scale(
                scale: scaleAnim,
                child: Stack(
                  clipBehavior: Clip.none,
                children: [
                  // Main Content
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: (details) {
                      widget.onCaptionSelected?.call(caption.id);
                      setState(() {
                        _draggingCaption = caption;
                        _isDragging = true;
                        _virtualX = (caption.transform3D.position['x'] ?? 540).toDouble();
                        _virtualY = (caption.transform3D.position['y'] ?? 960).toDouble();
                        _initialFontSize = caption.style.fontSize.toDouble();
                        _initialRotationZ = (caption.transform3D.rotation['z'] ?? 0).toDouble();
                      });
                    },
                    onScaleUpdate: (details) {
                      if (_draggingCaption == null) return;
                      setState(() {
                        // Translation
                        _virtualX += details.focalPointDelta.dx / scale;
                        _virtualY += details.focalPointDelta.dy / scale;
                        
                        double newX = _virtualX;
                        double newY = _virtualY;
                        final cx = widget.resolution.width / 2;
                        final cy = widget.resolution.height / 2;
                        const snapDist = 25.0;
                        
                        _isSnappedV = (newX - cx).abs() < snapDist;
                        if (_isSnappedV) newX = cx;
                        _isSnappedH = (newY - cy).abs() < snapDist;
                        if (_isSnappedH) newY = cy;
                        
                        _draggingCaption!.transform3D.position['x'] = newX;
                        _draggingCaption!.transform3D.position['y'] = newY;
                        
                        // Scaling (Pinch-to-zoom)
                        if (details.scale != 1.0) {
                          _draggingCaption!.style.fontSize = (_initialFontSize * details.scale).clamp(10, 400).toInt();
                        }
                        
                        // Rotation (Two fingers)
                        if (details.rotation != 0.0) {
                          double rotationDeg = details.rotation * 180 / math.pi;
                          _draggingCaption!.transform3D.rotation['z'] = _initialRotationZ + rotationDeg;
                        }

                        widget.onCaptionUpdate?.call();
                      });
                    },
                    onScaleEnd: (_) {
                      setState(() { 
                        _isDragging = false; 
                        _draggingCaption = null; 
                        _isSnappedV = false; 
                        _isSnappedH = false; 
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: isSelected ? Border.all(color: const Color(0xFFD4AF37), width: 2) : null,
                      ),
                      child: textWidget,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildHandle(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(color: Color(0xFFD4AF37), shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: Colors.black),
        ),
        Text(label, style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Color _parseHexColor(String hexString) {
    hexString = hexString.replaceAll('#', '');
    if (hexString.length == 6) hexString = 'FF$hexString';
    return Color(int.parse(hexString, radix: 16));
  }

  BlendMode _parseBlendMode(String mode) {
    switch (mode.toLowerCase()) {
      case 'multiply': return BlendMode.multiply;
      case 'screen': return BlendMode.screen;
      case 'overlay': return BlendMode.overlay;
      case 'darken': return BlendMode.darken;
      case 'lighten': return BlendMode.lighten;
      case 'colordodge': return BlendMode.colorDodge;
      case 'colorburn': return BlendMode.colorBurn;
      case 'hardlight': return BlendMode.hardLight;
      case 'softlight': return BlendMode.softLight;
      case 'difference': return BlendMode.difference;
      case 'exclusion': return BlendMode.exclusion;
      case 'hue': return BlendMode.hue;
      case 'saturation': return BlendMode.saturation;
      case 'color': return BlendMode.color;
      case 'luminosity': return BlendMode.luminosity;
      default: return BlendMode.srcOver; // Same as Normal
    }
  }
}

// Helper for Davinci Blending Effect
class BlendMask extends SingleChildRenderObjectWidget {
  final BlendMode blendMode;
  final double opacity;

  const BlendMask({
    super.key,
    required this.blendMode,
    this.opacity = 1.0,
    super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderBlendMask(blendMode, opacity);
  }

  @override
  void updateRenderObject(BuildContext context, RenderBlendMask renderObject) {
    renderObject.blendMode = blendMode;
    renderObject.opacity = opacity;
  }
}

class RenderBlendMask extends RenderProxyBox {
  BlendMode blendMode;
  double opacity;

  RenderBlendMask(this.blendMode, this.opacity);

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    // Perform composite stacking via saveLayer so GPU applies blending mode on restore()
    context.canvas.saveLayer(
      offset & size,
      Paint()
        ..blendMode = blendMode
        ..color = Color.fromRGBO(255, 255, 255, opacity),
    );
    super.paint(context, offset);
    context.canvas.restore();
  }
}

class SafeZonePainter extends CustomPainter {
  final bool isSnappedV;
  final bool isSnappedH;

  SafeZonePainter({required this.isSnappedV, required this.isSnappedH});

  @override
  void paint(Canvas canvas, Size size) {
    final dashPaint = Paint()
      ..color = const Color.fromRGBO(255, 0, 85, 0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromLTRB(size.width * 0.08, size.height * 0.15, size.width * 0.92, size.height * 0.75);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), dashPaint);

    // Safe zone label
    final textPainter = TextPainter(
      text: const TextSpan(text: 'IG/TikTok Safe Zone', style: TextStyle(color: Color.fromRGBO(255, 0, 85, 0.8), fontSize: 10, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(rect.left + 4, rect.top - 14));

    // Center guides
    final vPaint = Paint()
      ..color = isSnappedV ? const Color(0xFFFFD700) : const Color.fromRGBO(0, 255, 255, 0.6)
      ..strokeWidth = isSnappedV ? 2 : 1;
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), vPaint);

    final hPaint = Paint()
      ..color = isSnappedH ? const Color(0xFFFFD700) : const Color.fromRGBO(0, 255, 255, 0.6)
      ..strokeWidth = isSnappedH ? 2 : 1;
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), hPaint);
  }

  @override
  bool shouldRepaint(covariant SafeZonePainter oldDelegate) {
    return oldDelegate.isSnappedV != isSnappedV || oldDelegate.isSnappedH != isSnappedH;
  }
}
