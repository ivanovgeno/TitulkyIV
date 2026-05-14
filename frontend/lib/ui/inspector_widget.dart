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

  const InspectorWidget({
    super.key,
    required this.selectedCaption,
    required this.allCaptions,
    required this.currentTime,
    required this.presets,
    required this.onCaptionChanged,
    required this.onCaptionSelected,
    required this.onAddCaption,
    required this.onDeleteCaption,
    required this.onSavePreset,
    required this.onApplyPreset,
  });

  @override
  State<InspectorWidget> createState() => _InspectorWidgetState();
}

class _InspectorWidgetState extends State<InspectorWidget> {
  static const _fonts = [
    'Inter', 'Roboto', 'Open Sans', 'Lato', 'Montserrat', 'Oswald',
    'Raleway', 'PT Sans', 'Merriweather', 'Nunito', 'Concert One',
    'Work Sans', 'Fira Sans', 'Rubik', 'Quicksand', 'Playfair Display',
    'Anton', 'Cabin', 'Pacifico', 'Dosis', 'Ubuntu', 'Dancing Script',
    'Bebas Neue', 'Josefin Sans', 'Lobster', 'Titillium Web', 'Cinzel',
    'Amatic SC', 'Righteous', 'Caveat', 'Courgette', 'Abril Fatface',
    'Alfa Slab One', 'Teko', 'Exo 2', 'Varela Round', 'Bitter',
    'Libre Baskerville', 'PT Serif', 'Lora', 'Karla', 'Oxygen',
    'Overpass', 'Zilla Slab', 'Asap', 'Play', 'Prompt', 'Mukta',
    'Inconsolata', 'Noto Sans',
  ];

  static const _animationsIn = [
    'none', 'fade', 'pop', 'drop_in', 'slide_up', 'slide_down',
    'slide_left', 'slide_right', 'whoosh', 'zoom_in', 'zoom_out',
    'bounce', 'spin', 'flip_x', 'flip_y', 'swing', 'elastic',
    'tilt_left', 'tilt_right', 'squish', 'fall_back',
  ];

  static const _sfxOptions = [
    'none', 'pop', 'whoosh', 'ding', 'swoosh', 'click', 'snap', 'thud',
    'bounce', 'impact', 'slide', 'chime',
  ];

  static const _blendModes = [
    'normal', 'multiply', 'screen', 'overlay', 'darken', 'lighten',
    'colorDodge', 'colorBurn', 'hardLight', 'softLight', 'difference',
    'exclusion', 'hue', 'saturation', 'color', 'luminosity',
  ];

