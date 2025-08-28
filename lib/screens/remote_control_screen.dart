import 'package:flutter/material.dart';
import '../models/ir_device.dart';
import '../utils/ir_transmitter.dart';

class RemoteControlScreen extends StatefulWidget {
  final IRDevice device;

  const RemoteControlScreen({super.key, required this.device});

  @override
  State<RemoteControlScreen> createState() => _RemoteControlScreenState();
}

class _RemoteControlScreenState extends State<RemoteControlScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.device.name} Remote'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showDeviceInfo,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Device info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(_getCategoryIcon(), size: 32, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.device.name,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${widget.device.category} • ${widget.device.buttons.length} buttons',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Power button (always at top)
            if (_hasPowerButton())
              _buildSection('Power', [_getPowerButton()!]),
            
            // Navigation controls
            if (_hasNavigationButtons())
              _buildNavigationSection(),
            
            // Volume and Channel controls
            if (_hasVolumeOrChannelButtons())
              _buildVolumeChannelSection(),
            
            // Number pad
            if (_hasNumberButtons())
              _buildNumberPadSection(),
            
            // Other buttons
            if (_getOtherButtons().isNotEmpty)
              _buildSection('Other Controls', _getOtherButtons()),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<IRButton> buttons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: buttons.map((button) => _buildRemoteButton(button)).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildNavigationSection() {
    final upButton = widget.device.getButton('Up');
    final downButton = widget.device.getButton('Down');
    final leftButton = widget.device.getButton('Left');
    final rightButton = widget.device.getButton('Right');
    final okButton = widget.device.getButton('OK');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Navigation',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            // Up button
            if (upButton != null)
              _buildRemoteButton(upButton),
            const SizedBox(height: 8),
            // Left, OK, Right buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (leftButton != null)
                  _buildRemoteButton(leftButton)
                else
                  const SizedBox(width: 60),
                if (okButton != null)
                  _buildRemoteButton(okButton)
                else
                  const SizedBox(width: 60),
                if (rightButton != null)
                  _buildRemoteButton(rightButton)
                else
                  const SizedBox(width: 60),
              ],
            ),
            const SizedBox(height: 8),
            // Down button
            if (downButton != null)
              _buildRemoteButton(downButton),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildVolumeChannelSection() {
    final volumeButtons = widget.device.buttons.where((b) => b.isVolumeButton).toList();
    final channelButtons = widget.device.buttons.where((b) => b.isChannelButton).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Volume & Channel',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Volume controls
            if (volumeButtons.isNotEmpty)
              Column(
                children: [
                  const Text('Volume', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  ...volumeButtons.map((button) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _buildRemoteButton(button),
                  )),
                ],
              ),
            // Channel controls
            if (channelButtons.isNotEmpty)
              Column(
                children: [
                  const Text('Channel', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  ...channelButtons.map((button) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _buildRemoteButton(button),
                  )),
                ],
              ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildNumberPadSection() {
    final numberButtons = widget.device.buttons.where((b) => b.isNumberButton).toList();
    numberButtons.sort((a, b) {
      final aNum = int.tryParse(a.name) ?? 99;
      final bNum = int.tryParse(b.name) ?? 99;
      return aNum.compareTo(bNum);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Number Pad',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          childAspectRatio: 1.5,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: numberButtons.map((button) => _buildRemoteButton(button)).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRemoteButton(IRButton button) {
    return ElevatedButton(
      onPressed: () => _transmitIR(button),
      style: ElevatedButton.styleFrom(
        backgroundColor: _getButtonColor(button).withOpacity(0.1),
        foregroundColor: _getButtonColor(button),
        minimumSize: const Size(60, 60),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
            if (_getButtonIcon(button) != null) ...[
              Icon(_getButtonIcon(button), size: 20),
              const SizedBox(height: 4),
              Text(
                button.name,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ] else ...[
              // When no icon, show the button name more prominently
              Text(
                button.name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
        ],
      ),
    );
  }

  void _transmitIR(IRButton button) async {
    try {
      // Simple transmission without repeats
      await IRTransmitter.transmitButton(button);
    } catch (e) {
      // Silent - no messages at all
    }
  }

  void _showDeviceInfo() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(widget.device.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Category: ${widget.device.category}'),
              Text('Buttons: ${widget.device.buttons.length}'),
              Text('Created: ${widget.device.createdAt.toString().split('.')[0]}'),
              if (widget.device.description != null)
                Text('Description: ${widget.device.description}'),
              const SizedBox(height: 16),
              const Text('Protocols used:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...widget.device.buttons
                  .map((b) => b.protocol)
                  .toSet()
                  .map((protocol) => Text('• $protocol')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  IconData _getCategoryIcon() {
    switch (widget.device.category.toLowerCase()) {
      case 'tv':
        return Icons.tv;
      case 'ac':
        return Icons.ac_unit;
      case 'audio':
        return Icons.speaker;
      case 'fan':
        return Icons.toys;
      case 'light':
        return Icons.lightbulb;
      default:
        return Icons.settings_remote;
    }
  }

  IconData? _getButtonIcon(IRButton button) {
    final name = button.name.toLowerCase();
    if (name.contains('power')) return Icons.power_settings_new;
    if (name.contains('vol+') || name == 'vol+' || name == 'v+') return Icons.volume_up;
    if (name.contains('vol-') || name == 'vol-' || name == 'v-') return Icons.volume_down;
    if (name.contains('ch+') || name == 'ch+') return Icons.add;
    if (name.contains('ch-') || name == 'ch-') return Icons.remove;
    if (name == 'up') return Icons.keyboard_arrow_up;
    if (name == 'down') return Icons.keyboard_arrow_down;
    if (name == 'left') return Icons.keyboard_arrow_left;
    if (name == 'right') return Icons.keyboard_arrow_right;
    if (name == 'ok') return Icons.circle;
    if (name == 'play') return Icons.play_arrow;
    if (name == 'pause') return Icons.pause;
    if (name == 'stop') return Icons.stop;
    if (name == 'next') return Icons.skip_next;
    if (name == 'prev') return Icons.skip_previous;
    if (name == 'mute') return Icons.volume_off;
    if (name == 'freeze') return Icons.pause_circle;
    return null;
  }

  Color _getButtonColor(IRButton button) {
    if (button.isPowerButton) return Colors.red;
    if (button.isVolumeButton) return Colors.orange;
    if (button.isChannelButton) return Colors.purple;
    if (button.isNumberButton) return Colors.grey;
    if (button.name.toLowerCase().contains('up') || 
        button.name.toLowerCase().contains('down') ||
        button.name.toLowerCase().contains('left') ||
        button.name.toLowerCase().contains('right') ||
        button.name.toLowerCase().contains('ok')) {
      return Colors.blue;
    }
    return Colors.green;
  }

  // Helper methods
  bool _hasPowerButton() => _getPowerButton() != null;
  
  IRButton? _getPowerButton() {
    try {
      return widget.device.buttons.firstWhere((b) => b.isPowerButton);
    } catch (e) {
      return null;
    }
  }

  bool _hasNavigationButtons() {
    return widget.device.getButton('Up') != null ||
           widget.device.getButton('Down') != null ||
           widget.device.getButton('Left') != null ||
           widget.device.getButton('Right') != null ||
           widget.device.getButton('OK') != null;
  }

  bool _hasVolumeOrChannelButtons() {
    return widget.device.buttons.any((b) => b.isVolumeButton || b.isChannelButton);
  }

  bool _hasNumberButtons() {
    return widget.device.buttons.any((b) => b.isNumberButton);
  }

  List<IRButton> _getOtherButtons() {
    return widget.device.buttons.where((button) {
      return !button.isPowerButton &&
             !button.isVolumeButton &&
             !button.isChannelButton &&
             !button.isNumberButton &&
             !['up', 'down', 'left', 'right', 'ok'].contains(button.name.toLowerCase());
    }).toList();
  }
}
