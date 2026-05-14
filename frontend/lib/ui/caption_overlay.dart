import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/caption_model.dart';
import '../main.dart';
import 'dart:math' as math;

class CaptionOverlay extends StatefulWidget {
  final List<Caption> captions;
  final double currentTime;
  final Resolution resolution;
  final String? selectedCaptionId;
  final ValueChanged<String>? onCaptionSelected;
  final VoidCallback? onCaptionUpdate;
  const CaptionOverlay({super.key, required this.captions, required this.currentTime, required this.resolution, this.selectedCaptionId, this.onCaptionSelected, this.onCaptionUpdate});
  @override
  State<CaptionOverlay> createState() => _CaptionOverlayState();
}

class _CaptionOverlayState extends State<CaptionOverlay> {
  Caption? _drag;
  bool _isDragging = false;
  double _vx = 0, _vy = 0;
  bool _snapV = false, _snapH = false;
  double _initSize = 90, _initRot = 0;

  @override
  Widget build(BuildContext context) {
    final active = widget.captions.where((c) => widget.currentTime >= c.startTime && widget.currentTime <= c.endTime).toList();
    return LayoutBuilder(builder: (ctx, con) {
      final sx = con.maxWidth / widget.resolution.width;
      final sy = con.maxHeight / widget.resolution.height;
      final sc = math.min(sx, sy);
      return Stack(children: [...active.map((c) => _cap(c, sc)), if (_isDragging) _safeZone(con.maxWidth, con.maxHeight)]);
    });
  }

  Widget _safeZone(double w, double h) => IgnorePointer(child: CustomPaint(size: Size(w, h), painter: _SafePainter(sv: _snapV, sh: _snapH)));

