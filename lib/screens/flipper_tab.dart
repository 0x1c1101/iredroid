import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/flipper_irdb.dart';
import 'remote_control_screen.dart';
import 'custom_tab.dart';

class FlipperTab extends StatefulWidget {
  const FlipperTab({super.key});

  @override
  State<FlipperTab> createState() => _FlipperTabState();
}

class _FlipperTabState extends State<FlipperTab> {
  static bool _hasLoaded = false;
  static bool _irdbAvailable = false;
  static List<String> _categories = [];
  static Map<String, dynamic> _directoryInfo = {};
  
  bool _isLoading = true;
  String? _selectedCategory;
  List<String> _brands = [];
  String? _selectedBrand;
  List<String> _devices = [];

  @override
  void initState() {
    super.initState();
    if (_hasLoaded) {
      // Use cached data
      setState(() {
        _isLoading = false;
      });
    } else {
      // Load for the first time
      _checkIRDBAvailability();
    }
  }

  Future<void> _checkIRDBAvailability() async {
    setState(() => _isLoading = true);
    
    final available = await FlipperIRDB.isIRDBAvailable();
    final info = await FlipperIRDB.getDirectoryInfo();
    
    print('IRDB Available: $available');
    print('Directory Info: $info');
    
    if (available) {
      final categories = await FlipperIRDB.getCategories();
      print('Categories found: $categories');
      
      // Cache the data in static variables
      _hasLoaded = true;
      _irdbAvailable = true;
      _categories = categories;
      _directoryInfo = info;
      
      setState(() {
        _isLoading = false;
      });
    } else {
      _hasLoaded = true;
      _irdbAvailable = false;
      _directoryInfo = info;
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectCategory(String category) async {
    setState(() {
      _selectedCategory = category;
      _selectedBrand = null;
      _brands = [];
      _devices = [];
    });

    final brands = await FlipperIRDB.getBrands(category);
    setState(() {
      _brands = brands;
    });
  }

  Future<void> _selectBrand(String brand) async {
    if (_selectedCategory == null) return;
    
    setState(() {
      _selectedBrand = brand;
      _devices = [];
    });

    final devices = await FlipperIRDB.getDeviceFiles(_selectedCategory!, brand);
    setState(() {
      _devices = devices;
    });
  }

  Future<void> _openDevice(String deviceName) async {
    if (_selectedCategory == null || _selectedBrand == null) return;

    showDialog(
      context: context,
      builder: (context) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Loading device...'),
          ],
        ),
      ),
    );

