import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/ir_device.dart';
import '../utils/ir_file_parser.dart';
import '../utils/flipper_irdb.dart';
import '../screens/remote_control_screen.dart';

class CustomTab extends StatefulWidget {
  const CustomTab({super.key});

  @override
  State<CustomTab> createState() => _CustomTabState();

  // Static callback for refreshing the UI when devices are added
  static void Function()? _refreshCallback;
  
  static void setRefreshCallback(void Function() callback) {
    _refreshCallback = callback;
  }
  
  static void clearRefreshCallback() {
    _refreshCallback = null;
  }

  // Static method to add a device to favorites from flipper tab
  static Future<void> addFavorite(String brand, String deviceName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final customDir = Directory('${directory.path}/Custom');
      if (!await customDir.exists()) {
        await customDir.create(recursive: true);
      }

      // Find the original .ir file in flipper-irdb and copy it directly
      final extractedPath = await FlipperIRDB.extractedPath;
      final categories = await FlipperIRDB.getCategories();
      
      String? sourceFilePath;
      for (final category in categories) {
        try {
          final brands = await FlipperIRDB.getBrands(category);
          if (brands.contains(brand)) {
            final deviceFiles = await FlipperIRDB.getDeviceFiles(category, brand);
            if (deviceFiles.contains(deviceName)) {
              sourceFilePath = '$extractedPath/$category/$brand/$deviceName.ir';
              break;
            }
          }
        } catch (e) {
          // Continue searching in other categories
          continue;
        }
      }
      
      if (sourceFilePath == null) {
        throw Exception('Could not find .ir file for $deviceName from brand $brand in Flipper IRDB');
      }

      // Copy the original .ir file to the Custom folder with device name metadata
      final sourceFile = File(sourceFilePath);
      if (!await sourceFile.exists()) {
        throw Exception('Source .ir file does not exist: $sourceFilePath');
      }
      
      // Read the original content and add device metadata
      final originalContent = await sourceFile.readAsString();
      final lines = originalContent.split('\n');
      
      // Insert device metadata after the version line
      final modifiedLines = <String>[];
      bool metadataAdded = false;
      
      for (final line in lines) {
        modifiedLines.add(line);
        if (line.trim() == 'Version: 1' && !metadataAdded) {
          modifiedLines.add('#');
          modifiedLines.add('# Device: $deviceName');
          modifiedLines.add('# Brand: $brand');
          modifiedLines.add('# Source: Flipper IRDB (Favorite)');
          metadataAdded = true;
        }
      }
      
      final targetFile = File('${customDir.path}/${brand}_${deviceName}_favorite.ir');
      await targetFile.writeAsString(modifiedLines.join('\n'));
      
      // Trigger UI refresh
      if (_refreshCallback != null) {
        _refreshCallback!();
      }
    } catch (e) {
      throw Exception('Failed to add favorite: $e');
    }
  }

  // Static method to save a device from fuzzer to custom tab
  static Future<void> saveFromFuzzer(IRDevice device) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final customDir = Directory('${directory.path}/Custom');
      if (!await customDir.exists()) {
        await customDir.create(recursive: true);
      }

      // For fuzzer devices, we need to create a new .ir file since they come from testing
      // Save the device as a full .ir file
      final deviceFile = File('${customDir.path}/${device.name}_fuzzer.ir');
      final content = '''Filetype: IR signals file
Version: 1
#
# Device: ${device.name}
# Source: Fuzzer Discovery
#
''';
      
      final StringBuffer buffer = StringBuffer(content);
      for (final button in device.buttons) {
        buffer.writeln('name: ${button.name}');
        buffer.writeln('type: ${button.type}');
        if (button.protocol != null) {
          buffer.writeln('protocol: ${button.protocol}');
        }
        if (button.address != null) {
          buffer.writeln('address: ${button.address}');
        }
        if (button.command != null) {
          buffer.writeln('command: ${button.command}');
        }
        if (button.frequency != null) {
          buffer.writeln('frequency: ${button.frequency}');
        }
        if (button.dutyCycle != null) {
          buffer.writeln('duty_cycle: ${button.dutyCycle}');
        }
        if (button.data != null && button.data!.isNotEmpty) {
          buffer.writeln('data: ${button.data!.join(' ')}');
        }
        buffer.writeln('#');  // Add separator between buttons
      }
      
      await deviceFile.writeAsString(buffer.toString());
      
      // Trigger UI refresh
      if (_refreshCallback != null) {
        _refreshCallback!();
      }
    } catch (e) {
      throw Exception('Failed to save from fuzzer: $e');
    }
  }
}