  Widget _cap(Caption c, double sc) {
    final p = c.transform3D.position;
    final r = c.transform3D.rotation;
    final s = c.style;
    final rx = (r['x'] ?? 0.0).toDouble() * math.pi / 180;
    final ry = (r['y'] ?? 0.0).toDouble() * math.pi / 180;
    final rz = (r['z'] ?? 0.0).toDouble() * math.pi / 180;
    final m = Matrix4.identity()..setEntry(3, 2, 0.001)..translate((p['x'] ?? 540).toDouble() * sc, (p['y'] ?? 960).toDouble() * sc, (p['z'] ?? 0).toDouble())..rotateX(rx)..rotateY(ry)..rotateZ(rz);

    Color tc = _hex(s.colorSolid);
    List<Shadow> sh = [];
    if (s.shadowEnabled) sh.add(Shadow(color: Colors.black.withOpacity(0.9), offset: Offset(s.shadowOffsetX.toDouble(), s.shadowOffsetY.toDouble()), blurRadius: s.shadowBlur.toDouble()));
    if (s.glowEnabled) { final gc = _hex(s.glowColor); sh.add(Shadow(color: gc.withOpacity(s.glowIntensity), blurRadius: 20.0 * s.glowIntensity)); sh.add(Shadow(color: gc.withOpacity(s.glowIntensity * 0.5), blurRadius: 40.0 * s.glowIntensity)); }

    TextStyle ts;
    try { ts = GoogleFonts.getFont(s.fontFamily, fontSize: s.fontSize * sc, fontWeight: FontWeight.w900, color: s.useGradient ? Colors.white : tc, shadows: sh.isNotEmpty ? sh : null); }
    catch (_) { ts = TextStyle(fontFamily: 'Inter', fontSize: s.fontSize * sc, fontWeight: FontWeight.w900, color: s.useGradient ? Colors.white : tc, shadows: sh.isNotEmpty ? sh : null); }

    Widget content = Text(c.text, style: ts);
    if (s.useGradient && s.gradientColors.length >= 2) content = ShaderMask(blendMode: BlendMode.srcIn, shaderCallback: (b) => _grad(s, b), child: content);

    Widget tw;
    if (s.strokeEnabled && s.strokeWidth > 0) {
      tw = Stack(children: [Text(c.text, style: ts.copyWith(color: null, foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = s.strokeWidth * sc..color = _hex(s.strokeColor), shadows: null)), content]);
    } else { tw = content; }

    // Animations
    double ai = 0.2, ao = 0.2, prog = 1.0, sa = 1.0, oa = 1.0, slx = 0.0, sly = 0.0, ra = 0.0;
    final tfs = widget.currentTime - c.startTime;
    final tfe = c.endTime - widget.currentTime;
    if (tfs < ai && tfs >= 0) { prog = (tfs / ai).clamp(0.0, 1.0); final eo = 1.0 - math.pow(1.0 - prog, 3); switch (c.animationIn) { case 'fade': oa = prog; case 'pop': sa = 0.5 + 0.5 * eo; oa = prog; case 'zoom_in': sa = eo; oa = prog; case 'zoom_out': sa = 2.0 - eo; oa = prog; case 'drop_in': sa = 3.0 - 2.0 * eo; oa = prog; case 'slide_up': sly = 50 * (1.0 - eo); oa = prog; case 'slide_down': sly = -50 * (1.0 - eo); oa = prog; case 'slide_left': slx = 50 * (1.0 - eo); oa = prog; case 'slide_right': slx = -50 * (1.0 - eo); oa = prog; case 'spin': ra = math.pi * (1.0 - eo); sa = eo; oa = prog; default: if (c.animationIn != 'none') { sa = 0.5 + 0.5 * eo; oa = prog; } } }
    else if (tfe < ao && tfe >= 0) { prog = (tfe / ao).clamp(0.0, 1.0); switch (c.animationOut) { case 'fade': oa = prog; case 'pop': sa = 0.5 + 0.5 * prog; oa = prog; case 'zoom_in': sa = prog; oa = prog; case 'zoom_out': sa = 1.0 + (1.0 - prog); oa = prog; case 'slide_up': sly = -50 * (1.0 - prog); oa = prog; case 'slide_down': sly = 50 * (1.0 - prog); oa = prog; case 'slide_left': slx = -50 * (1.0 - prog); oa = prog; case 'slide_right': slx = 50 * (1.0 - prog); oa = prog; default: if (c.animationOut != 'none') { sa = 0.5 + 0.5 * prog; oa = prog; } } }

    final sel = widget.selectedCaptionId == c.id;
    m.translate(slx, sly, 0.0);
    if (ra != 0.0) m.rotateZ(ra);

    return Positioned(left: 0, top: 0, child: Transform(transform: m, alignment: Alignment.center,
      child: FractionalTranslation(translation: const Offset(-0.5, -0.5),
        child: BlendMask(blendMode: _bm(s.blendMode), opacity: 1.0,
          child: Opacity(opacity: oa * s.opacity,
            child: Transform.scale(scale: sa,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: (d) { widget.onCaptionSelected?.call(c.id); setState(() { _drag = c; _isDragging = true; _vx = (c.transform3D.position['x'] ?? 540).toDouble(); _vy = (c.transform3D.position['y'] ?? 960).toDouble(); _initSize = c.style.fontSize.toDouble(); _initRot = (c.transform3D.rotation['z'] ?? 0).toDouble(); }); },
                onScaleUpdate: (d) { if (_drag == null) return; setState(() {
                  _vx += d.focalPointDelta.dx / sc; _vy += d.focalPointDelta.dy / sc;
                  double nx = _vx, ny = _vy;
                  final cx = widget.resolution.width / 2, cy = widget.resolution.height / 2;
                  _snapV = (nx - cx).abs() < 25; if (_snapV) nx = cx;
                  _snapH = (ny - cy).abs() < 25; if (_snapH) ny = cy;
                  _drag!.transform3D.position['x'] = nx; _drag!.transform3D.position['y'] = ny;
                  if (d.scale != 1.0) _drag!.style.fontSize = (_initSize * d.scale).clamp(10, 400).toInt();
                  if (d.rotation != 0.0) _drag!.transform3D.rotation['z'] = _initRot + d.rotation * 180 / math.pi;
                  widget.onCaptionUpdate?.call();
                }); },
                onScaleEnd: (_) => setState(() { _isDragging = false; _drag = null; _snapV = false; _snapH = false; }),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: sel ? BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.accent.withOpacity(0.8), width: 1.5), boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.15), blurRadius: 12)]) : null,
                  child: tw,
                ),
              ),
            ),
          ),
        ),
      ),
    ));
  }

  Color _hex(String h) { h = h.replaceAll('#', ''); if (h.length == 6) h = 'FF$h'; return Color(int.parse(h, radix: 16)); }

  Shader _grad(CaptionStyle s, Rect b) {
    final colors = s.gradientColors.map(_hex).toList();
    final List<double> stops; final List<Color> gc;
    if (colors.length == 2) { gc = [colors[0], Color.lerp(colors[0], colors[1], 0.5)!, colors[1]]; stops = [0.0, s.gradientRatio.clamp(0.05, 0.95), 1.0]; }
    else { gc = colors; stops = List.generate(colors.length, (i) => i / (colors.length - 1)); }
    if (s.gradientType == 'radial') return RadialGradient(colors: gc, stops: stops, center: Alignment.center, radius: 0.8).createShader(Offset.zero & b.size);
    if (s.gradientType == 'sweep') return SweepGradient(colors: gc, stops: stops).createShader(Offset.zero & b.size);
    final a = (s.gradientAngle - 90) * math.pi / 180.0;
    return LinearGradient(colors: gc, stops: stops, begin: Alignment(math.cos(a + math.pi), math.sin(a + math.pi)), end: Alignment(math.cos(a), math.sin(a))).createShader(Offset.zero & b.size);
  }

  BlendMode _bm(String m) { switch (m.toLowerCase()) { case 'multiply': return BlendMode.multiply; case 'screen': return BlendMode.screen; case 'overlay': return BlendMode.overlay; case 'darken': return BlendMode.darken; case 'lighten': return BlendMode.lighten; case 'colordodge': return BlendMode.colorDodge; case 'colorburn': return BlendMode.colorBurn; case 'hardlight': return BlendMode.hardLight; case 'softlight': return BlendMode.softLight; case 'difference': return BlendMode.difference; case 'exclusion': return BlendMode.exclusion; case 'hue': return BlendMode.hue; case 'saturation': return BlendMode.saturation; case 'color': return BlendMode.color; case 'luminosity': return BlendMode.luminosity; default: return BlendMode.srcOver; } }
}

