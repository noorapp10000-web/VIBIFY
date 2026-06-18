# Vibify — Premium Music Player

A world-class Flutter music player application featuring YouTube streaming, local music library management, background audio playback, and a premium design system.

---

## Tech Stack

| Layer | Package |
|-------|---------|
| State Management | flutter_riverpod + riverpod_generator |
| Routing | go_router |
| Audio | just_audio + audio_service + just_audio_background |
| YouTube | youtube_explode_dart |
| DI | get_it |
| Local DB | hive + hive_flutter |
| Networking | dio |
| Local Music | on_audio_query |
| UI | cached_network_image, shimmer, palette_generator |

---

## Architecture

Clean Architecture with feature-first structure:

```
lib/
├── core/               # Shared utilities, theme, routing, DI
│   ├── constants/
│   ├── di/             # GetIt setup
│   ├── errors/
│   ├── extensions/
│   ├── network/
│   ├── router/         # GoRouter
│   ├── theme/          # Colors, typography, themes
│   ├── utils/
│   └── widgets/        # Shared widgets (MainScaffold)
│
└── features/
    ├── home/           # Dashboard, recently played, favorites
    ├── search/         # YouTube search
    ├── library/        # Playlists, favorites, history
    ├── local_music/    # On-device music scanner
    ├── player/         # Audio engine, Player screen, Mini player
    ├── playlists/      # CRUD playlists
    ├── downloads/      # Background download manager
    └── settings/       # Theme, audio quality, storage
```

Each feature follows:
```
feature/
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
└── presentation/
    ├── pages/
    ├── providers/
    └── widgets/
```

---

## Color System

| Token | Light | Dark |
|-------|-------|------|
| Primary | `#D6B48A` | `#D6B48A` |
| Background | `#F6F1EB` | `#111111` |
| Surface | `#EFE6DB` | `#1A1A1A` |
| Text | `#1D1D1D` | `#FFFFFF` |
| Secondary Text | `#6B6B6B` | `#B3B3B3` |

---

## Getting Started

### Prerequisites
- Flutter 3.22.0+
- Dart 3.3.0+
- Android SDK 21+

### Setup

```bash
# Install dependencies
flutter pub get

# Generate code (Riverpod, GoRouter, Hive adapters)
flutter pub run build_runner build --delete-conflicting-outputs

# Run on device/emulator
flutter run
```

### Fonts

Download and place Inter font files in `assets/fonts/`:
- `Inter-Regular.ttf`
- `Inter-Medium.ttf`
- `Inter-SemiBold.ttf`
- `Inter-Bold.ttf`

Download from: https://fonts.google.com/specimen/Inter

### App Icon & Splash Screen

1. Place your `app_icon.png` (1024×1024) in `assets/icons/`
2. Place `app_icon_foreground.png` (adaptive icon foreground) in `assets/icons/`
3. Run:

```bash
flutter pub run flutter_launcher_icons:main
flutter pub run flutter_native_splash:create
```

---

## GitHub Actions CI/CD

The `.github/workflows/android-build.yml` pipeline:

1. **Analyze & Test** — runs `flutter analyze` and all tests
2. **Build APK** — builds debug APK (or signed release if keystore secrets are set)
3. **Build AAB** — builds App Bundle for Play Store (main branch only)
4. **Release** — creates GitHub release on version tags

### Required Secrets (for signed release)

| Secret | Description |
|--------|-------------|
| `KEYSTORE_BASE64` | Base64-encoded `.jks` keystore file |
| `KEYSTORE_PASSWORD` | Keystore password |
| `KEY_ALIAS` | Key alias |
| `KEY_PASSWORD` | Key password |

### Generating a Keystore

```bash
keytool -genkey -v \
  -keystore vibify-release.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias vibify

# Encode for GitHub secret:
base64 vibify-release.jks | tr -d '\n'
```

---

## Running Tests

```bash
# All tests
flutter test

# Unit tests only
flutter test test/unit/

# Widget tests only
flutter test test/widget/

# With coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

---

## Features

| Feature | Status |
|---------|--------|
| YouTube search & streaming | ✅ |
| Background audio playback | ✅ |
| Lock screen / notification controls | ✅ |
| Bluetooth headset controls | ✅ |
| Local music library (MP3, FLAC, etc.) | ✅ |
| Queue management | ✅ |
| Shuffle & repeat modes | ✅ |
| Sleep timer | ✅ |
| Playback speed control | ✅ |
| Playlist creation & management | ✅ |
| Download manager | ✅ |
| Light & dark themes | ✅ |
| Dynamic album art colors | ✅ |
| Recently played history | ✅ |
| Favorites | ✅ |
| Offline support (local + downloads) | ✅ |
