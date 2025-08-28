import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class AppSettings {
  static const String _settingsFileName = 'app_settings.json';
  
  // Default values
  static const bool defaultTransmitterAvailable = true;
  
  // Get settings file
  static Future<File> _getSettingsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_settingsFileName');
  }
  
  // Load settings from file
  static Future<Map<String, dynamic>> _loadSettings() async {
    try {
      final file = await _getSettingsFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        return json.decode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      // Return default values if file doesn't exist or is corrupted
    }
    return {
      'transmitter_available': defaultTransmitterAvailable,
    };
  }
  
  // Save settings to file
  static Future<void> _saveSettings(Map<String, dynamic> settings) async {
    try {
      final file = await _getSettingsFile();
      await file.writeAsString(json.encode(settings));
    } catch (e) {
      // Ignore save errors
    }
  }
  
  // Get transmitter availability
  static Future<bool> getTransmitterAvailable() async {
    final settings = await _loadSettings();
    return settings['transmitter_available'] as bool? ?? defaultTransmitterAvailable;
  }
  
  // Set transmitter availability
  static Future<void> setTransmitterAvailable(bool available) async {
    final settings = await _loadSettings();
    settings['transmitter_available'] = available;
    await _saveSettings(settings);
  }
}
