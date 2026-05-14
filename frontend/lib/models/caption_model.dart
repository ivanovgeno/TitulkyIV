class CaptionProject {
  final String projectId;
  final String language;
  final Resolution resolution;
  final List<Caption> captions;

  CaptionProject({
    required this.projectId,
    required this.language,
    required this.resolution,
    required this.captions,
  });

  factory CaptionProject.fromJson(Map<String, dynamic> json) {
    return CaptionProject(
      projectId: json['project_id'],
      language: json['language'],
      resolution: Resolution.fromJson(json['resolution']),
      captions: (json['captions'] as List)
          .map((c) => Caption.fromJson(c))
          .toList(),
    );
  }
}

class Resolution {
  final int width;
  final int height;

  Resolution({required this.width, required this.height});

  factory Resolution.fromJson(Map<String, dynamic> json) {
    return Resolution(
      width: json['width'],
      height: json['height'],
    );
  }
}

class Caption {
  final String id;
  String text;
  double startTime;
  double endTime;
  String category;
  CaptionStyle style;
  Transform3D transform3D;
  int track;
  String animationIn;
  String animationOut;
  String sfxIn;
  String sfxOut;
  int sfxVolume;

  Caption({
    required this.id,
    required this.text,
    required this.startTime,
    required this.endTime,
    required this.category,
    required this.style,
    required this.transform3D,
    this.track = 0,
    this.animationIn = 'none',
    this.animationOut = 'none',
    this.sfxIn = 'none',
    this.sfxOut = 'none',
    this.sfxVolume = 30,
  });

  factory Caption.fromJson(Map<String, dynamic> json) {
    return Caption(
      id: json['id'],
      text: json['text'],
      startTime: json['start_time'].toDouble(),
      endTime: json['end_time'].toDouble(),
      category: json['category'] ?? 'Main',
      style: CaptionStyle.fromJson(json['style'] ?? {}),
      transform3D: Transform3D.fromJson(json['transform_3d'] ?? {}),
      track: json['track'] ?? 0,
      animationIn: json['animation_in'] ?? 'none',
      animationOut: json['animation_out'] ?? 'none',
      sfxIn: json['sfx_in'] is String ? json['sfx_in'] : (json['sfx_in'] == true ? 'pop' : 'none'),
      sfxOut: json['sfx_out'] is String ? json['sfx_out'] : (json['sfx_out'] == true ? 'pop' : 'none'),
      sfxVolume: json['sfx_volume'] ?? 30,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'start_time': startTime,
      'end_time': endTime,
      'category': category,
      'style': style.toJson(),
      'transform_3d': transform3D.toJson(),
      'track': track,
      'animation_in': animationIn,
      'animation_out': animationOut,
      'sfx_in': sfxIn,
      'sfx_out': sfxOut,
      'sfx_volume': sfxVolume,
    };
  }
}

class CaptionStyle {
  String fontFamily;
  String fontWeight;
  int fontSize;
  
  // Colors
  String colorSolid; // Hex like "#FFFFFF"
  bool useGradient;
  List<String> gradientColors; // e.g. ["#FFD700", "#D4AF37"]
  
  // Stroke (Obrys)
  bool strokeEnabled;
  int strokeWidth;
  String strokeColor;
  
  // Shadow (Stín)
  bool shadowEnabled;
  int shadowBlur;
  String shadowColor;
  int shadowOffsetX;
  int shadowOffsetY;
  
  // Glow (Záře)
  bool glowEnabled;
  String glowColor;
  double glowIntensity; // 0.0 - 1.0
  double gradientRatio; // 0.0 - 1.0 for stops
  bool behindPerson;
  
  // Davinci Effects (Opacity, Blending)
  double opacity; // 0.0 - 1.0
  String blendMode; // 'normal', 'multiply', 'screen', 'overlay', etc.
  
  // Advanced Gradients
  double gradientAngle; // 0 - 360
  String gradientType; // 'linear', 'radial', 'sweep'

  CaptionStyle({
    this.fontFamily = 'Inter',
    this.fontWeight = '900',
    this.fontSize = 90,
    this.colorSolid = '#FFFFFF',
    this.useGradient = false,
    this.gradientColors = const ['#FFD700', '#D4AF37'],
    this.gradientRatio = 0.5,
    this.behindPerson = false,
    this.strokeEnabled = true,
    this.strokeWidth = 6,
    this.strokeColor = '#000000',
    this.shadowEnabled = true,
    this.shadowBlur = 20,
    this.shadowColor = '#000000',
    this.shadowOffsetX = 0,
    this.shadowOffsetY = 8,
    this.glowEnabled = false,
    this.glowColor = '#D4AF37',
    this.glowIntensity = 0.4,
    this.opacity = 1.0,
    this.blendMode = 'normal',
    this.gradientAngle = 90.0,
    this.gradientType = 'linear',
  });

