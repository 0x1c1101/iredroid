import 'package:flutter/material.dart';
import '../utils/flipper_irdb.dart';
import '../models/ir_device.dart';
import '../utils/ir_transmitter.dart';
import 'custom_tab.dart';

class FuzzerTab extends StatefulWidget {
  const FuzzerTab({super.key});

  @override
  State<FuzzerTab> createState() => _FuzzerTabState();
}

class _FuzzerTabState extends State<FuzzerTab> {
  static bool _hasLoaded = false;
  static List<String> _staticCategories = [];
  
  bool _isLoading = false;
  List<String> _categories = [];
  String? _selectedCategory;
  List<String> _devices = [];
  String _powerMode = 'off'; // 'off' for power_off, 'on' for vol_up
  
  bool _isFuzzing = false;
  int _currentIndex = 0;
  int _intervalMs = 1000;
  IRDevice? _lastTestedDevice;
  List<IRDevice> _workingDevices = [];

  final TextEditingController _startIndexController = TextEditingController(text: '0');
  final TextEditingController _intervalController = TextEditingController(text: '1000');

  @override
  void initState() {
    super.initState();
    if (_hasLoaded) {
      // Use cached data
      setState(() {
        _categories = _staticCategories;
        _isLoading = false;
      });
    } else {
      // Load for the first time
      _loadCategories();
    }
  }

