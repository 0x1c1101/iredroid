import 'package:flutter/services.dart';
import '../models/ir_device.dart';

class IRTransmitter {
  static const MethodChannel _channel = MethodChannel('org.nslabs/irtransmitter');
  
  /// Transmit an IR button signal
  static Future<void> transmitButton(IRButton button) async {
    await sendIR(button);
  }

  /// Transmits a hex (NEC) code.
  static Future<void> transmit(int code) async {
    await _channel.invokeMethod("transmit", {"list": convertNECtoList(code)});
  }

  /// Transmits raw IR data given a frequency and pattern.
  static Future<void> transmitRaw(int frequency, List<int> pattern) async {
    await _channel.invokeMethod("transmitRaw", {"frequency": frequency, "list": pattern});
  }

  /// Checks if the device has an IR emitter.
  static Future<bool> hasIrEmitter() async {
    try {
      return await _channel.invokeMethod("hasIrEmitter");
    } catch (e) {
      return false;
    }
  }

  /// Converts a NEC code into a timing list.
  static List<int> convertNECtoList(int nec) {
    List<int> list = [];
    list.add(9045);
    list.add(4050);

    String str = nec.toRadixString(2);
    str = str.padLeft(32, '0');

    for (int i = 0; i < str.length; i++) {
      list.add(600);
      if (str[i] == "0") {
        list.add(550);
      } else {
        list.add(1650);
      }
    }
    list.add(600);
    return list;
  }

  /// Converts RC5 address and command into a timing list.
  /// RC5 uses Manchester encoding with 889µs bit period  
  static List<int> convertRC5toList(int address, int command, {bool toggleBit = false}) {
    // RC5 timing constants - using exact Philips specification
    const int halfBitTime = 889; // 444µs = half of 889µs bit period
    
    // Build the 14-bit RC5 frame as binary string for clarity
    String frame = '';
    
    // Start bits (always 11)
    frame += '11';
    
    // Toggle bit 
    frame += toggleBit ? '1' : '0';
    
    // Address (5 bits, MSB first)
    frame += address.toRadixString(2).padLeft(5, '0');
    
    // Command (6 bits, MSB first)  
    frame += command.toRadixString(2).padLeft(6, '0');
    
    print('DEBUG: RC5 14-bit frame: $frame (addr=$address, cmd=$command)');
    
    // Create the waveform as a sequence of HIGH/LOW states
    // Each bit creates exactly 2 half-periods
    List<bool> waveform = [];
    
    for (String bitChar in frame.split('')) {
      bool bit = bitChar == '1';
      
      if (bit) {
        // '1' bit: HIGH-to-LOW transition (mark-space)
        waveform.add(true);  // First half HIGH
        waveform.add(false); // Second half LOW
      } else {
        // '0' bit: LOW-to-HIGH transition (space-mark)  
        waveform.add(false); // First half LOW
        waveform.add(true);  // Second half HIGH
      }
    }
    
    // Convert waveform to timing by merging adjacent identical states
    List<int> pattern = [];
    if (waveform.isEmpty) return pattern;
    
    bool currentState = waveform[0];
    int duration = halfBitTime;
    
    for (int i = 1; i < waveform.length; i++) {
      if (waveform[i] == currentState) {
        // Same state, extend duration
        duration += halfBitTime;
      } else {
        // State change, add current duration and start new
        pattern.add(duration);
        duration = halfBitTime;
        currentState = waveform[i];
      }
    }
    
    // Add final duration
    pattern.add(duration);
    
    // Debug: show the waveform sequence
    String waveformStr = waveform.map((state) => state ? 'H' : 'L').join('');
    print('DEBUG: RC5 waveform: $waveformStr');
    print('DEBUG: Pattern before adjustment: $pattern (length: ${pattern.length})');
    
    return pattern;
  }

