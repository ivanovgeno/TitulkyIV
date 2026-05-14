import 'dart:convert';
import '../models/caption_model.dart';

class MockDataProvider {
  static Future<CaptionProject?> loadMockProject() async {
    try {
      final fallbackJson = '''
      {
        "project_id": "empty_project",
        "language": "cs",
        "resolution": {"width": 1080, "height": 1920},
        "captions": []
      }
      ''';
      return CaptionProject.fromJson(jsonDecode(fallbackJson));
    } catch (e) {
      print('Error loading initial data: \$e');
      return null;
    }
  }
}