  @override
  void dispose() {
    _startIndexController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    
    try {
      final available = await FlipperIRDB.isIRDBAvailable();
      if (available) {
        final categories = await FlipperIRDB.getCategories();
        
        // Cache the data in static variables
        _hasLoaded = true;
        _staticCategories = categories;
        
        setState(() {
          _categories = categories;
          _isLoading = false;
        });
      } else {
        _hasLoaded = true;
        _staticCategories = [];
        
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectCategory(String category) async {
    setState(() {
      _selectedCategory = category;
      _devices = [];
      _workingDevices = [];
      _isLoading = true;
    });

    try {
      final brands = await FlipperIRDB.getBrands(category);
      List<String> allDevices = [];
      
      // Load all devices from all brands in this category
      for (String brand in brands) {
        final devices = await FlipperIRDB.getDeviceFiles(category, brand);
        for (String device in devices) {
          allDevices.add('$brand/$device');
        }
      }
      
      setState(() {
        _devices = allDevices;
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _startFuzzing() async {
    if (_selectedCategory == null || _devices.isEmpty) return;
    
    final startIndex = int.tryParse(_startIndexController.text) ?? 0;
    final interval = int.tryParse(_intervalController.text) ?? 1000;
    
    if (startIndex < 0 || startIndex >= _devices.length) {
      _showSnackBar('Invalid start index. Must be between 0 and ${_devices.length - 1}', Colors.red);
      return;
    }
    
    setState(() {
      _isFuzzing = true;
      _currentIndex = startIndex;
      _intervalMs = interval;
      _workingDevices.clear();
    });

    await _fuzzDevice();
  }

  Future<void> _fuzzDevice() async {
    if (!_isFuzzing || _currentIndex >= _devices.length) {
      await _stopFuzzing();
      return;
    }

    final devicePath = _devices[_currentIndex];
    final parts = devicePath.split('/');
    if (parts.length != 2) {
      _currentIndex++;
      await Future.delayed(Duration(milliseconds: _intervalMs));
      await _fuzzDevice();
      return;
    }

    final brand = parts[0];
    final device = parts[1];

    try {
      final irDevice = await FlipperIRDB.parseDeviceFile(_selectedCategory!, brand, device);
      if (irDevice != null) {
        setState(() {
          _lastTestedDevice = irDevice;
        });

        // Find power-related buttons based on selected mode and flipper-irdb naming scheme
        List<IRButton> powerButtons = [];
        
        if (_powerMode == 'off') {
          // Look for power off buttons using flipper-irdb naming scheme
          final powerOffButton = irDevice.buttons.where(
            (button) => button.name.toLowerCase().contains('power_off') ||
                       button.name.toLowerCase().contains('power off') ||
                       button.name.toLowerCase().contains('poweroff') ||
                       button.name.toLowerCase().contains('off')
          ).firstOrNull;
          
          if (powerOffButton != null) powerButtons.add(powerOffButton);
        } else if (_powerMode == 'on') {
          // Look for vol_up buttons (which are power on in flipper-irdb scheme)
          final volUpButton = irDevice.buttons.where(
            (button) => button.name.toLowerCase().contains('vol_up') ||
                       button.name.toLowerCase().contains('volup') ||
                       button.name.toLowerCase().contains('volume_up') ||
                       button.name.toLowerCase().contains('volume up')
          ).firstOrNull;
          
          if (volUpButton != null) powerButtons.add(volUpButton);
        }
        
        // Fallback to general power button if specific mode button not found
        if (powerButtons.isEmpty) {
          final generalPowerButton = irDevice.buttons.where(
            (button) => button.isPowerButton
          ).firstOrNull;
          
          if (generalPowerButton != null) {
            powerButtons.add(generalPowerButton);
          }
        }
        
        // Fallback to first button if no power buttons found
        if (powerButtons.isEmpty) {
          powerButtons.add(irDevice.buttons.first);
        }

        // Transmit all power buttons with frame repeat for better reliability
        for (int i = 0; i < powerButtons.length; i++) {
          await IRTransmitter.transmitButton(powerButtons[i]);
          
          // Add small delay between multiple power commands (except for the last one)
          if (i < powerButtons.length - 1) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }
        
        setState(() {
          _currentIndex++;
        });
      }
    } catch (e) {
      // Skip failed devices
      setState(() {
        _currentIndex++;
      });
    }

    // Wait for the interval before next transmission
    await Future.delayed(Duration(milliseconds: _intervalMs));
    
    // Continue with next device
    if (_isFuzzing) {
      await _fuzzDevice();
    }
  }

  Future<void> _stopFuzzing() async {
    setState(() {
      _isFuzzing = false;
    });

    if (_workingDevices.isNotEmpty) {
      _showSaveDialog();
    } else {
      _showSnackBar('Fuzzing completed. No working devices found.', Colors.orange);
    }
  }

  void _markAsWorking() {
    if (_lastTestedDevice != null && !_workingDevices.contains(_lastTestedDevice)) {
      setState(() {
        _workingDevices.add(_lastTestedDevice!);
      });
      _showSnackBar('Device marked as working!', Colors.green);
    }
  }

  void _showSaveDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fuzzing Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Found ${_workingDevices.length} working device(s):'),
            const SizedBox(height: 8),
            ..._workingDevices.map((device) => Text('• ${device.name}')),
            const SizedBox(height: 16),
            const Text('Would you like to save these to your custom remotes?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveWorkingDevices();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveWorkingDevices() async {
    try {
      for (final device in _workingDevices) {
        await CustomTab.saveFromFuzzer(device);
      }
      _showSnackBar('${_workingDevices.length} device(s) saved to custom remotes!', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to save devices: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'IR Fuzzer',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Test power-off signals from multiple devices to find compatible remotes',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Category Selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Device Category',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_categories.isEmpty)
                    const Text('No categories available. Check IRDB installation.')
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((category) {
                        final isSelected = _selectedCategory == category;
                        return FilterChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (_) => _selectCategory(category),
                          selectedColor: Colors.blue.shade100,
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Configuration
          if (_selectedCategory != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configuration (${_devices.length} devices)',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    
                    // Power Mode Selection
                    const Text(
                      'Power Command',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(
                          value: 'off',
                          label: Text('Power Off'),
                          icon: Icon(Icons.power_settings_new, size: 16),
                        ),
                        ButtonSegment<String>(
                          value: 'on',
                          label: Text('Vol Up (Power On)'),
                          icon: Icon(Icons.volume_up, size: 16),
                        ),
                      ],
                      selected: {_powerMode},
                      onSelectionChanged: _isFuzzing ? null : (Set<String> newSelection) {
                        setState(() {
                          _powerMode = newSelection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _startIndexController,
                            decoration: const InputDecoration(
                              labelText: 'Start Index',
                              border: OutlineInputBorder(),
                              helperText: 'Device to start from (0-based)',
                            ),
                            keyboardType: TextInputType.number,
                            enabled: !_isFuzzing,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _intervalController,
                            decoration: const InputDecoration(
                              labelText: 'Interval (ms)',
                              border: OutlineInputBorder(),
                              helperText: 'Delay between signals',
                            ),
                            keyboardType: TextInputType.number,
                            enabled: !_isFuzzing,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Controls
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fuzzing Control',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    if (_isFuzzing) ...[
                      LinearProgressIndicator(
                        value: _devices.isNotEmpty ? _currentIndex / _devices.length : 0,
                      ),
                      const SizedBox(height: 8),
                      Text('Testing device ${_currentIndex + 1} of ${_devices.length}'),
                      if (_lastTestedDevice != null) ...[
                        const SizedBox(height: 8),
                        Text('Current: ${_lastTestedDevice!.name}'),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _markAsWorking,
                            icon: const Icon(Icons.check),
                            label: const Text('Mark as Working'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _stopFuzzing,
                            icon: const Icon(Icons.stop),
                            label: const Text('Stop'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          ),
                        ],
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        onPressed: _devices.isNotEmpty ? _startFuzzing : null,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Fuzzing'),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Working Devices
            if (_workingDevices.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Working Devices (${_workingDevices.length})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      ..._workingDevices.map((device) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.check_circle, color: Colors.green),
                        title: Text(device.name),
                        subtitle: Text(device.category),
                      )),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