class _CustomTabState extends State<CustomTab> {
  List<IRDevice> customDevices = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCustomDevices();
    // Set up refresh callback
    CustomTab.setRefreshCallback(() {
      _loadCustomDevices();
    });
  }

  @override
  void dispose() {
    // Clear refresh callback
    CustomTab.clearRefreshCallback();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Custom IR Devices',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _importIRFile,
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Import File'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _createCustomRemote,
                  icon: const Icon(Icons.add_circle),
                  label: const Text('Create Remote'),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Expanded(
              child: customDevices.isEmpty
                  ? const Center(
                      child: Text(
                        'No custom devices created yet.\n\nImport a .ir file (any extension accepted) or create a custom remote to get started.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: customDevices.length,
                      itemBuilder: (context, index) {
                        final device = customDevices[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.settings_remote),
                            title: Text(device.name),
                            subtitle: Text('${device.buttons.length} buttons'),
                            trailing: PopupMenuButton(
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete'),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _editDevice(device);
                                } else if (value == 'delete') {
                                  _deleteDevice(index);
                                }
                              },
                            ),
                            onTap: () => _openDevice(device),
                          ),
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }

  // Load custom devices from app data directory
  Future<void> _loadCustomDevices() async {
    setState(() => _isLoading = true);
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final customDir = Directory('${directory.path}/Custom');
      
      if (!await customDir.exists()) {
        await customDir.create(recursive: true);
      }
      
      final files = customDir.listSync().where((file) => file.path.endsWith('.ir')).toList();
      final List<IRDevice> devices = [];
      
      for (final file in files) {
        try {
          final content = await File(file.path).readAsString();
          final device = IRFileParser.parseIRFileContent(content);
          if (device != null) {
            devices.add(device);
          }
        } catch (e) {
          print('Error loading custom device ${file.path}: $e');
        }
      }
      
      setState(() {
        customDevices = devices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading custom devices: $e')),
        );
      }
    }
  }

  // Import .ir file
  Future<void> _importIRFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null) {
        setState(() => _isLoading = true);
        
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        
        // Read file content
        String content;
        try {
          content = await file.readAsString();
        } catch (e) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error reading file: Unable to read file as text. Please ensure it\'s a valid .ir file.')),
            );
          }
          return;
        }
        
        // Validate IR file format before parsing
        if (!IRFileParser.isValidIRFile(content)) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Invalid file format: This doesn\'t appear to be a valid .ir file.\n'
                  'Expected content should include "protocol:" and "name:" entries.\n'
                  'File: $fileName'
                ),
                duration: Duration(seconds: 5),
              ),
            );
          }
          return;
        }
        
        // Parse the IR file
        final device = IRFileParser.parseIRFileContent(content, fileName.replaceAll('.ir', ''));
        if (device != null && device.buttons.isNotEmpty) {
          await _saveCustomDevice(device, content);
          await _loadCustomDevices();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Successfully imported "${device.name}" with ${device.buttons.length} buttons'),
                backgroundColor: Theme.of(context).colorScheme.tertiary,
              ),
            );
          }
        } else {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Parsing failed: The file appears to be in .ir format but contains no valid buttons.\n'
                  'Please check the file content and try again.\n'
                  'File: $fileName'
                ),
                duration: Duration(seconds: 5),
              ),
            );
          }
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Create custom remote manually
  Future<void> _createCustomRemote() async {
    final result = await Navigator.push<IRDevice>(
      context,
      MaterialPageRoute(
        builder: (context) => const CustomRemoteEditor(),
      ),
    );
    
    if (result != null) {
      final irContent = _generateIRFileContent(result);
      await _saveCustomDevice(result, irContent);
      await _loadCustomDevices();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully created ${result.name}')),
        );
      }
    }
  }

  // Save custom device to app data directory
  Future<void> _saveCustomDevice(IRDevice device, String content) async {
    final directory = await getApplicationDocumentsDirectory();
    final customDir = Directory('${directory.path}/Custom');
    
    if (!await customDir.exists()) {
      await customDir.create(recursive: true);
    }
    
    final file = File('${customDir.path}/${device.name}.ir');
    await file.writeAsString(content);
  }

  // Generate .ir file content from IRDevice
  String _generateIRFileContent(IRDevice device) {
    final buffer = StringBuffer();
    buffer.writeln('Filetype: IR signals file');
    buffer.writeln('Version: 1');
    buffer.writeln('# Device: ${device.name}');
    buffer.writeln('# Brand: Custom');
    buffer.writeln('# Category: Custom');
    buffer.writeln('#');
    
    for (final button in device.buttons) {
      buffer.writeln('name: ${button.name}');
      buffer.writeln('type: ${button.type}');
      if (button.protocol != null) buffer.writeln('protocol: ${button.protocol}');
      if (button.address != null) buffer.writeln('address: ${button.address}');
      if (button.command != null) buffer.writeln('command: ${button.command}');
      if (button.frequency != null) buffer.writeln('frequency: ${button.frequency}');
      if (button.dutyCycle != null) buffer.writeln('duty_cycle: ${button.dutyCycle}');
      if (button.data != null && button.data!.isNotEmpty) {
        buffer.writeln('data: ${button.data!.join(' ')}');
      }
      buffer.writeln('#');
    }
    
    return buffer.toString();
  }

  // Edit device
  Future<void> _editDevice(IRDevice device) async {
    final result = await Navigator.push<IRDevice>(
      context,
      MaterialPageRoute(
        builder: (context) => CustomRemoteEditor(device: device),
      ),
    );
    
    if (result != null) {
      // Find the original file for this device
      final directory = await getApplicationDocumentsDirectory();
      final customDir = Directory('${directory.path}/Custom');
      final files = customDir.listSync().where((file) => file.path.endsWith('.ir')).toList();
      
      String? originalFilePath;
      for (final file in files) {
        try {
          final content = await File(file.path).readAsString();
          final parsedDevice = IRFileParser.parseIRFileContent(content);
          if (parsedDevice != null && 
              parsedDevice.name == device.name && 
              parsedDevice.brand == device.brand && 
              parsedDevice.buttons.length == device.buttons.length) {
            originalFilePath = file.path;
            break;
          }
        } catch (e) {
          // Continue searching
        }
      }
      
      if (originalFilePath != null) {
        // Update the original file in place
        final irContent = _generateIRFileContent(result);
        await File(originalFilePath).writeAsString(irContent);
      } else {
        // If we can't find the original file, create a new one
        final irContent = _generateIRFileContent(result);
        await _saveCustomDevice(result, irContent);
      }
      
      await _loadCustomDevices();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully updated ${result.name}')),
        );
      }
    }
  }

  // Delete device
  Future<void> _deleteDevice(int index) async {
    final device = customDevices[index];
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Device'),
        content: Text('Are you sure you want to delete "${device.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final customDir = Directory('${directory.path}/Custom');
        
        // Find the file that corresponds to this device
        // Since files might have different naming patterns, we need to search for them
        final files = customDir.listSync().where((file) => file.path.endsWith('.ir')).toList();
        
        String? deviceFilePath;
        for (final file in files) {
          try {
            final content = await File(file.path).readAsString();
            final parsedDevice = IRFileParser.parseIRFileContent(content);
            if (parsedDevice != null && parsedDevice.name == device.name && 
                parsedDevice.brand == device.brand && 
                parsedDevice.buttons.length == device.buttons.length) {
              deviceFilePath = file.path;
              break;
            }
          } catch (e) {
            // Continue searching
          }
        }
        
        if (deviceFilePath != null) {
          await File(deviceFilePath).delete();
        }
        
        await _loadCustomDevices();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted ${device.name}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting device: $e')),
          );
        }
      }
    }
  }

  // Open device for control
  void _openDevice(IRDevice device) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RemoteControlScreen(device: device),
      ),
    );
  }
}

