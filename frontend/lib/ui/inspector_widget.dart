import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../models/caption_model.dart';

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

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
          child: Container(
            decoration: const BoxDecoration(
              color: Color.fromRGBO(15, 15, 15, 0.65),
              border: Border(left: BorderSide(color: Colors.white12, width: 1)),
            ),
            child: Column(
              children: [
                // Header + Add/Delete buttons
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white10)),
                  ),
                  child: Row(
                    children: [
                      const Text('INSPEKTOR', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const Spacer(),
                      _miniBtn(Icons.add, 'Nový', widget.onAddCaption),
                      const SizedBox(width: 6),
                      _miniBtn(Icons.delete_outline, 'Smazat', widget.selectedCaption != null ? widget.onDeleteCaption : null, danger: true),
                    ],
                  ),
                ),

                // Caption list (ONLY ON DESKTOP, wastes vertical space on mobile)
                if (!isMobile)
                  Container(
                    height: 100,
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF222222)))),
                    child: ListView.builder(
                      itemCount: widget.allCaptions.length,
                      itemBuilder: (ctx, i) {
                        final c = widget.allCaptions[i];
                        final selected = c.id == widget.selectedCaption?.id;
                        return InkWell(
                          onTap: () => widget.onCaptionSelected(c.id),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? const Color(0xFFD4AF37).withOpacity(0.15) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: selected ? const Color(0xFFD4AF37).withOpacity(0.5) : Colors.transparent),
                            ),
                            child: Text(
                              '${c.text}  (${c.startTime.toStringAsFixed(1)}s)',
                              style: TextStyle(
                                color: selected ? const Color(0xFFD4AF37) : Colors.white70,
                                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                // Properties (scrollable)
                Expanded(
                  child: widget.selectedCaption == null
                      ? const Center(child: Text('Vyber titulek pro úpravu', style: TextStyle(color: Colors.white38, fontSize: 14)))
                      : (isMobile ? _buildMobileProperties(widget.selectedCaption!) : _buildProperties(widget.selectedCaption!)),
                ),
              ],
            ),
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
        _section('MOJE PRESETY (ŠABLONY)'),
        if (widget.presets.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Zatím nemáš žádné uložené šablony.', style: TextStyle(color: Colors.white24, fontSize: 11, fontStyle: FontStyle.italic)),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...widget.presets.asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              return InkWell(
                onTap: () => widget.onApplyPreset(p),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF222222),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                  ),
                  child: Text('Šablona ${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                ),
              );
            }),
            InkWell(
              onTap: () => widget.onSavePreset(c.style),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFD4AF37), style: BorderStyle.solid),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 12, color: Color(0xFFD4AF37)),
                    SizedBox(width: 4),
                    Text('Uložit aktuální styl', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // === TEXT ===
        _section('ZÁKLADNÍ VLASTNOSTI'),
        _label('Text'),
        TextField(
          controller: _textCtrl,
          onChanged: (v) { c.text = v; _update(); },
          maxLines: 2,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: _inputDeco(),
        ),
        const SizedBox(height: 12),

        // Start / End / Track
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

        // === FONT & STYLE ===
        _section('FONT A STYL'),
        _dropdownField('Font', _fonts, _fonts.contains(s.fontFamily) ? s.fontFamily : 'Inter', (v) { s.fontFamily = v; _update(); }),
        const SizedBox(height: 8),
        _slider('Velikost', s.fontSize.toDouble(), 20, 200, (v) { s.fontSize = v.toInt(); _update(); }, suffix: '${s.fontSize}px'),

        const SizedBox(height: 20),

        // === BARVY ===
        _section('BARVY A PŘECHODY'),
        Row(children: [
          // Solid color picker
          GestureDetector(
            onTap: () => _pickColor(s.colorSolid, (c) { s.colorSolid = _colorToHex(c); _update(); }),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: _hex(s.colorSolid), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF444444))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _toggleRow('Gradient', s.useGradient, (v) { s.useGradient = v; _update(); }, icon: Icons.gradient_rounded),
          ),
        ]),
        if (s.useGradient) ...[
          const SizedBox(height: 8),
          // Gradient Style Selector
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
            _slider('Úhel otočení', s.gradientAngle, 0, 360, (v) { s.gradientAngle = v; _update(); }, suffix: '${s.gradientAngle.toInt()}°'),
            const SizedBox(height: 8),
          ],
          _slider('Poměr barev (Střed)', s.gradientRatio, 0, 1, (v) { s.gradientRatio = v; _update(); }, suffix: '${(s.gradientRatio * 100).toInt()}%'),
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

        // === EFEKTY ===
        _section('EFEKTY A VRSTVY'),
        _slider('Krytí (Opacity)', s.opacity, 0.0, 1.0, (v) { s.opacity = v; _update(); }, suffix: '${(s.opacity * 100).toInt()}%'),
        const SizedBox(height: 8),
        _dropdownField('Styl prolnutí (Blend)', _blendModes, _blendModes.contains(s.blendMode) ? s.blendMode : 'normal', (v) { s.blendMode = v; _update(); }),
        const SizedBox(height: 16),

        // Stroke
        _toggleRow('Obrys (Stroke)', s.strokeEnabled, (v) { s.strokeEnabled = v; _update(); }, icon: Icons.border_style_rounded),
        if (s.strokeEnabled) ...[
          _slider('Šířka obrysu', s.strokeWidth.toDouble(), 0, 20, (v) { s.strokeWidth = v.toInt(); _update(); }, suffix: '${s.strokeWidth}px'),
          _colorRow('Barva obrysu', s.strokeColor, (c) { s.strokeColor = _colorToHex(c); _update(); }),
        ],
        const SizedBox(height: 8),

        // Shadow
        _toggleRow('Stín (Shadow)', s.shadowEnabled, (v) { s.shadowEnabled = v; _update(); }, icon: Icons.filter_drama_rounded),
        if (s.shadowEnabled) ...[
          _slider('Rozmazání', s.shadowBlur.toDouble(), 0, 50, (v) { s.shadowBlur = v.toInt(); _update(); }, suffix: '${s.shadowBlur}'),
          _slider('Offset Y', s.shadowOffsetY.toDouble(), -30, 30, (v) { s.shadowOffsetY = v.toInt(); _update(); }, suffix: '${s.shadowOffsetY}'),
        ],
        const SizedBox(height: 8),

        // Glow
        _toggleRow('Záře (Glow)', s.glowEnabled, (v) { s.glowEnabled = v; _update(); }, icon: Icons.wb_sunny_rounded),
        if (s.glowEnabled) ...[
          _colorRow('Barva záře', s.glowColor, (c) { s.glowColor = _colorToHex(c); _update(); }),
          _slider('Intenzita', s.glowIntensity, 0.0, 1.0, (v) { s.glowIntensity = v; _update(); }, suffix: '${(s.glowIntensity * 100).toInt()}%'),
        ],
        const SizedBox(height: 8),

        // Behind Person
        _toggleRow('Za osobou (Mask)', s.behindPerson, (v) { s.behindPerson = v; _update(); }, icon: Icons.person_pin_rounded),
        if (s.behindPerson) 
           const Padding(
             padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
             child: Text('Vyžaduje vygenerovanou masku v horním panelu.', style: TextStyle(color: Colors.white24, fontSize: 10, fontStyle: FontStyle.italic)),
           ),

        const SizedBox(height: 20),

        // === POZICE A ROTACE ===
        _section('POZICE A ROTACE'),
        Row(children: [
          Expanded(child: _numField('Pozice X', t.position['x'].toDouble(), (v) { t.position['x'] = v; _update(); })),
          const SizedBox(width: 6),
          Expanded(child: _numField('Pozice Y', t.position['y'].toDouble(), (v) { t.position['y'] = v; _update(); })),
        ]),
        const SizedBox(height: 12),
        _slider('Rotace X° (Náklon)', t.rotation['x'].toDouble(), -180, 180, (v) { t.rotation['x'] = v; _update(); }, suffix: '${t.rotation['x'].toInt()}°'),
        _slider('Rotace Y° (Otočení)', t.rotation['y'].toDouble(), -180, 180, (v) { t.rotation['y'] = v; _update(); }, suffix: '${t.rotation['y'].toInt()}°'),
        _slider('Rotace Z° (Zkosení)', t.rotation['z'].toDouble(), -180, 180, (v) { t.rotation['z'] = v; _update(); }, suffix: '${t.rotation['z'].toInt()}°'),


        const SizedBox(height: 30),
      ],
    );
  }

  // ─── Helper Widgets ───

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text, style: const TextStyle(color: Colors.white54, fontSize: 12)),
  );

  InputDecoration _inputDeco() => InputDecoration(
    filled: true, fillColor: Colors.white.withOpacity(0.05),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    isDense: true,
  );

  Widget _numField(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 3),
        SizedBox(
          height: 36,
          child: TextField(
            controller: TextEditingController(text: value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)),
            onSubmitted: (v) { final d = double.tryParse(v); if (d != null) onChanged(d); },
            style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
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
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 3),
        SizedBox(
          height: 36,
          child: DropdownButtonFormField<String>(
            value: items.contains(value) ? value : items.first,
            dropdownColor: const Color(0xFF1A1A1A),
            isDense: true,
            decoration: _inputDeco(),
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white, fontSize: 12)))).toList(),
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
          SizedBox(width: 60, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10))),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: const Color(0xFFD4AF37),
                inactiveTrackColor: const Color(0xFF333333),
                thumbColor: const Color(0xFFD4AF37),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                trackHeight: 3,
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
            ),
          ),
          SizedBox(width: 44, child: Text(suffix, style: const TextStyle(color: Colors.white38, fontSize: 11), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged, {IconData? icon}) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: value ? const Color(0xFFD4AF37).withOpacity(0.1) : const Color(0xFF17171E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: value ? const Color(0xFFD4AF37).withOpacity(0.6) : const Color(0xFF2C2C38),
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
                  color: value ? const Color(0xFFD4AF37) : Colors.white24,
                ),
                const SizedBox(width: 8),
                Text(
                  label, 
                  style: TextStyle(
                    color: value ? Colors.white : Colors.white60, 
                    fontSize: 12, 
                    fontWeight: value ? FontWeight.w600 : FontWeight.normal
                  )
                ),
              ]),
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? const Color(0xFFD4AF37) : Colors.transparent,
                  border: Border.all(color: value ? Colors.transparent : Colors.white24, width: 1.5),
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
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11))),
          GestureDetector(
            onTap: () => _pickColor(hex, onPicked),
            child: Container(width: 30, height: 30, decoration: BoxDecoration(color: _hex(hex), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFF444444)))),
          ),
          const SizedBox(width: 8),
          Text(hex, style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace')),
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
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 4),
            Container(height: 32, decoration: BoxDecoration(color: _hex(hex), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF444444)))),
          ],
        ),
      ),
    );
  }

  Widget _miniBtn(IconData icon, String tip, VoidCallback? onTap, {bool danger = false}) {
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: onTap == null ? Colors.transparent : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: danger ? const Color(0xFF662222) : Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: onTap == null ? Colors.white24 : (danger ? const Color(0xFFFF4444) : const Color(0xFFD4AF37))),
              const SizedBox(width: 4),
              Text(tip, style: TextStyle(fontSize: 11, color: onTap == null ? Colors.white24 : Colors.white70)),
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
        backgroundColor: const Color(0xFF16161C),
        titlePadding: const EdgeInsets.all(0),
        contentPadding: const EdgeInsets.all(0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.white10, width: 1)),
                    ),
                    child: const Center(child: Text('Kolo barev', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: ColorPicker(
                      pickerColor: activeColor,
                      onColorChanged: (c) {
                        setDialogState(() {
                          activeColor = c;
                        });
                      },
                      colorPickerWidth: 280,
                      pickerAreaHeightPercent: 0.7,
                      enableAlpha: false,
                      displayThumbColor: true,
                      paletteType: PaletteType.hsvWithHue,
                      labelTypes: const [],
                      pickerAreaBorderRadius: const BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx), 
                          child: const Text('Zrušit', style: TextStyle(color: Colors.white54))
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4AF37),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () { 
                            onPicked(activeColor); 
                            Navigator.pop(ctx); 
                          }, 
                          child: const Text('Použít', style: TextStyle(fontWeight: FontWeight.bold))
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
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
          const TabBar(
            labelColor: Color(0xFFD4AF37),
            unselectedLabelColor: Colors.white38,
            indicatorColor: Color(0xFFD4AF37),
            labelPadding: EdgeInsets.zero,
            indicatorWeight: 2,
            tabs: [
              Tab(icon: Icon(Icons.text_fields, size: 20), child: Text('Text', style: TextStyle(fontSize: 10))),
              Tab(icon: Icon(Icons.brush, size: 20), child: Text('Styl', style: TextStyle(fontSize: 10))),
              Tab(icon: Icon(Icons.auto_fix_high, size: 20), child: Text('Efekty', style: TextStyle(fontSize: 10))),
              Tab(icon: Icon(Icons.open_with, size: 20), child: Text('Pozice', style: TextStyle(fontSize: 10))),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // TAB 1: TEXT & PRESETS
                ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  children: [
                    _section('MOJE PRESETY'),
                    if (widget.presets.isEmpty) const Padding(padding: EdgeInsets.only(bottom:8), child: Text('Zatím žádné šablony.', style: TextStyle(color: Colors.white24, fontSize: 10))),
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: [
                        ...widget.presets.asMap().entries.map((entry) => InkWell(
                          onTap: () => widget.onApplyPreset(entry.value),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3))),
                            child: Text('Šab. ${entry.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                          ),
                        )),
                        InkWell(
                          onTap: () => widget.onSavePreset(c.style),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFD4AF37))),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add, size: 12, color: Color(0xFFD4AF37)), SizedBox(width:2), Text('Uložit', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 10, fontWeight: FontWeight.bold))]),
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
                      style: const TextStyle(color: Colors.white, fontSize: 13),
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
                    _section('FONT A VELIKOST'),
                    _dropdownField('Font', _fonts, _fonts.contains(s.fontFamily) ? s.fontFamily : 'Inter', (v) { s.fontFamily = v; _update(); }),
                    _slider('Velikost', s.fontSize.toDouble(), 20, 200, (v) { s.fontSize = v.toInt(); _update(); }, suffix: '${s.fontSize}px'),
                    const SizedBox(height: 12),
                    _section('BARVY'),
                    Row(children: [
                      GestureDetector(
                        onTap: () => _pickColor(s.colorSolid, (col) { s.colorSolid = _colorToHex(col); _update(); }),
                        child: Container(width: 36, height: 36, decoration: BoxDecoration(color: _hex(s.colorSolid), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey))),
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
                          'Styl', 
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
                          s.gradientColors = List<String>.from(s.gradientColors.isEmpty ? ['#FFD700','#D4AF37'] : s.gradientColors);
                          s.gradientColors[0]=_colorToHex(col); _update(); 
                        })),
                        const SizedBox(width: 8),
                        Expanded(child: _colorBox('B2', s.gradientColors.length > 1 ? s.gradientColors[1] : '#D4AF37', (col) { 
                          s.gradientColors = List<String>.from(s.gradientColors.length < 2 ? ['#FFD700','#D4AF37'] : s.gradientColors); 
                          s.gradientColors[1]=_colorToHex(col); _update(); 
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
                // TAB 3: EFFECTS & MASK
                ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  children: [
                    _section('VRSTVENÍ A KRYTÍ'),
                    _slider('Krytí', s.opacity, 0, 1, (v) { s.opacity = v; _update(); }),
                    const SizedBox(height: 4),
                    _dropdownField('Styl', _blendModes, _blendModes.contains(s.blendMode) ? s.blendMode : 'normal', (v) { s.blendMode = v; _update(); }),
                    const SizedBox(height: 12),
                    _toggleRow('Skrýt za osobu', s.behindPerson, (v) { s.behindPerson = v; _update(); }, icon: Icons.person_pin_rounded),
                    const SizedBox(height: 12),
                    _section('OBRYS A STÍN'),
                    _toggleRow('Obrys', s.strokeEnabled, (v) { s.strokeEnabled = v; _update(); }, icon: Icons.border_style_rounded),
                    if (s.strokeEnabled) ...[
                      _slider('Šířka', s.strokeWidth.toDouble(), 0, 20, (v) { s.strokeWidth = v.toInt(); _update(); }),
                      _colorRow('Barva', s.strokeColor, (col) { s.strokeColor = _colorToHex(col); _update(); }),
                    ],
                    const SizedBox(height: 8),
                    _toggleRow('Stín', s.shadowEnabled, (v) { s.shadowEnabled = v; _update(); }, icon: Icons.filter_drama_rounded),
                    if (s.shadowEnabled) ...[
                      _slider('Rozmaz', s.shadowBlur.toDouble(), 0, 50, (v) { s.shadowBlur = v.toInt(); _update(); }),
                      _slider('Y-Pos', s.shadowOffsetY.toDouble(), -30, 30, (v) { s.shadowOffsetY = v.toInt(); _update(); }),
                    ],
                    const SizedBox(height: 8),
                    _toggleRow('Záře', s.glowEnabled, (v) { s.glowEnabled = v; _update(); }, icon: Icons.wb_sunny_rounded),
                    if (s.glowEnabled) ...[
                      _colorRow('Záře', s.glowColor, (col) { s.glowColor = _colorToHex(col); _update(); }),
                      _slider('Intenz', s.glowIntensity, 0, 1, (v) { s.glowIntensity = v; _update(); }),
                    ],
                  ],
                ),
                // TAB 4: 3D POS & TRANSFORMS
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

/// Simple color grid picker
class _SimpleColorGrid extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;
  const _SimpleColorGrid({required this.initialColor, required this.onColorChanged});

  @override
  State<_SimpleColorGrid> createState() => _SimpleColorGridState();
}

class _SimpleColorGridState extends State<_SimpleColorGrid> {
  late Color _selected;

  static final _colors = [
    '#FFFFFF', '#CCCCCC', '#999999', '#666666', '#333333', '#000000',
    '#FF0000', '#FF4444', '#FF6666', '#CC0000', '#990000', '#660000',
    '#FF8800', '#FFAA33', '#FFCC66', '#CC6600', '#994400', '#662200',
    '#FFFF00', '#FFFF44', '#FFFF88', '#CCCC00', '#999900', '#666600',
    '#00FF00', '#44FF44', '#88FF88', '#00CC00', '#009900', '#006600',
    '#00FFFF', '#44FFFF', '#88FFFF', '#00CCCC', '#009999', '#006666',
    '#0000FF', '#4444FF', '#6666FF', '#0000CC', '#000099', '#000066',
    '#FF00FF', '#FF44FF', '#FF88FF', '#CC00CC', '#990099', '#660066',
    '#FFD700', '#D4AF37', '#AA771C', '#FFE066', '#B8860B', '#8B6914',
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, crossAxisSpacing: 4, mainAxisSpacing: 4),
      itemCount: _colors.length,
      itemBuilder: (ctx, i) {
        final hex = _colors[i];
        final c = Color(int.parse('FF${hex.replaceAll("#", "")}', radix: 16));
        final isSel = c.value == _selected.value;
        return GestureDetector(
          onTap: () {
            setState(() => _selected = c);
            widget.onColorChanged(c);
          },
          child: Container(
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: isSel ? Colors.white : Colors.transparent, width: isSel ? 3 : 1),
            ),
          ),
        );
      },
    );
  }
}
