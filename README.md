# IReDroid - Android Infrared Fuzzer

IReDroid is a free and open-source infrared remote control application for Android devices with IR blasters. Turn your Android device into a universal remote control for TVs, air conditioners, set-top boxes, and other infrared-controlled devices.

<img width="340" height="auto" alt="image" src="https://github.com/user-attachments/assets/3c237693-be8a-460c-82f8-3e36d9aad9ea" />
<br>
<img width="340" height="auto" alt="image" src="https://github.com/user-attachments/assets/d3505c35-449e-4f89-a488-41c2847490d9" />
<br>
<img width="340" height="auto" alt="image" src="https://github.com/user-attachments/assets/9cf54212-94a1-4892-92f1-c873a24eccfb" />


## Features

- You can add/modify/implement custom remotes.
- IReDroid uses Flipper Zero's database and has 1700+ devices.
- You can fuzz devices in a category.

## Supported IR Protocols

- **NEC**: Most common protocol used by many manufacturers
- **NECext**: Extended NEC protocol
- **Raw**: Custom timing patterns for unsupported protocols

- **RC5**: Doesn't work properly. (Need to fix)
- **RC6**: Doesn't work properly. (Need to fix)

## Requirements

- Android device with infrared (IR) blaster
- Android 5.0 (API level 21) or higher
- IR transmitter permission

## Installation

### From F-Droid (Not available yet)
1. Add the F-Droid repository
2. Search for "IReDroid"
3. Install the app

### From Source
1. Clone this repository
2. Open in Android Studio or VS Code
3. Run `flutter build apk --release`
4. Install the generated APK

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
- Xiaomi phones with IR blaster

## Support

For support, bug reports, or feature requests, please open an issue on the project repository.

---

**Made with ❤️ by the open source community**