// Custom Remote Editor Screen
class CustomRemoteEditor extends StatefulWidget {
  final IRDevice? device;
  
  const CustomRemoteEditor({super.key, this.device});

  @override
  State<CustomRemoteEditor> createState() => _CustomRemoteEditorState();
}

class _CustomRemoteEditorState extends State<CustomRemoteEditor> {
  late TextEditingController _nameController;
  List<IRButton> _buttons = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.device?.name ?? '');
    _buttons = widget.device?.buttons.map((b) => IRButton(
      name: b.name,
      type: b.type,
      protocol: b.protocol,
      address: b.address,
      command: b.command,
      frequency: b.frequency,
      dutyCycle: b.dutyCycle,
      data: b.data != null ? List<int>.from(b.data!) : null,
    )).toList() ?? [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device == null ? 'Create Remote' : 'Edit Remote'),
        actions: [
          TextButton(
            onPressed: _saveDevice,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Device Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Buttons (${_buttons.length})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _addButton,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Button'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Expanded(
              child: _buttons.isEmpty
                  ? const Center(
                      child: Text(
                        'No buttons added yet.\nTap "Add Button" to create your first button.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _buttons.length,
                      itemBuilder: (context, index) {
                        final button = _buttons[index];
                        return Card(
                          child: ListTile(
                            title: Text(button.name),
                            subtitle: Text('${button.type} - ${button.protocol ?? 'Raw'}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _editButton(index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteButton(index),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveDevice() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a device name')),
      );
      return;
    }

    if (_buttons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one button')),
      );
      return;
    }

    final device = IRDevice(
      name: _nameController.text,
      brand: 'Custom',
      category: 'Custom',
      buttons: _buttons,
    );

    Navigator.pop(context, device);
  }

  void _addButton() {
    _showButtonEditor();
  }

  void _editButton(int index) {
    _showButtonEditor(button: _buttons[index], index: index);
  }

  void _deleteButton(int index) {
    setState(() {
      _buttons.removeAt(index);
    });
  }

  void _showButtonEditor({IRButton? button, int? index}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ButtonEditor(
          button: button,
          onSave: (newButton) {
            setState(() {
              if (index != null) {
                _buttons[index] = newButton;
              } else {
                _buttons.add(newButton);
              }
            });
          },
        ),
      ),
    );
  }
}

