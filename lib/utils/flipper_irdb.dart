import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';
import '../models/ir_device.dart';

/// Utility for managing flipper-irdb from zip extraction
class FlipperIRDB {
  static String? _extractedPath;
  static bool _isInitialized = false;

  /// Get the path where the IRDB is extracted
  static Future<String> get extractedPath async {
    if (_extractedPath != null) return _extractedPath!;
    
    final appDir = await getApplicationDocumentsDirectory();
    _extractedPath = path.join(appDir.path, 'flipper-irdb');
    return _extractedPath!;
  }

  /// Extract the zip asset to app documents directory
  static Future<void> _extractZipAsset() async {
    try {
      print('Loading zip asset...');
      final byteData = await rootBundle.load('assets/flipper-irdb.zip');
      final bytes = byteData.buffer.asUint8List();
      
      print('Decoding zip archive...');
      final archive = ZipDecoder().decodeBytes(bytes);
      
      final extractPath = await extractedPath;
      final extractDir = Directory(extractPath);
      
      print('Extracting to: $extractPath');
      int fileCount = 0;
      
      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final filePath = path.join(extractPath, filename);
          final fileDir = Directory(path.dirname(filePath));
          
          if (!await fileDir.exists()) {
            await fileDir.create(recursive: true);
          }
          
          final outFile = File(filePath);
          await outFile.writeAsBytes(file.content as List<int>);
          fileCount++;
          
          if (fileCount % 100 == 0) {
            print('Extracted $fileCount files...');
          }
        }
      }
      
      print('Extraction completed: $fileCount files extracted');
      
