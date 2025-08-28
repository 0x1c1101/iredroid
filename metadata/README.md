# F-Droid Metadata for IReDroid

This directory contains the F-Droid metadata for IReDroid submission.

## Files Included

- `app.yml` - Main F-Droid metadata file
- `en-US/full_description.txt` - Detailed app description
- `en-US/short_description.txt` - Brief app summary
- `en-US/title.txt` - App display name
- `en-US/changelogs/1.txt` - Version 1.0.0 changelog

## Before Submission

Please update the following placeholders in `app.yml`:

1. **Repository URLs**: Replace `https://github.com/0x1c1101/iredroid` with your actual repository
2. **Author Information**: Add proper author name and email
3. **Website**: Add project website if available
4. **Git Commit Tags**: Ensure version tags exist in your repository

## F-Droid Submission Process

1. Fork the F-Droid Data repository: https://gitlab.com/fdroid/fdroiddata
2. Create a new directory: `metadata/com.yourcompany.iredroid/`
3. Copy these metadata files to that directory
4. Update the app ID in filenames and metadata
5. Create a merge request

## Requirements Checklist

✅ App is completely open source (GPL-3.0)
✅ No proprietary dependencies
✅ No network permissions (offline only)
✅ No ads or tracking
✅ Builds from source with Flutter
✅ Minimal permissions (only IR transmitter)
✅ Privacy-respecting application

## Build Instructions

The app can be built using standard Flutter commands:

```bash
flutter pub get
flutter build apk --release
```

F-Droid will build from source using the configuration in `app.yml`.