    try {
      final device = await FlipperIRDB.parseDeviceFile(
        _selectedCategory!,
        _selectedBrand!,
        deviceName,
      );

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (device != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RemoteControlScreen(device: device),
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load device')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _addToFavorites(String deviceName) async {
    try {
      await CustomTab.addFavorite(_selectedBrand!, deviceName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$deviceName added to favorites')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add favorite: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_irdbAvailable) {
      return _buildSetupInstructions();
    }

    return Column(
      children: [
        // Header with info
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Flipper IRDB',
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_directoryInfo['totalCategories']} categories • ${_directoryInfo['totalDevices']} devices',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        
        // Navigation breadcrumb
        if (_selectedCategory != null || _selectedBrand != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() {
                    _selectedCategory = null;
                    _selectedBrand = null;
                    _brands = [];
                    _devices = [];
                  }),
                  child: Text('Categories', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                ),
                if (_selectedCategory != null) ...[
                  const Text(' > '),
                  GestureDetector(
                    onTap: () => setState(() {
                      _selectedBrand = null;
                      _devices = [];
                    }),
                    child: Text(_selectedCategory!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                  ),
                ],
                if (_selectedBrand != null) ...[
                  const Text(' > '),
                  Text(_selectedBrand!, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ),

        // Content
        Expanded(
          child: _selectedCategory == null
              ? _buildCategoriesList()
              : _selectedBrand == null
                  ? _buildBrandsList()
                  : _buildDevicesList(),
        ),
      ],
    );
  }

  Widget _buildSetupInstructions() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_open, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Flipper IRDB Not Available',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'The IR device database is embedded in this app.\n\n'
            'If you see this message, the database was not\n'
            'included during the build process.\n\n'
            'Please rebuild the app with the flipper-irdb\n'
            'assets properly included.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          const Text('Asset location:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text(
            'assets/flipper-irdb/',
            style: TextStyle(fontFamily: 'monospace', color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _checkIRDBAvailability,
            child: const Text('Check Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        return Card(
          child: ListTile(
            leading: _getCategoryIcon(category),
            title: Text(category),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _selectCategory(category),
          ),
        );
      },
    );
  }

  Widget _buildBrandsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _brands.length,
      itemBuilder: (context, index) {
        final brand = _brands[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.business),
            title: Text(brand),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _selectBrand(brand),
          ),
        );
      },
    );
  }

  Widget _buildDevicesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.settings_remote),
            title: Text(device),
            subtitle: Text('$_selectedBrand'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.favorite_border),
                  onPressed: () => _addToFavorites(device),
                  tooltip: 'Add to Favorites',
                ),
                const Icon(Icons.play_arrow),
              ],
            ),
            onTap: () => _openDevice(device),
          ),
        );
      },
    );
  }

  Widget _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'tvs':
      case 'tv':
        return Icon(Icons.tv, color: Theme.of(context).colorScheme.primary);
      case 'acs':
      case 'ac':
      case 'air_conditioners':
        return Icon(Icons.ac_unit, color: Theme.of(context).colorScheme.primary);
      case 'audio':
      case 'speakers':
      case 'audio_and_video_receivers':
        return Icon(Icons.speaker, color: Theme.of(context).colorScheme.primary);
      case 'fans':
        return Icon(Icons.toys, color: Theme.of(context).colorScheme.primary);
      case 'lights':
      case 'lighting':
      case 'led_lighting':
        return Icon(Icons.lightbulb, color: Theme.of(context).colorScheme.primary);
      case 'projectors':
        return Icon(Icons.videocam, color: Theme.of(context).colorScheme.primary);
      case 'air_purifiers':
        return Icon(Icons.air, color: Theme.of(context).colorScheme.primary);
      case 'bidet':
        return Icon(Icons.shower, color: Theme.of(context).colorScheme.primary);
      case 'blu-ray':
      case 'dvd_players':
      case 'vcr':
        return Icon(Icons.disc_full, color: Theme.of(context).colorScheme.primary);
      case 'cable_boxes':
      case 'set_top_boxes':
      case 'streaming_devices':
        return Icon(Icons.cable, color: Theme.of(context).colorScheme.primary);
      case 'cameras':
      case 'cctv':
        return Icon(Icons.camera_alt, color: Theme.of(context).colorScheme.primary);
      case 'car_multimedia':
      case 'head_units':
        return Icon(Icons.car_rental, color: Theme.of(context).colorScheme.primary);
      case 'cd_players':
      case 'minidisc':
      case 'laserdisc':
        return Icon(Icons.album, color: Theme.of(context).colorScheme.primary);
      case 'clocks':
        return Icon(Icons.access_time, color: Theme.of(context).colorScheme.primary);
      case 'computers':
      case 'monitors':
        return Icon(Icons.computer, color: Theme.of(context).colorScheme.primary);
      case 'consoles':
      case 'toys':
        return Icon(Icons.games, color: Theme.of(context).colorScheme.primary);
      case 'converters':
      case 'digital_signs':
        return Icon(Icons.transform, color: Theme.of(context).colorScheme.primary);
      case 'dust_collectors':
      case 'vacuum_cleaners':
        return Icon(Icons.cleaning_services, color: Theme.of(context).colorScheme.primary);
      case 'dvb-t':
      case 'tv_tuner':
        return Icon(Icons.settings_input_antenna, color: Theme.of(context).colorScheme.primary);
      case 'fireplaces':
      case 'heaters':
        return Icon(Icons.fireplace, color: Theme.of(context).colorScheme.primary);
      case 'humidifiers':
        return Icon(Icons.water_drop, color: Theme.of(context).colorScheme.primary);
      case 'kvm':
        return Icon(Icons.keyboard, color: Theme.of(context).colorScheme.primary);
      case 'miscellaneous':
        return Icon(Icons.more_horiz, color: Theme.of(context).colorScheme.onSurfaceVariant);
      case 'multimedia':
      case 'soundbars':
        return Icon(Icons.surround_sound, color: Theme.of(context).colorScheme.primary);
      case 'picture_frames':
      case 'touchscreen_displays':
        return Icon(Icons.photo, color: Theme.of(context).colorScheme.primary);
      case 'universal_tv_remotes':
        return Icon(Icons.settings_remote, color: Theme.of(context).colorScheme.primary);
      case 'videoconferencing':
        return Icon(Icons.video_call, color: Theme.of(context).colorScheme.primary);
      case 'whiteboards':
        return Icon(Icons.dashboard, color: Theme.of(context).colorScheme.primary);
      case 'window_cleaners':
        return Icon(Icons.cleaning_services, color: Theme.of(context).colorScheme.primary);
      default:
        return Icon(Icons.devices, color: Theme.of(context).colorScheme.onSurfaceVariant);
    }
  }
}