  /// Converts RC6 address and command into a timing list.
  /// RC6 uses Manchester encoding with variable bit periods and a trailer bit
  static List<int> convertRC6toList(int address, int command, {bool toggleBit = false}) {
    // RC6 timing constants (in microseconds)
    const int halfBitTime = 444; // Half bit period (889µs / 2)
    const int leaderPulse = 2666; // Leader AGC burst
    const int leaderSpace = 889;  // Leader space
    const int trailerTime = 889;  // Trailer bit is twice normal bit time
    
    List<int> pattern = [];
    
    // Leader sequence: AGC burst + space
    pattern.add(leaderPulse);
    pattern.add(leaderSpace);
    
    // Start bit (always 1)
    pattern.add(halfBitTime); // High
    pattern.add(halfBitTime); // Low (Manchester '1')
    
    // Mode bits (3 bits, typically 000 for RC6-0 mode)
    for (int i = 2; i >= 0; i--) {
      int bit = 0; // RC6-0 mode
      if (bit == 1) {
        pattern.add(halfBitTime); // High
        pattern.add(halfBitTime); // Low
      } else {
        pattern.add(halfBitTime); // Low  
        pattern.add(halfBitTime); // High
      }
    }
    
    // Trailer bit (toggle bit with double length)
    if (toggleBit) {
      pattern.add(trailerTime); // High (double length)
      pattern.add(trailerTime); // Low (double length)
    } else {
      pattern.add(trailerTime); // Low (double length)
      pattern.add(trailerTime); // High (double length)
    }
    
    // Address (8 bits, MSB first)
    for (int i = 7; i >= 0; i--) {
      int bit = (address >> i) & 1;
      if (bit == 1) {
        pattern.add(halfBitTime); // High
        pattern.add(halfBitTime); // Low
      } else {
        pattern.add(halfBitTime); // Low
        pattern.add(halfBitTime); // High
      }
    }
    
    // Command (8 bits, MSB first)
    for (int i = 7; i >= 0; i--) {
      int bit = (command >> i) & 1;
      if (bit == 1) {
        pattern.add(halfBitTime); // High
        pattern.add(halfBitTime); // Low
      } else {
        pattern.add(halfBitTime); // Low
        pattern.add(halfBitTime); // High
      }
    }
    
    return pattern;
  }