      // Mark as initialized
      final flagFile = File(path.join(extractPath, '.initialized'));
      await flagFile.writeAsString('${DateTime.now().toIso8601String()}');
      
    } catch (e) {
      print('Error extracting zip: $e');
      rethrow;
    }
  }

  /// Check if the IRDB has been extracted
  static Future<bool> _isExtracted() async {
    final extractPath = await extractedPath;
    final extractDir = Directory(extractPath);
    final flagFile = File(path.join(extractPath, '.initialized'));
    
    // Check if both directory exists and has content, and flag file exists
    if (!await extractDir.exists() || !await flagFile.exists()) {
      return false;
    }
    
    // Double check by looking for actual content
    try {
      int fileCount = 0;
      await for (final entity in extractDir.list(recursive: true)) {
        if (entity is File && path.extension(entity.path) == '.ir') {
          fileCount++;
          if (fileCount >= 10) break; // Found enough files, we're good
        }
      }
      return fileCount >= 10; // Should have at least 10 IR files
    } catch (e) {
      print('Error checking extracted content: $e');
      return false;
    }
  }

  /// Initialize the IRDB (extract if needed)
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    print('Checking if flipper-irdb is extracted...');
    if (!await _isExtracted()) {
      print('First run - extracting flipper-irdb...');
      await _extractZipAsset();
    } else {
      print('flipper-irdb already extracted');
    }
    
    _isInitialized = true;
  }

  /// Get all categories by scanning directories
  static Future<List<String>> getCategories() async {
    await initialize();
    
    final extractPath = await extractedPath;
    final irdbDir = Directory(extractPath);
    
    if (!await irdbDir.exists()) {
      print('IRDB directory does not exist: $extractPath');
      return [];
    }

    final categories = <String>[];
    
    await for (final entity in irdbDir.list()) {
      if (entity is Directory) {
        final categoryName = path.basename(entity.path);
        // Skip hidden and system directories
        if (!categoryName.startsWith('.') && categoryName != 'README.md') {
          categories.add(categoryName);
        }
      }
    }
    
    categories.sort();
    print('Found categories: $categories');
    return categories;
  }

  /// Get all brands for a category by scanning directories
  static Future<List<String>> getBrands(String category) async {
    await initialize();
    
    final extractPath = await extractedPath;
    final categoryDir = Directory(path.join(extractPath, category));
    
    if (!await categoryDir.exists()) {
      print('Category directory does not exist: ${categoryDir.path}');
      return [];
    }

    final brands = <String>[];
    
    await for (final entity in categoryDir.list()) {
      if (entity is Directory) {
        final brandName = path.basename(entity.path);
        brands.add(brandName);
      }
    }
    
    brands.sort();
    print('Found brands for $category: $brands');
    return brands;
  }

  /// Get all devices for a brand by scanning .ir files
  static Future<List<String>> getDeviceFiles(String category, String brand) async {
    await initialize();
    
    final extractPath = await extractedPath;
    final brandDir = Directory(path.join(extractPath, category, brand));
    
    if (!await brandDir.exists()) {
      print('Brand directory does not exist: ${brandDir.path}');
      return [];
    }

    final devices = <String>[];
    
    await for (final entity in brandDir.list()) {
      if (entity is File && path.extension(entity.path) == '.ir') {
        final deviceName = path.basenameWithoutExtension(entity.path);
        devices.add(deviceName);
      }
    }
    
    devices.sort();
    print('Found devices for $category/$brand: $devices');
    return devices;
  }

  /// Parse an IR file from the extracted directory
  static Future<IRDevice?> parseDeviceFile(String category, String brand, String device) async {
    await initialize();
    
    final extractPath = await extractedPath;
    final devicePath = path.join(extractPath, category, brand, '$device.ir');
    final deviceFile = File(devicePath);
    
    if (!await deviceFile.exists()) {
      print('Device file does not exist: $devicePath');
      return null;
    }

    try {
      final content = await deviceFile.readAsString();
      return _parseIRContent(content, device, category, brand);
    } catch (e) {
      print('Error loading device $device: $e');
      return null;
    }
  }

  /// Parse IR file content dynamically
  static IRDevice _parseIRContent(String content, String deviceName, String category, String brand) {
    final lines = content.split('\n');
    List<IRButton> buttons = [];
    
    String? currentButtonName;
    String? currentButtonType;
    String? currentButtonProtocol;
    String currentButtonData = '';
    
    for (String line in lines) {
      line = line.trim();
      
      if (line.isEmpty || line.startsWith('#') || line.startsWith('Filetype:') || line.startsWith('Version:')) {
        continue;
      }
      
      if (line.startsWith('name:')) {
        // Save previous button if exists
        if (currentButtonName != null && (currentButtonProtocol != null || currentButtonType == 'raw')) {
          // Parse the data for the new format
          final parsedData = _parseButtonData(currentButtonData.trim(), currentButtonProtocol, currentButtonType);
          
          buttons.add(IRButton(
            name: currentButtonName,
            type: currentButtonType ?? 'parsed',
            protocol: parsedData['protocol'],
            address: parsedData['address'],
            command: parsedData['command'],
            frequency: parsedData['frequency'],
            dutyCycle: parsedData['dutyCycle'],
            data: parsedData['data'],
          ));
        }
        
        // Start new button
        currentButtonName = line.substring(5).trim();
        currentButtonType = null;
        currentButtonProtocol = null;
        currentButtonData = '';
      } else if (line.startsWith('type:')) {
        currentButtonType = line.substring(5).trim();
      } else if (line.startsWith('protocol:')) {
        currentButtonProtocol = line.substring(9).trim();
      } else if (line.contains(':')) {
        // Any other key:value pair is part of the button data
        currentButtonData += line + '\n';
      }
    }
    
    // Don't forget the last button
    if (currentButtonName != null && (currentButtonProtocol != null || currentButtonType == 'raw')) {
      final parsedData = _parseButtonData(currentButtonData.trim(), currentButtonProtocol, currentButtonType);
      
      buttons.add(IRButton(
        name: currentButtonName,
        type: currentButtonType ?? 'parsed',
        protocol: parsedData['protocol'],
        address: parsedData['address'],
        command: parsedData['command'],
        frequency: parsedData['frequency'],
        dutyCycle: parsedData['dutyCycle'],
        data: parsedData['data'],
      ));
    }
    
    return IRDevice(
      name: '$brand $deviceName',
      brand: brand,
      category: _capitalizeCategory(category),
      buttons: buttons,
      description: 'From flipper-irdb: $category/$brand',
    );
  }

  /// Check if IRDB is available
  static Future<bool> isIRDBAvailable() async {
    try {
      await initialize();
      final extractPath = await extractedPath;
      final irdbDir = Directory(extractPath);
      return await irdbDir.exists();
    } catch (e) {
      return false;
    }
  }

  /// Get directory structure info
  static Future<Map<String, dynamic>> getDirectoryInfo() async {
    try {
      await initialize();
      final extractPath = await extractedPath;
      final categories = await getCategories();
      
      int totalFiles = 0;
      for (final category in categories) {
        final brands = await getBrands(category);
        for (final brand in brands) {
          final devices = await getDeviceFiles(category, brand);
          totalFiles += devices.length;
        }
      }

      return {
        'exists': categories.isNotEmpty,
        'path': extractPath,
        'totalCategories': categories.length,
        'totalDevices': totalFiles,
      };
    } catch (e) {
      return {
        'exists': false,
        'path': null,
        'totalCategories': 0,
        'totalDevices': 0,
        'error': e.toString(),
      };
    }
  }

  /// Capitalize category name for display
  static String _capitalizeCategory(String category) {
    if (category.isEmpty) return category;
    return category.split('_').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Parse button data from IR file format to new button model
  static Map<String, dynamic> _parseButtonData(String data, String? protocol, String? type) {
    final Map<String, dynamic> parsed = {
      'protocol': protocol,
      'address': null,
      'command': null,
      'frequency': null,
      'dutyCycle': null,
      'data': null,
    };

    final lines = data.split('\n');
    for (String line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('address:')) {
        parsed['address'] = line.substring(8).trim();
      } else if (line.startsWith('command:')) {
        parsed['command'] = line.substring(8).trim();
      } else if (line.startsWith('frequency:')) {
        parsed['frequency'] = int.tryParse(line.substring(10).trim());
      } else if (line.startsWith('duty_cycle:')) {
        parsed['dutyCycle'] = double.tryParse(line.substring(11).trim());
      } else if (line.startsWith('data:')) {
        final dataStr = line.substring(5).trim();
        try {
          parsed['data'] = dataStr.split(' ')
              .where((s) => s.isNotEmpty)
              .map((s) => int.parse(s.trim()))
              .toList();
        } catch (e) {
          print('Error parsing data: $e');
        }
      }
    }

    return parsed;
  }
}
