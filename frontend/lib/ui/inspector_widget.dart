import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../models/caption_model.dart';
import '../main.dart';

class InspectorWidget extends StatefulWidget {
  final Caption? selectedCaption;
  final List<Caption> allCaptions;
  final double currentTime;
  final VoidCallback onCaptionChanged;
  final ValueChanged<String> onCaptionSelected;
  final List<CaptionStyle> presets;
  final VoidCallback onAddCaption;
  final VoidCallback onDeleteCaption;
  final ValueChanged<CaptionStyle> onSavePreset;
  final ValueChanged<CaptionStyle> onApplyPreset;

  const InspectorWidget({super.key, required this.selectedCaption, required this.allCaptions, required this.currentTime, required this.presets, required this.onCaptionChanged, required this.onCaptionSelected, required this.onAddCaption, required this.onDeleteCaption, required this.onSavePreset, required this.onApplyPreset});

  @override
  State<InspectorWidget> createState() => _InspectorWidgetState();
}

class _InspectorWidgetState extends State<InspectorWidget> {
  static const _fonts = ['Inter','Roboto','Open Sans','Lato','Montserrat','Oswald','Raleway','PT Sans','Merriweather','Nunito','Concert One','Work Sans','Fira Sans','Rubik','Quicksand','Playfair Display','Anton','Cabin','Pacifico','Dosis','Ubuntu','Dancing Script','Bebas Neue','Josefin Sans','Lobster','Titillium Web','Cinzel','Amatic SC','Righteous','Caveat','Courgette','Abril Fatface','Alfa Slab One','Teko','Exo 2','Varela Round','Bitter','Libre Baskerville','PT Serif','Lora','Karla','Oxygen','Overpass','Zilla Slab','Asap','Play','Prompt','Mukta','Inconsolata','Noto Sans'];
  static const _anims = ['none','fade','pop','drop_in','slide_up','slide_down','slide_left','slide_right','whoosh','zoom_in','zoom_out','bounce','spin','flip_x','flip_y','swing','elastic','tilt_left','tilt_right','squish','fall_back'];
  static const _sfx = ['none','pop','whoosh','ding','swoosh','click','snap','thud','bounce','impact','slide','chime'];
  static const _blends = ['normal','multiply','screen','overlay','darken','lighten','colorDodge','colorBurn','hardLight','softLight','difference','exclusion','hue','saturation','color','luminosity'];

  late TextEditingController _tc;
  String? _lastId;

  @override
  void initState() { super.initState(); _tc = TextEditingController(text: widget.selectedCaption?.text ?? ''); _lastId = widget.selectedCaption?.id; }
  @override
  void didUpdateWidget(covariant InspectorWidget o) { super.didUpdateWidget(o); if (widget.selectedCaption?.id != _lastId) { _lastId = widget.selectedCaption?.id; _tc.text = widget.selectedCaption?.text ?? ''; } }
  @override
  void dispose() { _tc.dispose(); super.dispose(); }

  void _u() => widget.onCaptionChanged();
  Color _hex(String h) { h = h.replaceAll('#', ''); if (h.length == 6) h = 'FF$h'; return Color(int.parse(h, radix: 16)); }
  String _c2h(Color c) => '#${c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  bool get _mob => MediaQuery.of(context).size.width < 800;

