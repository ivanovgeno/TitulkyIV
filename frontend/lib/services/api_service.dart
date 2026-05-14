import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/caption_model.dart';

class ApiService {
  // Automatically detects environment and platform for seamless multi-platform use.
  static String get baseUrl {
    // V produkčním (online) prostředí použijeme online backend
    if (kReleaseMode) {
      return 'https://genzawhat-titulkyiv.hf.space/api/v1';
    }
    // Pro lokální vývoj na síti použijeme vaši lokální IP
    return 'http://10.0.1.12:8000/api/v1';
  }

  /// Uploads video bytes to the backend to start transcription (Web & Desktop compatible)
  Future<String?> uploadVideoForTranscription(Uint8List bytes, String filename) async {
    var uri = Uri.parse('$baseUrl/process/transcribe');
    var request = http.MultipartRequest('POST', uri);
    
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      ),
    );
    
    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        // The backend returns a project_id to poll for status
        return jsonResponse['project_id'];
      } else {
        print('Upload failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error uploading video: $e');
      return null;
    }
  }

  /// Polls the server to check if transcription is done and returns the CaptionProject
  Future<CaptionProject?> checkTranscriptionStatus(String projectId) async {
    var uri = Uri.parse('$baseUrl/process/result/$projectId');
    
    try {
      var response = await http.get(uri);
      
      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        
        if (jsonResponse['status'] == 'completed') {
          return CaptionProject.fromJson(jsonResponse['data']);
        } else {
          // Still processing
          return null;
        }
      }
      return null;
    } catch (e) {
      print('Error checking status: $e');
      return null;
    }
  }

  /// Uploads video bytes to the backend to start Mask generation
  Future<String?> uploadVideoForMasking(Uint8List bytes, String filename) async {
    var uri = Uri.parse('$baseUrl/generate-mask');
    var request = http.MultipartRequest('POST', uri);
    
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      ),
    );
    
    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        return jsonResponse['project_id']; // Vrátí ID maskovacího procesu
      } else {
        print('Mask Upload failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error uploading video for mask: $e');
      return null;
    }
  }

  /// Polls the server to check if Mask generation is done
  Future<Map<String, String>?> checkMaskStatus(String projectId) async {
    var uri = Uri.parse('$baseUrl/generate-mask/status/$projectId');
    
    try {
      var response = await http.get(uri);
      
      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        
        if (jsonResponse['status'] == 'completed') {
          return {
            'webm': jsonResponse['mask_url_webm'],
            'mov': jsonResponse['mask_url_mov'],
            'bw': jsonResponse['mask_url_bw'] ?? '',
          };
        } else if (jsonResponse['status'] == 'error') {
          throw Exception(jsonResponse['message']);
        }
        return null; // Zpracovává se
      }
      return null;
    } catch (e) {
      print('Error checking mask status: $e');
      throw e;
    }
  }
}