  factory CaptionStyle.fromJson(Map<String, dynamic> json) {
    // Parse color - can be string "#FFFFFF" or map with gradient info
    String colorSolid = '#FFFFFF';
    bool useGradient = false;
    List<String> gradientColors = ['#FFD700', '#D4AF37'];
    
    final rawColor = json['color'];
    if (rawColor is String) {
      colorSolid = rawColor;
    } else if (rawColor is Map) {
      if (rawColor['type'] == 'gradient') {
        useGradient = true;
        gradientColors = List<String>.from(rawColor['colors'] ?? ['#FFD700', '#D4AF37']);
        colorSolid = gradientColors.isNotEmpty ? gradientColors.first : '#FFFFFF';
      } else if (rawColor['type'] == 'solid') {
        colorSolid = rawColor['value'] ?? '#FFFFFF';
      }
    }

    double gradientAngle = 90.0;
    String gradientType = 'linear';
    double gradientRatio = 0.5;
    if (json['gradient_ext'] is Map) {
      final ext = json['gradient_ext'] as Map;
      gradientAngle = (ext['angle'] ?? 90.0).toDouble();
      gradientType = ext['type'] ?? 'linear';
      gradientRatio = (ext['ratio'] ?? 0.5).toDouble();
    } else if (json['gradient_ratio'] != null) {
      gradientRatio = (json['gradient_ratio']).toDouble();
    }

    // Parse stroke
    final rawStroke = json['stroke'];
    bool strokeEnabled = rawStroke != null;
    int strokeWidth = 6;
    String strokeColor = '#000000';
    if (rawStroke is Map) {
      strokeWidth = rawStroke['width'] ?? 6;
      strokeColor = rawStroke['color'] ?? '#000000';
    }

    // Parse shadow
    final rawShadow = json['shadow'];
    bool shadowEnabled = rawShadow != null;
    int shadowBlur = 20;
    String shadowColor = '#000000';
    int shadowOffsetX = 0;
    int shadowOffsetY = 8;
    if (rawShadow is Map) {
      shadowBlur = rawShadow['blur'] ?? 20;
      shadowColor = rawShadow['color'] is String ? rawShadow['color'].toString().replaceAll(RegExp(r'rgba?\([^)]+\)'), '#000000') : '#000000';
      if (shadowColor.startsWith('rgba')) shadowColor = '#000000';
      shadowOffsetX = rawShadow['offset_x'] ?? 0;
      shadowOffsetY = rawShadow['offset_y'] ?? 8;
    }

    // Parse glow
    final rawGlow = json['glow'];
    bool glowEnabled = rawGlow != null;
    String glowColor = '#D4AF37';
    double glowIntensity = 0.4;
    if (rawGlow is Map) {
      glowColor = rawGlow['color'] ?? '#D4AF37';
      glowIntensity = (rawGlow['intensity'] ?? 0.4).toDouble();
    }

    return CaptionStyle(
      fontFamily: json['font_family'] ?? 'Inter',
      fontWeight: json['font_weight']?.toString() ?? '900',
      fontSize: json['font_size'] ?? 90,
      colorSolid: colorSolid,
      useGradient: useGradient,
      gradientColors: gradientColors,
      behindPerson: json['behind_person'] ?? false,
      strokeEnabled: strokeEnabled,
      strokeWidth: strokeWidth,
      strokeColor: strokeColor,
      shadowEnabled: shadowEnabled,
      shadowBlur: shadowBlur,
      shadowColor: shadowColor,
      shadowOffsetX: shadowOffsetX,
      shadowOffsetY: shadowOffsetY,
      glowEnabled: glowEnabled,
      glowColor: glowColor,
      glowIntensity: glowIntensity,
      opacity: (json['opacity'] ?? 1.0).toDouble(),
      blendMode: json['blend_mode'] ?? 'normal',
      gradientRatio: gradientRatio,
      gradientAngle: gradientAngle,
      gradientType: gradientType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'font_family': fontFamily,
      'font_weight': fontWeight,
      'font_size': fontSize,
      'color': useGradient
          ? {'type': 'gradient', 'colors': gradientColors, 'ratio': gradientRatio}
          : colorSolid,
      if (strokeEnabled) 'stroke': {'width': strokeWidth, 'color': strokeColor},
      if (shadowEnabled) 'shadow': {'color': shadowColor, 'blur': shadowBlur, 'offset_x': shadowOffsetX, 'offset_y': shadowOffsetY},
      if (glowEnabled) 'glow': {'intensity': glowIntensity, 'color': glowColor},
      'behind_person': behindPerson,
      'opacity': opacity,
      'blend_mode': blendMode,
      'gradient_ext': {
        'angle': gradientAngle,
        'type': gradientType,
        'ratio': gradientRatio,
      }
    };
  }

  CaptionStyle copy() {
    return CaptionStyle(
      fontFamily: fontFamily,
      fontWeight: fontWeight,
      fontSize: fontSize,
      colorSolid: colorSolid,
      useGradient: useGradient,
      gradientColors: List<String>.from(gradientColors),
      gradientRatio: gradientRatio,
      behindPerson: behindPerson,
      strokeEnabled: strokeEnabled,
      strokeWidth: strokeWidth,
      strokeColor: strokeColor,
      shadowEnabled: shadowEnabled,
      shadowBlur: shadowBlur,
      shadowColor: shadowColor,
      shadowOffsetX: shadowOffsetX,
      shadowOffsetY: shadowOffsetY,
      glowEnabled: glowEnabled,
      glowColor: glowColor,
      glowIntensity: glowIntensity,
      opacity: opacity,
      blendMode: blendMode,
      gradientAngle: gradientAngle,
      gradientType: gradientType,
    );
  }
}

class Transform3D {
  Map<String, dynamic> position;
  Map<String, dynamic> rotation;
  bool meshBendEnabled;

  Transform3D({
    required this.position,
    required this.rotation,
    required this.meshBendEnabled,
  });

  factory Transform3D.fromJson(Map<String, dynamic> json) {
    return Transform3D(
      position: json['position'] ?? {"x": 0, "y": 0, "z": 0},
      rotation: json['rotation'] ?? {"x": 0.0, "y": 0.0, "z": 0.0},
      meshBendEnabled: json['mesh_bend']?['enabled'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'position': position,
      'rotation': rotation,
      'mesh_bend': {'enabled': meshBendEnabled},
    };
  }
}
