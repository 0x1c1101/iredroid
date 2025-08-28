/// Represents an IR device with its buttons and metadata
class IRDevice {
  final String name;
  final String brand;
  final String category;
  final List<IRButton> buttons;
  final String? description;
  final DateTime createdAt;

  IRDevice({
    required this.name,
    required this.brand,
    required this.category,
    required this.buttons,
    this.description,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'brand': brand,
      'category': category,
      'buttons': buttons.map((b) => b.toJson()).toList(),
      'description': description,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory IRDevice.fromJson(Map<String, dynamic> json) {
    return IRDevice(
      name: json['name'],
      brand: json['brand'] ?? 'Unknown',
      category: json['category'],
      buttons: (json['buttons'] as List)
          .map((b) => IRButton.fromJson(b))
          .toList(),
      description: json['description'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  /// Get button by name
  IRButton? getButton(String buttonName) {
    try {
      return buttons.firstWhere(
        (button) => button.name.toLowerCase() == buttonName.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get buttons by category
  List<IRButton> getButtonsByType(String type) {
    return buttons.where((button) => button.type == type).toList();
  }
}

/// Represents an individual IR button/signal
class IRButton {
  final String name;
  final String type;
  final String? protocol;
  final String? address;
  final String? command;
  final int? frequency;
  final double? dutyCycle;
  final List<int>? data;
  final String? description;
  final Map<String, dynamic>? metadata;

  IRButton({
    required this.name,
    required this.type,
    this.protocol,
    this.address,
    this.command,
    this.frequency,
    this.dutyCycle,
    this.data,
    this.description,
    this.metadata,
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'protocol': protocol,
      'address': address,
      'command': command,
      'frequency': frequency,
      'dutyCycle': dutyCycle,
      'data': data,
      'description': description,
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory IRButton.fromJson(Map<String, dynamic> json) {
    return IRButton(
      name: json['name'],
      type: json['type'],
      protocol: json['protocol'],
      address: json['address'],
      command: json['command'],
      frequency: json['frequency'],
      dutyCycle: json['dutyCycle'],
      data: json['data'] != null ? List<int>.from(json['data']) : null,
      description: json['description'],
      metadata: json['metadata'],
    );
  }

  /// Extract specific data fields based on protocol
  Map<String, String> getParsedData() {
    final Map<String, String> parsed = {};
    
    if (protocol != null) parsed['protocol'] = protocol!;
    if (address != null) parsed['address'] = address!;
    if (command != null) parsed['command'] = command!;
    if (frequency != null) parsed['frequency'] = frequency.toString();
    if (dutyCycle != null) parsed['duty_cycle'] = dutyCycle.toString();
    if (data != null && data!.isNotEmpty) {
      parsed['data'] = data!.join(' ');
    }
    
    return parsed;
  }

  /// Check if this is a power button
  bool get isPowerButton {
    return name.toLowerCase().contains('power') || 
           name.toLowerCase().contains('on') ||
           name.toLowerCase().contains('off');
  }

  /// Check if this is a volume button
  bool get isVolumeButton {
    return name.toLowerCase().contains('vol') || 
           name.toLowerCase().contains('volume') ||
           name.toLowerCase() == 'v+' ||
           name.toLowerCase() == 'v-' ||
           name.toLowerCase() == 'vol+' ||
           name.toLowerCase() == 'vol-';
  }

  /// Check if this is a channel button
  bool get isChannelButton {
    return name.toLowerCase().contains('ch') || 
           name.toLowerCase().contains('channel');
  }

  /// Check if this is a number button
  bool get isNumberButton {
    return RegExp(r'^\d+$').hasMatch(name) || 
           name.toLowerCase().contains('num');
  }
}

/// Enum for common IR protocols
enum IRProtocol {
  nec,
  sony,
  rc5,
  rc6,
  samsung,
  lg,
  panasonic,
  jvc,
  sharp,
  unknown;

  static IRProtocol fromString(String protocol) {
    switch (protocol.toLowerCase()) {
      case 'nec':
        return IRProtocol.nec;
      case 'sony':
        return IRProtocol.sony;
      case 'rc5':
        return IRProtocol.rc5;
      case 'rc6':
        return IRProtocol.rc6;
      case 'samsung':
        return IRProtocol.samsung;
      case 'lg':
        return IRProtocol.lg;
      case 'panasonic':
        return IRProtocol.panasonic;
      case 'jvc':
        return IRProtocol.jvc;
      case 'sharp':
        return IRProtocol.sharp;
      default:
        return IRProtocol.unknown;
    }
  }
}

/// Device categories
enum DeviceCategory {
  tv,
  ac,
  audio,
  fan,
  light,
  projector,
  settopbox,
  other;

  static DeviceCategory fromString(String category) {
    switch (category.toLowerCase()) {
      case 'tv':
        return DeviceCategory.tv;
      case 'ac':
      case 'air conditioner':
        return DeviceCategory.ac;
      case 'audio':
      case 'speaker':
      case 'stereo':
        return DeviceCategory.audio;
      case 'fan':
        return DeviceCategory.fan;
      case 'light':
      case 'lamp':
        return DeviceCategory.light;
      case 'projector':
        return DeviceCategory.projector;
      case 'settopbox':
      case 'set-top box':
        return DeviceCategory.settopbox;
      default:
        return DeviceCategory.other;
    }
  }

  String get displayName {
    switch (this) {
      case DeviceCategory.tv:
        return 'TV';
      case DeviceCategory.ac:
        return 'Air Conditioner';
      case DeviceCategory.audio:
        return 'Audio';
      case DeviceCategory.fan:
        return 'Fan';
      case DeviceCategory.light:
        return 'Light';
      case DeviceCategory.projector:
        return 'Projector';
      case DeviceCategory.settopbox:
        return 'Set-Top Box';
      case DeviceCategory.other:
        return 'Other';
    }
  }
}