  late TextEditingController _textCtrl;
  String? _lastId;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.selectedCaption?.text ?? '');
    _lastId = widget.selectedCaption?.id;
  }

  @override
  void didUpdateWidget(covariant InspectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCaption?.id != _lastId) {
      _lastId = widget.selectedCaption?.id;
      _textCtrl.text = widget.selectedCaption?.text ?? '';
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _update() => widget.onCaptionChanged();

  Color _hex(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  String _colorToHex(Color c) => '#${c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24.0, sigmaY: 24.0),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bgPanel.withOpacity(0.85),
            border: Border(left: BorderSide(color: AppColors.border.withOpacity(0.5), width: 1)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accentLight]),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('INSPEKTOR', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                    ),
                    const Spacer(),
                    _actionBtn(Icons.add_rounded, 'Nový', widget.onAddCaption),
                    const SizedBox(width: 6),
                    _actionBtn(Icons.delete_outline_rounded, 'Smazat', widget.selectedCaption != null ? widget.onDeleteCaption : null, danger: true),
                  ],
                ),
              ),

              // Caption list (desktop only)
              if (!isMobile)
                Container(
                  height: 90,
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.3)))),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    itemCount: widget.allCaptions.length,
                    itemBuilder: (ctx, i) {
                      final c = widget.allCaptions[i];
                      final selected = c.id == widget.selectedCaption?.id;
                      return InkWell(
                        onTap: () => widget.onCaptionSelected(c.id),
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.accent.withOpacity(0.12) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: selected ? AppColors.accent.withOpacity(0.4) : Colors.transparent),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 4, height: 20,
                                decoration: BoxDecoration(
                                  color: selected ? AppColors.accent : AppColors.border,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  c.text,
                                  style: TextStyle(
                                    color: selected ? AppColors.accent : AppColors.textSecondary,
                                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${c.startTime.toStringAsFixed(1)}s',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // Properties
              Expanded(
                child: widget.selectedCaption == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app_outlined, size: 32, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            Text('Vyber titulek', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                          ],
                        ),
                      )
                    : (isMobile ? _buildMobileProperties(widget.selectedCaption!) : _buildProperties(widget.selectedCaption!)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProperties(Caption c) {
    final s = c.style;
    final t = c.transform3D;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // === PRESETS ===
        _section('PRESETY'),
        if (widget.presets.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Zatím nemáš uložené šablony.', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic)),
          ),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: [
            ...widget.presets.asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              return InkWell(
                onTap: () => widget.onApplyPreset(p),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                  ),
                  child: Text('Šablona ${i + 1}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 11)),
                ),
              );
            }),
            InkWell(
              onTap: () => widget.onSavePreset(c.style),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.accent.withOpacity(0.15), AppColors.accentLight.withOpacity(0.05)]),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 12, color: AppColors.accent),
                    const SizedBox(width: 4),
                    Text('Uložit styl', style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // === TEXT ===
        _section('TEXT'),
        _label('Obsah titulku'),
        TextField(
          controller: _textCtrl,
          onChanged: (v) { c.text = v; _update(); },
          maxLines: 2,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: _inputDeco(),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _numField('Začátek', c.startTime, (v) { c.startTime = v; _update(); })),
          const SizedBox(width: 8),
          Expanded(child: _numField('Konec', c.endTime, (v) { c.endTime = v; _update(); })),
          const SizedBox(width: 8),
          Expanded(child: _dropdownField('Stopa', ['0', '1', '2'], c.track.toString(), (v) { c.track = int.parse(v); _update(); })),
        ]),
        const SizedBox(height: 20),

        // === ANIMATION ===
        _section('ANIMACE'),
        Row(children: [
          Expanded(child: _dropdownField('IN', _animationsIn, _animationsIn.contains(c.animationIn) ? c.animationIn : 'none', (v) { c.animationIn = v; _update(); })),
          const SizedBox(width: 8),
          Expanded(child: _dropdownField('OUT', _animationsIn, _animationsIn.contains(c.animationOut) ? c.animationOut : 'none', (v) { c.animationOut = v; _update(); })),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _dropdownField('SFX In', _sfxOptions, _sfxOptions.contains(c.sfxIn) ? c.sfxIn : 'none', (v) { c.sfxIn = v; _update(); })),
          const SizedBox(width: 8),
          Expanded(child: _dropdownField('SFX Out', _sfxOptions, _sfxOptions.contains(c.sfxOut) ? c.sfxOut : 'none', (v) { c.sfxOut = v; _update(); })),
        ]),
        _slider('Hlasitost SFX', c.sfxVolume.toDouble(), 0, 100, (v) { c.sfxVolume = v.toInt(); _update(); }, suffix: '${c.sfxVolume}%'),
        const SizedBox(height: 20),

        // === FONT ===
        _section('FONT'),
        _dropdownField('Rodina', _fonts, _fonts.contains(s.fontFamily) ? s.fontFamily : 'Inter', (v) { s.fontFamily = v; _update(); }),
        const SizedBox(height: 8),
        _slider('Velikost', s.fontSize.toDouble(), 20, 200, (v) { s.fontSize = v.toInt(); _update(); }, suffix: '${s.fontSize}px'),
        const SizedBox(height: 20),

        // === COLORS ===
        _section('BARVY'),
        Row(children: [
          GestureDetector(
            onTap: () => _pickColor(s.colorSolid, (c) { s.colorSolid = _colorToHex(c); _update(); }),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _hex(s.colorSolid),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border, width: 2),
                boxShadow: [BoxShadow(color: _hex(s.colorSolid).withOpacity(0.3), blurRadius: 8)],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _toggleRow('Gradient', s.useGradient, (v) { s.useGradient = v; _update(); }, icon: Icons.gradient_rounded)),
        ]),
        if (s.useGradient) ...[
          const SizedBox(height: 8),
          Builder(builder: (context) {
            String currentGradPreset = 'Vlastní úhel';
            if (s.gradientType == 'radial') currentGradPreset = 'Z prostředka (kruhový)';
            else if (s.gradientType == 'sweep') currentGradPreset = 'Vějířový';
            else if (s.gradientAngle == 90) currentGradPreset = 'Na stojato (svisle)';
            else if (s.gradientAngle == 0) currentGradPreset = 'Vodorovně';
            else if (s.gradientAngle == 45) currentGradPreset = 'Z rohu (diagonálně)';
            
            return _dropdownField(
              'Styl přechodu', 
              ['Na stojato (svisle)', 'Vodorovně', 'Z rohu (diagonálně)', 'Z prostředka (kruhový)', 'Vějířový', 'Vlastní úhel'],
              currentGradPreset,
              (v) {
                if (v == 'Na stojato (svisle)') { s.gradientType = 'linear'; s.gradientAngle = 90; }
                else if (v == 'Vodorovně') { s.gradientType = 'linear'; s.gradientAngle = 0; }
                else if (v == 'Z rohu (diagonálně)') { s.gradientType = 'linear'; s.gradientAngle = 45; }
                else if (v == 'Z prostředka (kruhový)') { s.gradientType = 'radial'; }
                else if (v == 'Vějířový') { s.gradientType = 'sweep'; }
                else { s.gradientType = 'linear'; }
                _update();
              }
            );
          }),
          const SizedBox(height: 8),
          if (s.gradientType == 'linear') ...[
            _slider('Úhel', s.gradientAngle, 0, 360, (v) { s.gradientAngle = v; _update(); }, suffix: '${s.gradientAngle.toInt()}°'),
            const SizedBox(height: 8),
          ],
          _slider('Poměr', s.gradientRatio, 0, 1, (v) { s.gradientRatio = v; _update(); }, suffix: '${(s.gradientRatio * 100).toInt()}%'),
          const SizedBox(height: 8),
          Row(children: [
            _colorBox('Barva 1', s.gradientColors.isNotEmpty ? s.gradientColors[0] : '#FFD700', (c) {
              s.gradientColors = List<String>.from(s.gradientColors.isEmpty ? ['#FFD700', '#D4AF37'] : s.gradientColors);
              s.gradientColors[0] = _colorToHex(c); _update();
            }),
            const SizedBox(width: 8),
            _colorBox('Barva 2', s.gradientColors.length > 1 ? s.gradientColors[1] : '#D4AF37', (c) {
              s.gradientColors = List<String>.from(s.gradientColors.length < 2 ? ['#FFD700', '#D4AF37'] : s.gradientColors);
              s.gradientColors[1] = _colorToHex(c); _update();
            }),
          ]),
        ],
        const SizedBox(height: 20),

        // === EFFECTS ===
        _section('EFEKTY'),
        _slider('Krytí', s.opacity, 0.0, 1.0, (v) { s.opacity = v; _update(); }, suffix: '${(s.opacity * 100).toInt()}%'),
        const SizedBox(height: 8),
        _dropdownField('Prolnutí', _blendModes, _blendModes.contains(s.blendMode) ? s.blendMode : 'normal', (v) { s.blendMode = v; _update(); }),
        const SizedBox(height: 12),
        _toggleRow('Obrys', s.strokeEnabled, (v) { s.strokeEnabled = v; _update(); }, icon: Icons.border_style_rounded),
        if (s.strokeEnabled) ...[
          _slider('Šířka', s.strokeWidth.toDouble(), 0, 20, (v) { s.strokeWidth = v.toInt(); _update(); }, suffix: '${s.strokeWidth}px'),
          _colorRow('Barva', s.strokeColor, (c) { s.strokeColor = _colorToHex(c); _update(); }),
        ],
        const SizedBox(height: 8),
        _toggleRow('Stín', s.shadowEnabled, (v) { s.shadowEnabled = v; _update(); }, icon: Icons.filter_drama_outlined),
        if (s.shadowEnabled) ...[
          _slider('Rozmazání', s.shadowBlur.toDouble(), 0, 50, (v) { s.shadowBlur = v.toInt(); _update(); }, suffix: '${s.shadowBlur}'),
          _slider('Offset Y', s.shadowOffsetY.toDouble(), -30, 30, (v) { s.shadowOffsetY = v.toInt(); _update(); }, suffix: '${s.shadowOffsetY}'),
        ],
        const SizedBox(height: 8),
        _toggleRow('Záře', s.glowEnabled, (v) { s.glowEnabled = v; _update(); }, icon: Icons.wb_sunny_outlined),
        if (s.glowEnabled) ...[
          _colorRow('Barva záře', s.glowColor, (c) { s.glowColor = _colorToHex(c); _update(); }),
          _slider('Intenzita', s.glowIntensity, 0.0, 1.0, (v) { s.glowIntensity = v; _update(); }, suffix: '${(s.glowIntensity * 100).toInt()}%'),
        ],
        const SizedBox(height: 8),
        _toggleRow('Za osobou', s.behindPerson, (v) { s.behindPerson = v; _update(); }, icon: Icons.person_outline_rounded),
        if (s.behindPerson)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text('Vyžaduje vygenerovanou masku.', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontStyle: FontStyle.italic)),
          ),
        const SizedBox(height: 20),

        // === POSITION ===
        _section('POZICE A ROTACE'),
        Row(children: [
          Expanded(child: _numField('X', t.position['x'].toDouble(), (v) { t.position['x'] = v; _update(); })),
          const SizedBox(width: 6),
          Expanded(child: _numField('Y', t.position['y'].toDouble(), (v) { t.position['y'] = v; _update(); })),
        ]),
        const SizedBox(height: 12),
        _slider('Rot X', t.rotation['x'].toDouble(), -180, 180, (v) { t.rotation['x'] = v; _update(); }, suffix: '${t.rotation['x'].toInt()}°'),
        _slider('Rot Y', t.rotation['y'].toDouble(), -180, 180, (v) { t.rotation['y'] = v; _update(); }, suffix: '${t.rotation['y'].toInt()}°'),
        _slider('Rot Z', t.rotation['z'].toDouble(), -180, 180, (v) { t.rotation['z'] = v; _update(); }, suffix: '${t.rotation['z'].toInt()}°'),
        const SizedBox(height: 30),
      ],
    );
  }

  // ─── Helpers ───

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Container(
          width: 3, height: 14,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.accent, AppColors.accentLight],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
      ],
    ),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
  );

  InputDecoration _inputDeco() => InputDecoration(
    filled: true,
    fillColor: AppColors.bgCard,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border.withOpacity(0.5))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    isDense: true,
  );

  Widget _numField(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(height: 3),
        SizedBox(
          height: 36,
          child: TextField(
            controller: TextEditingController(text: value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)),
            onSubmitted: (v) { final d = double.tryParse(v); if (d != null) onChanged(d); },
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontFamily: 'monospace'),
            keyboardType: TextInputType.number,
            decoration: _inputDeco(),
          ),
        ),
      ],
    );
  }

  Widget _dropdownField(String label, List<String> items, String value, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(height: 3),
        SizedBox(
          height: 36,
          child: DropdownButtonFormField<String>(
            value: items.contains(value) ? value : items.first,
            dropdownColor: AppColors.bgElevated,
            isDense: true,
            decoration: _inputDeco(),
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)))).toList(),
            onChanged: (v) { if (v != null) onChanged(v); },
          ),
        ),
      ],
    );
  }

  Widget _slider(String label, double value, double min, double max, ValueChanged<double> onChanged, {String suffix = ''}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 55, child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10))),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppColors.accent,
                inactiveTrackColor: AppColors.border,
                thumbColor: AppColors.accent,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                trackHeight: 3,
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
            ),
          ),
          SizedBox(width: 44, child: Text(suffix, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontFamily: 'monospace'), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged, {IconData? icon}) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: value ? AppColors.accent.withOpacity(0.08) : AppColors.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: value ? AppColors.accent.withOpacity(0.4) : AppColors.border.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(
                  icon ?? (value ? Icons.check_circle_rounded : Icons.circle_outlined),
                  size: 16,
                  color: value ? AppColors.accent : AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: value ? AppColors.textPrimary : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: value ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ]),
              // Toggle indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 32, height: 18,
                decoration: BoxDecoration(
                  color: value ? AppColors.accent : AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: value ? AppColors.accent : AppColors.border),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 14, height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: value ? Colors.black : AppColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colorRow(String label, String hex, ValueChanged<Color> onPicked) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 75, child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11))),
          GestureDetector(
            onTap: () => _pickColor(hex, onPicked),
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: _hex(hex),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
                boxShadow: [BoxShadow(color: _hex(hex).withOpacity(0.25), blurRadius: 6)],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(hex, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _colorBox(String label, String hex, ValueChanged<Color> onPicked) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _pickColor(hex, onPicked),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 4),
            Container(
              height: 32,
              decoration: BoxDecoration(
                color: _hex(hex),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
                boxShadow: [BoxShadow(color: _hex(hex).withOpacity(0.2), blurRadius: 6)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String tip, VoidCallback? onTap, {bool danger = false}) {
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: onTap == null ? Colors.transparent : AppColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: danger ? AppColors.danger.withOpacity(0.3) : AppColors.border.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: onTap == null ? AppColors.textMuted : (danger ? AppColors.danger : AppColors.accent)),
              const SizedBox(width: 4),
              Text(tip, style: TextStyle(fontSize: 11, color: onTap == null ? AppColors.textMuted : AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  void _pickColor(String currentHex, ValueChanged<Color> onPicked) {
    Color activeColor = _hex(currentHex);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        titlePadding: const EdgeInsets.all(0),
        contentPadding: const EdgeInsets.all(0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        content: StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
                    ),
                    child: const Center(child: Text('Vybrat barvu', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15))),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: ColorPicker(
                      pickerColor: activeColor,
                      onColorChanged: (c) { setDialogState(() { activeColor = c; }); },
                      colorPickerWidth: 280,
                      pickerAreaHeightPercent: 0.7,
                      enableAlpha: false,
                      displayThumbColor: true,
                      paletteType: PaletteType.hsvWithHue,
                      labelTypes: const [],
                      pickerAreaBorderRadius: const BorderRadius.all(Radius.circular(14)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Zrušit', style: TextStyle(color: AppColors.textMuted)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
                          onPressed: () { onPicked(activeColor); Navigator.pop(ctx); },
                          child: const Text('Použít', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileProperties(Caption c) {
    final s = c.style;
    final t = c.transform3D;

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          TabBar(
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.accent,
            indicatorWeight: 2,
            labelPadding: EdgeInsets.zero,
            tabs: const [
              Tab(icon: Icon(Icons.text_fields_outlined, size: 18), child: Text('Text', style: TextStyle(fontSize: 9))),
              Tab(icon: Icon(Icons.brush_outlined, size: 18), child: Text('Styl', style: TextStyle(fontSize: 9))),
              Tab(icon: Icon(Icons.auto_fix_high_outlined, size: 18), child: Text('Efekty', style: TextStyle(fontSize: 9))),
              Tab(icon: Icon(Icons.open_with_outlined, size: 18), child: Text('Pozice', style: TextStyle(fontSize: 9))),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // TAB 1: TEXT & PRESETS
                ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  children: [
                    _section('PRESETY'),
                    if (widget.presets.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Zatím žádné šablony.', style: TextStyle(color: AppColors.textMuted, fontSize: 10))),
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: [
                        ...widget.presets.asMap().entries.map((entry) => InkWell(
                          onTap: () => widget.onApplyPreset(entry.value),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.accent.withOpacity(0.3))),
                            child: Text('Šab. ${entry.key + 1}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 10)),
                          ),
                        )),
                        InkWell(
                          onTap: () => widget.onSavePreset(c.style),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.accent)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_rounded, size: 12, color: AppColors.accent), const SizedBox(width: 2), Text('Uložit', style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w600))]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _section('TITULEK'),
                    TextField(
                      controller: _textCtrl,
                      onChanged: (v) { c.text = v; _update(); },
                      maxLines: 2,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: _inputDeco().copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _numField('Začátek', c.startTime, (v) { c.startTime = v; _update(); })),
                      const SizedBox(width: 6),
                      Expanded(child: _numField('Konec', c.endTime, (v) { c.endTime = v; _update(); })),
                      const SizedBox(width: 6),
                      Expanded(child: _dropdownField('Tr.', ['0', '1', '2'], c.track.toString(), (v) { c.track = int.parse(v); _update(); })),
                    ]),
                  ],
                ),
                // TAB 2: STYLING & COLORS
                ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  children: [
                    _section('FONT'),
                    _dropdownField('Font', _fonts, _fonts.contains(s.fontFamily) ? s.fontFamily : 'Inter', (v) { s.fontFamily = v; _update(); }),
                    _slider('Velikost', s.fontSize.toDouble(), 20, 200, (v) { s.fontSize = v.toInt(); _update(); }, suffix: '${s.fontSize}px'),
                    const SizedBox(height: 12),
                    _section('BARVY'),
                    Row(children: [
                      GestureDetector(
                        onTap: () => _pickColor(s.colorSolid, (col) { s.colorSolid = _colorToHex(col); _update(); }),
                        child: Container(width: 36, height: 36, decoration: BoxDecoration(color: _hex(s.colorSolid), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _toggleRow('Gradient', s.useGradient, (v) { s.useGradient = v; _update(); }, icon: Icons.gradient_rounded)),
                    ]),
                    if (s.useGradient) ...[
                      const SizedBox(height: 8),
                      Builder(builder: (context) {
                        String currentGradPreset = 'Vlastní úhel';
                        if (s.gradientType == 'radial') currentGradPreset = 'Z prostředka (kruhový)';
                        else if (s.gradientType == 'sweep') currentGradPreset = 'Vějířový';
                        else if (s.gradientAngle == 90) currentGradPreset = 'Na stojato (svisle)';
                        else if (s.gradientAngle == 0) currentGradPreset = 'Vodorovně';
                        else if (s.gradientAngle == 45) currentGradPreset = 'Z rohu (diagonálně)';
                        
                        return _dropdownField('Styl', 
                          ['Na stojato (svisle)', 'Vodorovně', 'Z rohu (diagonálně)', 'Z prostředka (kruhový)', 'Vějířový', 'Vlastní úhel'],
                          currentGradPreset,
                          (v) {
                            if (v == 'Na stojato (svisle)') { s.gradientType = 'linear'; s.gradientAngle = 90; }
                            else if (v == 'Vodorovně') { s.gradientType = 'linear'; s.gradientAngle = 0; }
                            else if (v == 'Z rohu (diagonálně)') { s.gradientType = 'linear'; s.gradientAngle = 45; }
                            else if (v == 'Z prostředka (kruhový)') { s.gradientType = 'radial'; }
                            else if (v == 'Vějířový') { s.gradientType = 'sweep'; }
                            else { s.gradientType = 'linear'; }
                            _update();
                          }
                        );
                      }),
                      if (s.gradientType == 'linear') ...[
                        const SizedBox(height: 6),
                        _slider('Úhel', s.gradientAngle, 0, 360, (v) { s.gradientAngle = v; _update(); }, suffix: '${s.gradientAngle.toInt()}°'),
                      ],
                      const SizedBox(height: 6),
                      _slider('Poměr', s.gradientRatio, 0, 1, (v) { s.gradientRatio = v; _update(); }),
                      Row(children: [
                        Expanded(child: _colorBox('B1', s.gradientColors.isNotEmpty ? s.gradientColors[0] : '#FFD700', (col) {
                          s.gradientColors = List<String>.from(s.gradientColors.isEmpty ? ['#FFD700', '#D4AF37'] : s.gradientColors);
                          s.gradientColors[0] = _colorToHex(col); _update();
                        })),
                        const SizedBox(width: 8),
                        Expanded(child: _colorBox('B2', s.gradientColors.length > 1 ? s.gradientColors[1] : '#D4AF37', (col) {
                          s.gradientColors = List<String>.from(s.gradientColors.length < 2 ? ['#FFD700', '#D4AF37'] : s.gradientColors);
                          s.gradientColors[1] = _colorToHex(col); _update();
                        })),
                      ]),
                    ],
                    const SizedBox(height: 12),
                    _section('ANIMACE'),
                    Row(children: [
                      Expanded(child: _dropdownField('IN', _animationsIn, _animationsIn.contains(c.animationIn) ? c.animationIn : 'none', (v) { c.animationIn = v; _update(); })),
                      const SizedBox(width: 6),
                      Expanded(child: _dropdownField('OUT', _animationsIn, _animationsIn.contains(c.animationOut) ? c.animationOut : 'none', (v) { c.animationOut = v; _update(); })),
                    ]),
                  ],
                ),
                // TAB 3: EFFECTS
                ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  children: [
                    _section('VRSTVENÍ'),
                    _slider('Krytí', s.opacity, 0, 1, (v) { s.opacity = v; _update(); }),
                    const SizedBox(height: 4),
                    _dropdownField('Prolnutí', _blendModes, _blendModes.contains(s.blendMode) ? s.blendMode : 'normal', (v) { s.blendMode = v; _update(); }),
                    const SizedBox(height: 12),
                    _toggleRow('Za osobou', s.behindPerson, (v) { s.behindPerson = v; _update(); }, icon: Icons.person_outline_rounded),
                    const SizedBox(height: 12),
                    _section('OBRYS A STÍN'),
                    _toggleRow('Obrys', s.strokeEnabled, (v) { s.strokeEnabled = v; _update(); }, icon: Icons.border_style_rounded),
                    if (s.strokeEnabled) ...[
                      _slider('Šířka', s.strokeWidth.toDouble(), 0, 20, (v) { s.strokeWidth = v.toInt(); _update(); }),
                      _colorRow('Barva', s.strokeColor, (col) { s.strokeColor = _colorToHex(col); _update(); }),
                    ],
                    const SizedBox(height: 8),
                    _toggleRow('Stín', s.shadowEnabled, (v) { s.shadowEnabled = v; _update(); }, icon: Icons.filter_drama_outlined),
                    if (s.shadowEnabled) ...[
                      _slider('Rozmaz', s.shadowBlur.toDouble(), 0, 50, (v) { s.shadowBlur = v.toInt(); _update(); }),
                      _slider('Y-Pos', s.shadowOffsetY.toDouble(), -30, 30, (v) { s.shadowOffsetY = v.toInt(); _update(); }),
                    ],
                    const SizedBox(height: 8),
                    _toggleRow('Záře', s.glowEnabled, (v) { s.glowEnabled = v; _update(); }, icon: Icons.wb_sunny_outlined),
                    if (s.glowEnabled) ...[
                      _colorRow('Záře', s.glowColor, (col) { s.glowColor = _colorToHex(col); _update(); }),
                      _slider('Intenz', s.glowIntensity, 0, 1, (v) { s.glowIntensity = v; _update(); }),
                    ],
                  ],
                ),
                // TAB 4: POSITION
                ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  children: [
                    _section('POZICE A ROTACE'),
                    Row(children: [
                      Expanded(child: _numField('Pos X', t.position['x'].toDouble(), (v) { t.position['x'] = v; _update(); })),
                      const SizedBox(width: 6),
                      Expanded(child: _numField('Pos Y', t.position['y'].toDouble(), (v) { t.position['y'] = v; _update(); })),
                    ]),
                    const SizedBox(height: 8),
                    _slider('Rot X', t.rotation['x'].toDouble(), -180, 180, (v) { t.rotation['x'] = v; _update(); }),
                    _slider('Rot Y', t.rotation['y'].toDouble(), -180, 180, (v) { t.rotation['y'] = v; _update(); }),
                    _slider('Rot Z', t.rotation['z'].toDouble(), -180, 180, (v) { t.rotation['z'] = v; _update(); }),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

