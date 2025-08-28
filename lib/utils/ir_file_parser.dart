import 'dart:io';
import '../models/ir_device.dart';

/// Minimal IR file parser for Flipper Zero .ir files
class IRFileParser {
  /// Parse a Flipper Zero .ir file
  static Future<IRDevice?> parseIRFile(String filePath) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString();
      final fileName = filePath.split('/').last.replaceAll('.ir', '');
      
      return _parseIRContent(content, fileName);
    } catch (e) {
      throw Exception('Failed to parse IR file: $e');
    }
  }

  /// Parse IR file content directly
  static IRDevice? parseIRFileContent(String content, [String? fileName]) {
    try {
      if (!isValidIRFile(content)) {
        return null;
      }
      return _parseIRContent(content, fileName ?? 'Custom Device');
    } catch (e) {
      print('Error parsing IR file content: $e');
      return null;
    }
  }

  /// Parse IR file content
  static IRDevice _parseIRContent(String content, String fileName) {
    final lines = content.split('\n');
    List<IRButton> buttons = [];
    
    // Try to extract device name and brand from comments
    String deviceName = fileName;
    String deviceBrand = 'Unknown';
    
    for (String line in lines) {
      line = line.trim();
      if (line.startsWith('# Device:')) {
        deviceName = line.substring(9).trim();
      } else if (line.startsWith('# Brand:')) {
        deviceBrand = line.substring(8).trim();
      }
    }
    
    String? currentButtonName;
    String? currentButtonType;
    String? currentButtonProtocol;
    String? currentAddress;
    String? currentCommand;
    int? currentFrequency;
    double? currentDutyCycle;
    List<int>? currentData;
    
    for (String line in lines) {
      line = line.trim();
      
      if (line.isEmpty) continue;
      
      if (line.startsWith('#')) {
        // # indicates end of button definition, save current button if complete
        if (currentButtonName != null) {
          buttons.add(IRButton(
            name: currentButtonName,
            type: currentButtonType ?? 'parsed',
            protocol: currentButtonProtocol,
            address: currentAddress,
            command: currentCommand,
            frequency: currentFrequency,
            dutyCycle: currentDutyCycle,
            data: currentData,
          ));
        }
        // Reset for next button
        currentButtonName = null;
        currentButtonType = null;
        currentButtonProtocol = null;
        currentAddress = null;
        currentCommand = null;
        currentFrequency = null;
        currentDutyCycle = null;
        currentData = null;
        continue;
      }
      
      if (line.startsWith('name:')) {
        currentButtonName = line.substring(5).trim();
      } else if (line.startsWith('type:')) {
        currentButtonType = line.substring(5).trim();
      } else if (line.startsWith('protocol:')) {
        currentButtonProtocol = line.substring(9).trim();
      } else if (line.startsWith('address:')) {
        currentAddress = line.substring(8).trim();
      } else if (line.startsWith('command:')) {
        currentCommand = line.substring(8).trim();
      } else if (line.startsWith('frequency:')) {
        currentFrequency = int.tryParse(line.substring(10).trim());
      } else if (line.startsWith('duty_cycle:')) {
        currentDutyCycle = double.tryParse(line.substring(11).trim());
      } else if (line.startsWith('data:')) {
        final dataStr = line.substring(5).trim();
        try {
          currentData = dataStr.split(' ')
              .where((s) => s.isNotEmpty)
              .map((s) => int.parse(s.trim()))
              .toList();
        } catch (e) {
          print('Error parsing data: $e');
        }
      }
    }
    
    // Add last button if exists
    if (currentButtonName != null) {
      buttons.add(IRButton(
        name: currentButtonName,
        type: currentButtonType ?? 'parsed',
        protocol: currentButtonProtocol,
        address: currentAddress,
        command: currentCommand,
        frequency: currentFrequency,
        dutyCycle: currentDutyCycle,
        data: currentData,
      ));
    }
    
    return IRDevice(
      name: deviceName,
      brand: deviceBrand,
      category: _determineCategory(deviceName, buttons),
      buttons: buttons,
    );
  }

  /// Determine device category based on name and buttons
  static String _determineCategory(String deviceName, List<IRButton> buttons) {
    final name = deviceName.toLowerCase();
    final buttonNames = buttons.map((b) => b.name.toLowerCase()).join(' ');
    
    if (name.contains('tv') || buttonNames.contains('channel')) {
      return 'TV';
    } else if (name.contains('ac') || name.contains('air')) {
      return 'AC';
    } else if (name.contains('audio') || name.contains('speaker')) {
      return 'Audio';
    } else if (name.contains('fan')) {
      return 'Fan';
    } else if (name.contains('light')) {
      return 'Light';
    }
    
    return 'Other';
  }

  /// Check if content is valid IR format
  static bool isValidIRFile(String content) {
    if (content.trim().isEmpty) return false;
    
    // Check for essential IR file components
    final hasProtocol = content.contains('protocol:');
    final hasName = content.contains('name:');
    
    // Additional checks for common IR file patterns
    final hasFlipperFormat = content.contains('Filetype: IR signals file') || 
                           content.contains('Version:');
    final hasIRData = content.contains('address:') || 
                     content.contains('command:') || 
                     content.contains('data:') ||
                     content.contains('frequency:');
    
    // Must have at least name and either protocol or some IR data
    return (hasName && (hasProtocol || hasIRData)) || hasFlipperFormat;
  }
}