  @override
  Widget build(BuildContext context) {
    return ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        decoration: BoxDecoration(color: AppColors.bgPanel.withOpacity(0.9), border: Border(left: BorderSide(color: AppColors.border.withOpacity(0.3)))),
        child: Column(children: [
          // Header
          if (!_mob) Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.3)))),
            child: Row(children: [
              _badge('INSPEKTOR'),
              const Spacer(),
              _actionChip(Icons.delete_outline_rounded, widget.selectedCaption != null ? widget.onDeleteCaption : null, danger: true),
            ]),
          ),
          // Caption list (desktop)
          if (!_mob) Container(
            height: 80,
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.2)))),
            child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), itemCount: widget.allCaptions.length, itemBuilder: (_, i) {
              final c = widget.allCaptions[i]; final sel = c.id == widget.selectedCaption?.id;
              return GestureDetector(onTap: () => widget.onCaptionSelected(c.id), child: AnimatedContainer(
                duration: const Duration(milliseconds: 150), margin: const EdgeInsets.symmetric(vertical: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: sel ? AppColors.accent.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: sel ? AppColors.accent.withOpacity(0.3) : Colors.transparent)),
                child: Row(children: [
                  Container(width: 3, height: 16, decoration: BoxDecoration(color: sel ? AppColors.accent : AppColors.border.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(c.text, style: TextStyle(color: sel ? AppColors.accent : AppColors.textSecondary, fontWeight: sel ? FontWeight.w600 : FontWeight.normal, fontSize: 12), overflow: TextOverflow.ellipsis)),
                  Text('${c.startTime.toStringAsFixed(1)}s', style: TextStyle(color: AppColors.textMuted.withOpacity(0.5), fontSize: 9, fontFamily: 'monospace')),
                ]),
              ));
            }),
          ),
          // Caption list (mobile) - always visible as horizontal chips
          if (_mob && widget.allCaptions.isNotEmpty) Container(
            height: 40,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.2)))),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: widget.allCaptions.length,
              itemBuilder: (_, i) {
                final c = widget.allCaptions[i];
                final sel = c.id == widget.selectedCaption?.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => widget.onCaptionSelected(c.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.accent.withOpacity(0.15) : AppColors.bgCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: sel ? AppColors.accent.withOpacity(0.5) : AppColors.border.withOpacity(0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (sel) Padding(padding: const EdgeInsets.only(right: 4), child: Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle))),
                        Text(c.text, style: TextStyle(color: sel ? AppColors.accent : AppColors.textSecondary, fontSize: 11, fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                        const SizedBox(width: 4),
                        Text('\${c.startTime.toStringAsFixed(1)}s', style: TextStyle(color: AppColors.textMuted.withOpacity(0.5), fontSize: 9, fontFamily: 'monospace')),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
          // Body
          Expanded(child: widget.selectedCaption == null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.touch_app_outlined, size: 28, color: AppColors.textMuted.withOpacity(0.3)), const SizedBox(height: 8), Text(_mob && widget.allCaptions.isNotEmpty ? 'Vyber titulek nahoře' : 'Přidej titulek (+)', style: TextStyle(color: AppColors.textMuted.withOpacity(0.5), fontSize: 13))]))
              : (_mob ? _mobileProp(widget.selectedCaption!) : _desktopProp(widget.selectedCaption!))),
        ]),
      ),
    ));
  }

  // ── Desktop properties ──
  Widget _desktopProp(Caption c) {
    final s = c.style; final t = c.transform3D;
    return ListView(padding: const EdgeInsets.all(14), children: [
      _presetSection(c),
      _sec('TEXT'),
      TextField(controller: _tc, onChanged: (v) { c.text = v; _u(); }, maxLines: 2, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13), decoration: _deco()),
      const SizedBox(height: 10),
      Row(children: [Expanded(child: _num('Začátek', c.startTime, (v) { c.startTime = v; _u(); })), const SizedBox(width: 6), Expanded(child: _num('Konec', c.endTime, (v) { c.endTime = v; _u(); })), const SizedBox(width: 6), Expanded(child: _dd('Stopa', ['0','1','2'], c.track.toString(), (v) { c.track = int.parse(v); _u(); }))]),
      const SizedBox(height: 16),
      _sec('ANIMACE'),
      Row(children: [Expanded(child: _dd('IN', _anims, _anims.contains(c.animationIn) ? c.animationIn : 'none', (v) { c.animationIn = v; _u(); })), const SizedBox(width: 6), Expanded(child: _dd('OUT', _anims, _anims.contains(c.animationOut) ? c.animationOut : 'none', (v) { c.animationOut = v; _u(); }))]),
      const SizedBox(height: 6),
      Row(children: [Expanded(child: _dd('SFX In', _sfx, _sfx.contains(c.sfxIn) ? c.sfxIn : 'none', (v) { c.sfxIn = v; _u(); })), const SizedBox(width: 6), Expanded(child: _dd('SFX Out', _sfx, _sfx.contains(c.sfxOut) ? c.sfxOut : 'none', (v) { c.sfxOut = v; _u(); }))]),
      _sl('Hlasitost', c.sfxVolume.toDouble(), 0, 100, (v) { c.sfxVolume = v.toInt(); _u(); }, s: '${c.sfxVolume}%'),
      const SizedBox(height: 16),
      _sec('FONT'),
      _dd('Font', _fonts, _fonts.contains(s.fontFamily) ? s.fontFamily : 'Inter', (v) { s.fontFamily = v; _u(); }),
      _sl('Velikost', s.fontSize.toDouble(), 20, 200, (v) { s.fontSize = v.toInt(); _u(); }, s: '${s.fontSize}px'),
      const SizedBox(height: 16),
      _sec('BARVY'),
      _colorSection(s),
      const SizedBox(height: 16),
      _sec('EFEKTY'),
      _sl('Krytí', s.opacity, 0, 1, (v) { s.opacity = v; _u(); }, s: '${(s.opacity * 100).toInt()}%'),
      _dd('Prolnutí', _blends, _blends.contains(s.blendMode) ? s.blendMode : 'normal', (v) { s.blendMode = v; _u(); }),
      const SizedBox(height: 8),
      _tog('Obrys', s.strokeEnabled, (v) { s.strokeEnabled = v; _u(); }, icon: Icons.border_style_rounded),
      if (s.strokeEnabled) ...[_sl('Šířka', s.strokeWidth.toDouble(), 0, 20, (v) { s.strokeWidth = v.toInt(); _u(); }, s: '${s.strokeWidth}px'), _cr('Barva', s.strokeColor, (c) { s.strokeColor = _c2h(c); _u(); })],
      _tog('Stín', s.shadowEnabled, (v) { s.shadowEnabled = v; _u(); }, icon: Icons.filter_drama_outlined),
      if (s.shadowEnabled) ...[_sl('Blur', s.shadowBlur.toDouble(), 0, 50, (v) { s.shadowBlur = v.toInt(); _u(); }, s: '${s.shadowBlur}'), _sl('Y', s.shadowOffsetY.toDouble(), -30, 30, (v) { s.shadowOffsetY = v.toInt(); _u(); }, s: '${s.shadowOffsetY}')],
      _tog('Záře', s.glowEnabled, (v) { s.glowEnabled = v; _u(); }, icon: Icons.wb_sunny_outlined),
      if (s.glowEnabled) ...[_cr('Barva', s.glowColor, (c) { s.glowColor = _c2h(c); _u(); }), _sl('Intenz', s.glowIntensity, 0, 1, (v) { s.glowIntensity = v; _u(); }, s: '${(s.glowIntensity * 100).toInt()}%')],
      _tog('Za osobou', s.behindPerson, (v) { s.behindPerson = v; _u(); }, icon: Icons.person_outline),
      const SizedBox(height: 16),
      _sec('POZICE'),
      Row(children: [Expanded(child: _num('X', t.position['x'].toDouble(), (v) { t.position['x'] = v; _u(); })), const SizedBox(width: 6), Expanded(child: _num('Y', t.position['y'].toDouble(), (v) { t.position['y'] = v; _u(); }))]),
      const SizedBox(height: 8),
      _sl('Rot X', t.rotation['x'].toDouble(), -180, 180, (v) { t.rotation['x'] = v; _u(); }, s: '${t.rotation['x'].toInt()}°'),
      _sl('Rot Y', t.rotation['y'].toDouble(), -180, 180, (v) { t.rotation['y'] = v; _u(); }, s: '${t.rotation['y'].toInt()}°'),
      _sl('Rot Z', t.rotation['z'].toDouble(), -180, 180, (v) { t.rotation['z'] = v; _u(); }, s: '${t.rotation['z'].toInt()}°'),
      const SizedBox(height: 24),
    ]);
  }

  // ── Mobile properties ──
  Widget _mobileProp(Caption c) {
    final s = c.style; final t = c.transform3D;
    return DefaultTabController(length: 4, child: Column(children: [
      SizedBox(height: 30, child: TabBar(labelColor: AppColors.accent, unselectedLabelColor: AppColors.textMuted, indicatorColor: AppColors.accent, indicatorWeight: 2, indicatorSize: TabBarIndicatorSize.label, labelPadding: EdgeInsets.zero,
        tabs: const [Tab(icon: Icon(Icons.text_fields_outlined, size: 16), height: 28), Tab(icon: Icon(Icons.brush_outlined, size: 16), height: 28), Tab(icon: Icon(Icons.auto_fix_high_outlined, size: 16), height: 28), Tab(icon: Icon(Icons.open_with_outlined, size: 16), height: 28)])),
      Expanded(child: TabBarView(children: [
        // T1: Text
        ListView(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), children: [
          _presetSection(c),
          TextField(controller: _tc, onChanged: (v) { c.text = v; _u(); }, maxLines: 2, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13), decoration: _deco()),
          const SizedBox(height: 8),
          Row(children: [Expanded(child: _num('Start', c.startTime, (v) { c.startTime = v; _u(); })), const SizedBox(width: 4), Expanded(child: _num('End', c.endTime, (v) { c.endTime = v; _u(); })), const SizedBox(width: 4), Expanded(child: _dd('Tr', ['0','1','2'], c.track.toString(), (v) { c.track = int.parse(v); _u(); }))]),
          const SizedBox(height: 6),
          // Delete
          GestureDetector(onTap: widget.onDeleteCaption, child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.delete_outline, size: 14, color: AppColors.danger), const SizedBox(width: 4), Text('Smazat titulek', style: TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600))]))),
        ]),
        // T2: Style
        ListView(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), children: [
          _dd('Font', _fonts, _fonts.contains(s.fontFamily) ? s.fontFamily : 'Inter', (v) { s.fontFamily = v; _u(); }),
          _sl('Velikost', s.fontSize.toDouble(), 20, 200, (v) { s.fontSize = v.toInt(); _u(); }, s: '${s.fontSize}px'),
          const SizedBox(height: 8),
          _colorSection(s),
          const SizedBox(height: 8),
          Row(children: [Expanded(child: _dd('IN', _anims, _anims.contains(c.animationIn) ? c.animationIn : 'none', (v) { c.animationIn = v; _u(); })), const SizedBox(width: 4), Expanded(child: _dd('OUT', _anims, _anims.contains(c.animationOut) ? c.animationOut : 'none', (v) { c.animationOut = v; _u(); }))]),
        ]),
        // T3: Effects
        ListView(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), children: [
          _sl('Krytí', s.opacity, 0, 1, (v) { s.opacity = v; _u(); }),
          _dd('Blend', _blends, _blends.contains(s.blendMode) ? s.blendMode : 'normal', (v) { s.blendMode = v; _u(); }),
          const SizedBox(height: 6),
          _tog('Obrys', s.strokeEnabled, (v) { s.strokeEnabled = v; _u(); }, icon: Icons.border_style_rounded),
          if (s.strokeEnabled) ...[_sl('Šířka', s.strokeWidth.toDouble(), 0, 20, (v) { s.strokeWidth = v.toInt(); _u(); }), _cr('Barva', s.strokeColor, (c) { s.strokeColor = _c2h(c); _u(); })],
          _tog('Stín', s.shadowEnabled, (v) { s.shadowEnabled = v; _u(); }, icon: Icons.filter_drama_outlined),
          if (s.shadowEnabled) ...[_sl('Blur', s.shadowBlur.toDouble(), 0, 50, (v) { s.shadowBlur = v.toInt(); _u(); }), _sl('Y', s.shadowOffsetY.toDouble(), -30, 30, (v) { s.shadowOffsetY = v.toInt(); _u(); })],
          _tog('Záře', s.glowEnabled, (v) { s.glowEnabled = v; _u(); }, icon: Icons.wb_sunny_outlined),
          if (s.glowEnabled) ...[_cr('Barva', s.glowColor, (c) { s.glowColor = _c2h(c); _u(); }), _sl('Intenz', s.glowIntensity, 0, 1, (v) { s.glowIntensity = v; _u(); })],
          _tog('Za osobou', s.behindPerson, (v) { s.behindPerson = v; _u(); }, icon: Icons.person_outline),
        ]),
        // T4: Position
        ListView(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), children: [
          Row(children: [Expanded(child: _num('X', t.position['x'].toDouble(), (v) { t.position['x'] = v; _u(); })), const SizedBox(width: 4), Expanded(child: _num('Y', t.position['y'].toDouble(), (v) { t.position['y'] = v; _u(); }))]),
          const SizedBox(height: 6),
          _sl('Rot X', t.rotation['x'].toDouble(), -180, 180, (v) { t.rotation['x'] = v; _u(); }),
          _sl('Rot Y', t.rotation['y'].toDouble(), -180, 180, (v) { t.rotation['y'] = v; _u(); }),
          _sl('Rot Z', t.rotation['z'].toDouble(), -180, 180, (v) { t.rotation['z'] = v; _u(); }),
        ]),
      ])),
    ]));
  }

  // ── Shared sections ──
  Widget _presetSection(Caption c) {
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Wrap(spacing: 5, runSpacing: 5, children: [
      ...widget.presets.asMap().entries.map((e) => GestureDetector(onTap: () => widget.onApplyPreset(e.value),
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.accent.withOpacity(0.2))),
          child: Text('Styl ${e.key + 1}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 10))))),
      GestureDetector(onTap: () => widget.onSavePreset(c.style),
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.accent.withOpacity(0.3))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_rounded, size: 11, color: AppColors.accent), const SizedBox(width: 3), Text('Uložit', style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w600))]))),
    ]));
  }

  Widget _colorSection(CaptionStyle s) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        GestureDetector(onTap: () => _pickColor(s.colorSolid, (c) { s.colorSolid = _c2h(c); _u(); }),
          child: Container(width: 40, height: 40, decoration: BoxDecoration(color: _hex(s.colorSolid), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border, width: 1.5), boxShadow: [BoxShadow(color: _hex(s.colorSolid).withOpacity(0.25), blurRadius: 8)]))),
        const SizedBox(width: 10),
        Expanded(child: _tog('Gradient', s.useGradient, (v) { s.useGradient = v; _u(); }, icon: Icons.gradient_rounded)),
      ]),
      if (s.useGradient) ...[
        const SizedBox(height: 8),
        Builder(builder: (_) {
          String gp = 'Vlastní'; if (s.gradientType == 'radial') gp = 'Kruhový'; else if (s.gradientType == 'sweep') gp = 'Vějíř'; else if (s.gradientAngle == 90) gp = 'Svisle'; else if (s.gradientAngle == 0) gp = 'Vodorovně'; else if (s.gradientAngle == 45) gp = 'Diagonálně';
          return _dd('Styl', ['Svisle','Vodorovně','Diagonálně','Kruhový','Vějíř','Vlastní'], gp, (v) {
            if (v == 'Svisle') { s.gradientType = 'linear'; s.gradientAngle = 90; } else if (v == 'Vodorovně') { s.gradientType = 'linear'; s.gradientAngle = 0; } else if (v == 'Diagonálně') { s.gradientType = 'linear'; s.gradientAngle = 45; } else if (v == 'Kruhový') { s.gradientType = 'radial'; } else if (v == 'Vějíř') { s.gradientType = 'sweep'; } else { s.gradientType = 'linear'; } _u();
          });
        }),
        if (s.gradientType == 'linear') _sl('Úhel', s.gradientAngle, 0, 360, (v) { s.gradientAngle = v; _u(); }, s: '${s.gradientAngle.toInt()}°'),
        _sl('Poměr', s.gradientRatio, 0, 1, (v) { s.gradientRatio = v; _u(); }),
        const SizedBox(height: 4),
        Row(children: [
          _cbox('B1', s.gradientColors.isNotEmpty ? s.gradientColors[0] : '#FFD700', (c) { s.gradientColors = List.from(s.gradientColors.isEmpty ? ['#FFD700','#D4AF37'] : s.gradientColors); s.gradientColors[0] = _c2h(c); _u(); }),
          const SizedBox(width: 6),
          _cbox('B2', s.gradientColors.length > 1 ? s.gradientColors[1] : '#D4AF37', (c) { s.gradientColors = List.from(s.gradientColors.length < 2 ? ['#FFD700','#D4AF37'] : s.gradientColors); s.gradientColors[1] = _c2h(c); _u(); }),
        ]),
      ],
    ]);
  }

  // ── Reusable widgets ──
  Widget _badge(String t) => Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accentLight]), borderRadius: BorderRadius.circular(5)), child: Text(t, style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)));
  Widget _sec(String t) => Padding(padding: const EdgeInsets.only(bottom: 8, top: 4), child: Row(children: [Container(width: 3, height: 12, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2))), const SizedBox(width: 6), Text(t, style: const TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8))]));
  InputDecoration _deco() => InputDecoration(filled: true, fillColor: AppColors.bgCard, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border.withOpacity(0.3))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent, width: 1)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), isDense: true);

  Widget _num(String l, double v, ValueChanged<double> cb) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: TextStyle(color: AppColors.textMuted, fontSize: 10)), const SizedBox(height: 2), SizedBox(height: 34, child: TextField(controller: TextEditingController(text: v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)), onSubmitted: (x) { final d = double.tryParse(x); if (d != null) cb(d); }, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontFamily: 'monospace'), keyboardType: TextInputType.number, decoration: _deco()))]);

  Widget _dd(String l, List<String> items, String v, ValueChanged<String> cb) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: TextStyle(color: AppColors.textMuted, fontSize: 10)), const SizedBox(height: 2), SizedBox(height: 34, child: DropdownButtonFormField<String>(value: items.contains(v) ? v : items.first, dropdownColor: AppColors.bgElevated, isDense: true, decoration: _deco(), items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: AppColors.textPrimary, fontSize: 11)))).toList(), onChanged: (x) { if (x != null) cb(x); }))]);

  Widget _sl(String l, double v, double mn, double mx, ValueChanged<double> cb, {String s = ''}) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [SizedBox(width: 48, child: Text(l, style: TextStyle(color: AppColors.textMuted, fontSize: 10))), Expanded(child: Slider(value: v.clamp(mn, mx), min: mn, max: mx, onChanged: cb)), if (s.isNotEmpty) SizedBox(width: 38, child: Text(s, style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontFamily: 'monospace'), textAlign: TextAlign.right))]));

  Widget _tog(String l, bool v, ValueChanged<bool> cb, {IconData? icon}) => GestureDetector(onTap: () => cb(!v), child: AnimatedContainer(duration: const Duration(milliseconds: 150), margin: const EdgeInsets.symmetric(vertical: 2), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: v ? AppColors.accent.withOpacity(0.06) : AppColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: v ? AppColors.accent.withOpacity(0.3) : AppColors.border.withOpacity(0.3))),
    child: Row(children: [Icon(icon ?? (v ? Icons.check_circle : Icons.circle_outlined), size: 15, color: v ? AppColors.accent : AppColors.textMuted), const SizedBox(width: 7), Text(l, style: TextStyle(color: v ? AppColors.textPrimary : AppColors.textSecondary, fontSize: 12, fontWeight: v ? FontWeight.w600 : FontWeight.normal)), const Spacer(),
      // iOS switch
      AnimatedContainer(duration: const Duration(milliseconds: 180), width: 38, height: 22, decoration: BoxDecoration(color: v ? AppColors.accent : AppColors.bgElevated, borderRadius: BorderRadius.circular(11), border: Border.all(color: v ? AppColors.accent : AppColors.border)),
        child: AnimatedAlign(duration: const Duration(milliseconds: 180), alignment: v ? Alignment.centerRight : Alignment.centerLeft, child: Container(width: 18, height: 18, margin: const EdgeInsets.all(1), decoration: BoxDecoration(color: v ? Colors.black : AppColors.textMuted, shape: BoxShape.circle)))),
    ])));

  Widget _cr(String l, String hex, ValueChanged<Color> cb) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [SizedBox(width: 60, child: Text(l, style: TextStyle(color: AppColors.textMuted, fontSize: 10))), GestureDetector(onTap: () => _pickColor(hex, cb), child: Container(width: 28, height: 28, decoration: BoxDecoration(color: _hex(hex), borderRadius: BorderRadius.circular(7), border: Border.all(color: AppColors.border)))), const SizedBox(width: 6), Text(hex, style: TextStyle(color: AppColors.textMuted.withOpacity(0.6), fontSize: 10, fontFamily: 'monospace'))]));

  Widget _cbox(String l, String hex, ValueChanged<Color> cb) => Expanded(child: GestureDetector(onTap: () => _pickColor(hex, cb), child: Column(children: [Text(l, style: TextStyle(color: AppColors.textMuted, fontSize: 10)), const SizedBox(height: 3), Container(height: 28, decoration: BoxDecoration(color: _hex(hex), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)))])));

  Widget _actionChip(IconData icon, VoidCallback? cb, {bool danger = false}) => GestureDetector(onTap: cb, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: cb == null ? Colors.transparent : (danger ? AppColors.danger.withOpacity(0.08) : AppColors.bgCard), borderRadius: BorderRadius.circular(8), border: Border.all(color: danger ? AppColors.danger.withOpacity(0.2) : AppColors.border.withOpacity(0.3))), child: Icon(icon, size: 14, color: cb == null ? AppColors.textMuted.withOpacity(0.3) : (danger ? AppColors.danger : AppColors.accent))));

  void _pickColor(String hex, ValueChanged<Color> cb) {
    Color ac = _hex(hex);
    showModalBottomSheet(context: context, backgroundColor: AppColors.bgCard, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))), builder: (ctx) => StatefulBuilder(builder: (_, ss) => Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 12),
      ColorPicker(pickerColor: ac, onColorChanged: (c) => ss(() => ac = c), colorPickerWidth: 280, pickerAreaHeightPercent: 0.65, enableAlpha: false, displayThumbColor: true, paletteType: PaletteType.hsvWithHue, labelTypes: const [], pickerAreaBorderRadius: const BorderRadius.all(Radius.circular(14))),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Zrušit', style: TextStyle(color: AppColors.textMuted))),
        const SizedBox(width: 8),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () { cb(ac); Navigator.pop(ctx); }, child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w700))),
      ]),
    ]))));
  }
}