class BlendMask extends SingleChildRenderObjectWidget {
  final BlendMode blendMode; final double opacity;
  const BlendMask({super.key, required this.blendMode, this.opacity = 1.0, super.child});
  @override
  RenderObject createRenderObject(BuildContext ctx) => RenderBlendMask(blendMode, opacity);
  @override
  void updateRenderObject(BuildContext ctx, RenderBlendMask r) { r.blendMode = blendMode; r.opacity = opacity; }
}

class RenderBlendMask extends RenderProxyBox {
  BlendMode blendMode; double opacity;
  RenderBlendMask(this.blendMode, this.opacity);
  @override
  void paint(PaintingContext ctx, Offset o) { if (child == null) return; ctx.canvas.saveLayer(o & size, Paint()..blendMode = blendMode..color = Color.fromRGBO(255, 255, 255, opacity)); super.paint(ctx, o); ctx.canvas.restore(); }
}

class _SafePainter extends CustomPainter {
  final bool sv, sh;
  _SafePainter({required this.sv, required this.sh});
  @override
  void paint(Canvas c, Size s) {
    final dp = Paint()..color = AppColors.danger.withOpacity(0.5)..strokeWidth = 1..style = PaintingStyle.stroke;
    final r = Rect.fromLTRB(s.width * 0.08, s.height * 0.15, s.width * 0.92, s.height * 0.75);
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(10)), dp);
    final tp = TextPainter(text: TextSpan(text: 'Safe Zone', style: TextStyle(color: AppColors.danger.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.w600)), textDirection: TextDirection.ltr);
    tp.layout(); tp.paint(c, Offset(r.left + 4, r.top - 12));
    c.drawLine(Offset(s.width / 2, 0), Offset(s.width / 2, s.height), Paint()..color = sv ? AppColors.accent : AppColors.info.withOpacity(0.3)..strokeWidth = sv ? 1.5 : 0.5);
    c.drawLine(Offset(0, s.height / 2), Offset(s.width, s.height / 2), Paint()..color = sh ? AppColors.accent : AppColors.info.withOpacity(0.3)..strokeWidth = sh ? 1.5 : 0.5);
  }
  @override
  bool shouldRepaint(covariant _SafePainter o) => o.sv != sv || o.sh != sh;
}