  /// Helper function that sends the IR signal based on the button type.
  /// If the button contains rawData and frequency, it sends a raw signal;
  /// otherwise it transmits a hex NEC code.
  static Future<void> sendIR(IRButton button) async {
    try {
      // Debug: Print button details
      print('DEBUG: Transmitting button "${button.name}"');
      print('  Type: ${button.type}');
      print('  Protocol: ${button.protocol}');
      print('  Address: ${button.address}');
      print('  Command: ${button.command}');
      print('  Frequency: ${button.frequency}');
      print('  Data length: ${button.data?.length ?? 0}');
      
      // First priority: raw data 
      if (button.type == 'raw' && button.frequency != null && button.data != null && button.data!.isNotEmpty) {
        print('DEBUG: Transmitting as raw data');
        await transmitRaw(button.frequency!, button.data!);
        return;
      }
      
      // Second priority: parsed data with protocol, address, and command
      if (button.type == 'parsed' && button.protocol != null && button.address != null && button.command != null) {
        print('DEBUG: Transmitting as parsed data with protocol');
        String protocol = button.protocol!.toLowerCase();
        
        // Handle RC5 protocol
        if (protocol == 'rc5') {
          print('DEBUG: Processing RC5 protocol');
          try {
            // Handle both single hex values and space-separated format
            int address, command;
            
            // Parse address
            if (button.address!.contains(' ')) {
              List<String> addressParts = button.address!.split(' ');
              address = int.parse(addressParts[0], radix: 16);
              print('DEBUG: RC5 address parsed from space-separated: $address');
            } else {
              address = int.parse(button.address!, radix: 16);
              print('DEBUG: RC5 address parsed from single hex: $address');
            }
            
            // Parse command  
            if (button.command!.contains(' ')) {
              List<String> commandParts = button.command!.split(' ');
              command = int.parse(commandParts[0], radix: 16);
              print('DEBUG: RC5 command parsed from space-separated: $command');
            } else {
              command = int.parse(button.command!, radix: 16);
              print('DEBUG: RC5 command parsed from single hex: $command');
            }
            
            // RC5 uses 36kHz carrier frequency
            List<int> pattern = convertRC5toList(address, command);
            print('DEBUG: RC5 pattern generated, length: ${pattern.length}');
            print('DEBUG: RC5 pattern: $pattern');
            print('DEBUG: RC5 total duration: ${pattern.reduce((a, b) => a + b)}µs');
            await transmitRaw(38000, pattern);
            return;
          } catch (e) {
            print('RC5 parsing error: $e');
          }
        }
        
        // Handle RC6 protocol
        if (protocol == 'rc6') {
          print('DEBUG: Processing RC6 protocol');
          try {
            // Handle both single hex values and space-separated format
            int address, command;
            
            // Parse address
            if (button.address!.contains(' ')) {
              List<String> addressParts = button.address!.split(' ');
              address = int.parse(addressParts[0], radix: 16);
              print('DEBUG: RC6 address parsed from space-separated: $address');
            } else {
              address = int.parse(button.address!, radix: 16);
              print('DEBUG: RC6 address parsed from single hex: $address');
            }
            
            // Parse command  
            if (button.command!.contains(' ')) {
              List<String> commandParts = button.command!.split(' ');
              command = int.parse(commandParts[0], radix: 16);
              print('DEBUG: RC6 command parsed from space-separated: $command');
            } else {
              command = int.parse(button.command!, radix: 16);
              print('DEBUG: RC6 command parsed from single hex: $command');
            }
            
            // RC6 uses 36kHz carrier frequency (same as RC5)
            List<int> pattern = convertRC6toList(address, command);
            print('DEBUG: RC6 pattern generated, length: ${pattern.length}');
            await transmitRaw(36000, pattern);
            return;
          } catch (e) {
            print('RC6 parsing error: $e');
          }
        }
        
        // Handle NEC family protocols (existing code unchanged)
        if (protocol == 'nec' || protocol == 'necext' || protocol == 'samsung32') {
          print('DEBUG: Processing ${protocol.toUpperCase()} protocol');
          List<String> addressParts = button.address!.split(' ');
          List<String> commandParts = button.command!.split(' ');
          
          print('DEBUG: Address parts: $addressParts, Command parts: $commandParts');
          
          if (addressParts.length >= 2 && commandParts.length >= 2) {
            // Use your convertToLIRCHex logic exactly as in your reference for all protocols
            int addrByte1 = int.parse(addressParts[0], radix: 16);
            int addrByte2 = int.parse(addressParts[1], radix: 16);
            int cmdByte1 = int.parse(commandParts[0], radix: 16);
            int cmdByte2 = int.parse(commandParts[1], radix: 16);
            
            print('DEBUG: Parsed bytes - addr1: $addrByte1, addr2: $addrByte2, cmd1: $cmdByte1, cmd2: $cmdByte2');
            
            int lircCmd = bitReverse(addrByte1);
            int lircCmdInv = (addrByte2 == 0) ? (0xFF - lircCmd) : bitReverse(addrByte2);
            int lircAddr = bitReverse(cmdByte1);
            int lircAddrInv = (cmdByte2 == 0) ? (0xFF - lircAddr) : bitReverse(cmdByte2);
            
            String hexString = "${lircCmd.toRadixString(16).padLeft(2, '0')}"
                              "${lircCmdInv.toRadixString(16).padLeft(2, '0')}"
                              "${lircAddr.toRadixString(16).padLeft(2, '0')}"
                              "${lircAddrInv.toRadixString(16).padLeft(2, '0')}";
            
            print('DEBUG: Generated hex string: $hexString');
            
            int code = int.parse(hexString, radix: 16);
            print('DEBUG: Final NEC code: $code');
            await transmit(code);
            return;
          } else {
            print('DEBUG: Insufficient address/command parts for NEC family');
          }
        }
      }
      
      print('IR Transmitter: Unable to transmit button ${button.name} - insufficient data');
      print('  Available data does not match any supported format:');
      print('  - Raw: needs type="raw", frequency, and data array');
      print('  - Parsed: needs type="parsed", protocol, address, and command');
    } catch (e) {
      print('IR Transmitter Error: $e');
    }
  }

  /// Bit reverse function from your reference
  static int bitReverse(int x) {
    return int.parse(
        x.toRadixString(2).padLeft(8, '0').split('').reversed.join(),
        radix: 2);
  }

  /// Check if IR transmitter is available on the device
  static Future<bool> isIRAvailable() async {
    try {
      final bool result = await _channel.invokeMethod('hasIrEmitter');
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Check if IR transmitter is available (alias for consistency)
  static Future<bool> isTransmitterAvailable() async {
    return await isIRAvailable();
  }

  /// Get supported protocols
  static Future<List<String>> getSupportedProtocols() async {
    return ['NEC', 'NECext', 'RC5', 'RC6', 'Raw'];
  }
}
