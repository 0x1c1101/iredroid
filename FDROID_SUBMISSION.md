# F-Droid Submission Checklist for IReDroid

## Pre-submission Requirements

### 1. Repository Setup
- [ ] Create public Git repository on GitHub/GitLab
- [ ] Add GPL-3.0 license file
- [ ] Tag version 1.0.0 release
- [ ] Update repository URLs in metadata files

### 2. Code Requirements
- [x] App is 100% open source
- [x] No proprietary dependencies
- [x] No network permissions
- [x] No ads or tracking
- [x] Privacy-respecting
- [x] Uses only minimal required permissions

### 3. Build Requirements
- [x] Builds with Flutter stable
- [x] No build errors or warnings
- [x] APK size reasonable
- [x] Targets Android 5.0+ (API 21)

### 4. Metadata Files Created
- [x] `com.iredroid.app.yml` - Main F-Droid metadata
- [x] `en-US/full_description.txt` - Detailed description
- [x] `en-US/short_description.txt` - Brief summary
- [x] `en-US/title.txt` - App title
- [x] `en-US/changelogs/1.txt` - Version 1.0.0 changelog
- [x] `README.md` - Submission documentation

## Submission Steps

1. **Fork F-Droid Data Repository**
   ```bash
   git clone https://gitlab.com/fdroid/fdroiddata.git
   cd fdroiddata
   ```

2. **Create App Directory**
   ```bash
   mkdir metadata/com.iredroid.app
   ```

3. **Copy Metadata Files**
   ```bash
   cp /path/to/iredroid/metadata/com.iredroid.app.yml metadata/com.iredroid.app.yml
   cp -r /path/to/iredroid/metadata/en-US metadata/com.iredroid.app/
   ```

4. **Update Metadata**
   - Replace placeholder URLs with actual repository
   - Verify all information is correct
   - Test build configuration

5. **Create Merge Request**
   - Commit changes with clear message
   - Push to your fork
   - Create merge request to F-Droid
   - Include screenshots if available

## Before Final Submission

### Update These Placeholders:
- `https://github.com/yourusername/iredroid` → Your actual repository URL
- Package ID: Decide on final package name (com.iredroid.app or similar)
- Author information
- Website URLs

### Test Build:
```bash
# Test local build
flutter clean
flutter pub get
flutter build apk --release

# Verify APK
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Final Checks:
- [ ] Repository is public and accessible
- [ ] All source code is included
- [ ] No binary files in repository
- [ ] License file is present
- [ ] README is comprehensive
- [ ] All metadata is accurate

## F-Droid Review Process

1. **Automated Checks**: F-Droid will run automated tests
2. **Manual Review**: Maintainers will review the app
3. **Build Test**: F-Droid will attempt to build from source
4. **Publication**: Once approved, app will be published

Expected timeline: 1-4 weeks depending on review queue.

## Contact Information

For F-Droid submission help:
- F-Droid Forum: https://forum.f-droid.org/
- IRC: #fdroid on Libera.Chat
- Matrix: #fdroid:f-droid.org
