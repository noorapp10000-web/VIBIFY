# Vibify Setup Guide

## Step-by-Step Setup

### 1. Clone & Install Flutter

Make sure you have Flutter 3.22.0+ installed:
```bash
flutter --version
```

### 2. Install dependencies
```bash
cd vibify
flutter pub get
```

### 3. Generate code
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

This generates:
- `lib/core/router/app_router.g.dart` (GoRouter + Riverpod)
- Any Hive adapters you add later

### 4. Add fonts

Download Inter from https://fonts.google.com/specimen/Inter

Place in `assets/fonts/`:
```
assets/fonts/Inter-Regular.ttf
assets/fonts/Inter-Medium.ttf
assets/fonts/Inter-SemiBold.ttf
assets/fonts/Inter-Bold.ttf
```

### 5. Add app icon

Place a 1024×1024 PNG at `assets/icons/app_icon.png`

Then run:
```bash
flutter pub run flutter_launcher_icons:main
flutter pub run flutter_native_splash:create
```

### 6. Run the app
```bash
flutter run
```

---

## GitHub Actions (CI/CD)

### First build (unsigned debug APK)

Push to `main` or `develop`. The workflow automatically:
1. Installs Flutter
2. Runs `flutter analyze`
3. Runs all tests
4. Builds a debug APK
5. Uploads it as an artifact

Download the APK from the **Actions** tab → your workflow run → **Artifacts**.

### Signed release APK

1. Generate a keystore:
```bash
keytool -genkey -v \
  -keystore vibify-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias vibify
```

2. Encode it:
```bash
base64 vibify-release.jks | tr -d '\n'
```

3. Add these GitHub repository secrets:
   - `KEYSTORE_BASE64` → the base64 output
   - `KEYSTORE_PASSWORD` → your keystore password
   - `KEY_ALIAS` → `vibify`
   - `KEY_PASSWORD` → your key password

4. Push to `main` — the workflow builds and uploads a signed release APK.

### Create a GitHub Release

Tag your commit:
```bash
git tag v1.0.0
git push origin v1.0.0
```

The release workflow creates a GitHub Release with the APK attached.