// Button Editor Screen
class ButtonEditor extends StatefulWidget {
  final IRButton? button;
  final Function(IRButton) onSave;

  const ButtonEditor({super.key, this.button, required this.onSave});

  @override
  State<ButtonEditor> createState() => _ButtonEditorState();
}

class _ButtonEditorState extends State<ButtonEditor> {
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _commandController;
  late TextEditingController _frequencyController;
  late TextEditingController _dutyCycleController;
  late TextEditingController _dataController;
  
  String _selectedType = 'parsed';
  String _selectedProtocol = 'NEC';

  final List<String> _protocols = ['NEC', 'NECext', 'Samsung32', 'RC5', 'RC6', 'Sony', 'Raw'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.button?.name ?? '');
    _addressController = TextEditingController(text: widget.button?.address ?? '');
    _commandController = TextEditingController(text: widget.button?.command ?? '');
    _frequencyController = TextEditingController(text: widget.button?.frequency?.toString() ?? '38000');
    _dutyCycleController = TextEditingController(text: widget.button?.dutyCycle?.toString() ?? '0.33');
    _dataController = TextEditingController(text: widget.button?.data?.join(' ') ?? '');
    
    if (widget.button != null) {
      _selectedType = widget.button!.type;
      _selectedProtocol = widget.button!.protocol ?? 'NEC';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _commandController.dispose();
    _frequencyController.dispose();
    _dutyCycleController.dispose();
    _dataController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.button == null ? 'Add Button' : 'Edit Button'),
        actions: [
          TextButton(
            onPressed: _saveButton,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Button Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'parsed', child: Text('Parsed')),
                  DropdownMenuItem(value: 'raw', child: Text('Raw')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              if (_selectedType == 'parsed') ...[
                DropdownButtonFormField<String>(
                  value: _selectedProtocol,
                  decoration: const InputDecoration(
                    labelText: 'Protocol',
                    border: OutlineInputBorder(),
                  ),
                  items: _protocols.map((protocol) => 
                    DropdownMenuItem(value: protocol, child: Text(protocol))
                  ).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedProtocol = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address (hex, e.g., 0x04)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _commandController,
                  decoration: const InputDecoration(
                    labelText: 'Command (hex, e.g., 0x08)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _frequencyController,
                  decoration: const InputDecoration(
                    labelText: 'Frequency (Hz)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _dutyCycleController,
                  decoration: const InputDecoration(
                    labelText: 'Duty Cycle (e.g., 0.33)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _dataController,
                  decoration: const InputDecoration(
                    labelText: 'Data (space-separated numbers)',
                    border: OutlineInputBorder(),
                    hintText: '8986 4492 548 548 548 1670...',
                  ),
                  maxLines: 3,
                ),
              ],
              
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Help',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (_selectedType == 'parsed')
                      const Text(
                        'For parsed signals:\n'
                        '• Address: Device address in hex (e.g., 0x04)\n'
                        '• Command: Button command in hex (e.g., 0x08)\n'
                        '• Use hex values from IR remote databases',
                        style: TextStyle(fontSize: 12),
                      )
                    else
                      const Text(
                        'For raw signals:\n'
                        '• Frequency: Usually 38000 Hz for most remotes\n'
                        '• Duty Cycle: Usually 0.33 (33%)\n'
                        '• Data: Timing values in microseconds\n'
                        '• Copy raw data from IR capture tools',
                        style: TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveButton() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a button name')),
      );
      return;
    }

    try {
      List<int>? data;
      if (_selectedType == 'raw' && _dataController.text.isNotEmpty) {
        data = _dataController.text
            .split(' ')
            .where((s) => s.isNotEmpty)
            .map((s) => int.parse(s.trim()))
            .toList();
      }

      final button = IRButton(
        name: _nameController.text,
        type: _selectedType,
        protocol: _selectedType == 'parsed' ? _selectedProtocol : null,
        address: _selectedType == 'parsed' && _addressController.text.isNotEmpty 
            ? _addressController.text : null,
        command: _selectedType == 'parsed' && _commandController.text.isNotEmpty 
            ? _commandController.text : null,
        frequency: _selectedType == 'raw' && _frequencyController.text.isNotEmpty 
            ? int.tryParse(_frequencyController.text) : null,
        dutyCycle: _selectedType == 'raw' && _dutyCycleController.text.isNotEmpty 
            ? double.tryParse(_dutyCycleController.text) : null,
        data: data,
      );

      widget.onSave(button);
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating button: $e')),
      );
    }
  }
}
