# IReDroid - Android Infrared Fuzzer

IReDroid is a free and open-source infrared remote control application for Android devices with IR blasters. Turn your Android device into a universal remote control for TVs, air conditioners, set-top boxes, and other infrared-controlled devices.

<img width="340" height="auto" alt="image" src="https://github.com/user-attachments/assets/3c237693-be8a-460c-82f8-3e36d9aad9ea" />
<br>
<img width="340" height="auto" alt="image" src="https://github.com/user-attachments/assets/d3505c35-449e-4f89-a488-41c2847490d9" />
<br>
<img width="340" height="auto" alt="image" src="https://github.com/user-attachments/assets/9cf54212-94a1-4892-92f1-c873a24eccfb" />


## Features

- 📱 **Universal Remote Control**: Control various IR devices using your Android's built-in IR blaster
- 🔧 **Multiple Protocol Support**: Supports NEC, NECext, Samsung32, RC5, RC6, and raw IR data
- 📂 **Custom Remote Creation**: Create and edit custom remote control layouts
- 🗃️ **Flipper Zero Compatibility**: Import remote controls from Flipper Zero IR database
- 🎨 **Modern UI**: Clean, intuitive Material Design interface
- 🆓 **Free & Open Source**: No ads, no tracking, completely free

## Supported IR Protocols

- **NEC**: Most common protocol used by many manufacturers
- **NECext**: Extended NEC protocol
- **Samsung32**: Samsung-specific 32-bit protocol
- **RC5**: Philips RC5 protocol with Manchester encoding
- **RC6**: Philips RC6 protocol with enhanced features
- **Raw**: Custom timing patterns for unsupported protocols

## Requirements

- Android device with infrared (IR) blaster
- Android 5.0 (API level 21) or higher
- IR transmitter permission

## Installation

### From F-Droid (Recommended)
1. Add the F-Droid repository
2. Search for "IReDroid"
3. Install the app

### From Source
1. Clone this repository
2. Open in Android Studio or VS Code
3. Run `flutter build apk --release`
4. Install the generated APK

## Usage

1. **Check IR Support**: The app will automatically detect if your device has an IR blaster
2. **Create Remote**: Add a new remote control by selecting device type and brand
3. **Import from Flipper**: Load remote controls from Flipper Zero IR database
4. **Test Buttons**: Use the test function to verify IR transmission
5. **Control Devices**: Point your device at the target and press buttons

## Building from Source

### Prerequisites
- Flutter SDK (3.9.0 or higher)
- Android SDK
- Android Studio or VS Code

### Build Steps
```bash
# Clone the repository
git clone <repository-url>
cd iredroid

# Get dependencies
flutter pub get

# Generate launcher icons
flutter pub run flutter_launcher_icons:main

# Build APK
flutter build apk --release
```

## Privacy & Permissions

IReDroid respects your privacy:
- **No internet permission**: The app works completely offline
- **No data collection**: No analytics, tracking, or data collection
- **Minimal permissions**: Only requests IR transmitter permission

### Required Permissions
- `android.permission.TRANSMIT_IR`: Required to send infrared signals

## Contributing

We welcome contributions! Please feel free to:
- Report bugs and issues
- Suggest new features
- Submit pull requests
- Improve documentation

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Disclaimer

IReDroid is provided "as is" without warranty. Use at your own risk. The developers are not responsible for any damage caused by the use of this application.

## Compatibility

Tested on devices with IR blasters including:
- Samsung Galaxy series
- Xiaomi phones with IR blaster
- OnePlus devices with IR support

## Support

For support, bug reports, or feature requests, please open an issue on the project repository.

---

**Made with ❤️ by the open source community**
