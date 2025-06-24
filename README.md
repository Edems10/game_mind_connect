
# Game Mind Connect - Flutter POC

[![Flutter](https://img.shields.io/badge/Flutter-3.19-blue)](https://flutter.dev)
[![Platforms](https://img.shields.io/badge/Platforms-Web%20%7C%20Android%20%7C%20iOS-green)](https://flutter.dev/multi-platform)

Proof-of-concept demonstrating real-time game data visualization with Flutter, running on **web browsers**, **Android**, and **iOS** devices.

## Key Features
- 🕹️ Real-time Dota 2 match visualization
- 🌐 WebSocket integration for live data streaming
- 📱 Responsive UI for mobile and web
- 🗺️ Interactive game map with hero/creep tracking
- ⏱️ Playback controls for match replay

## Project Structure
```

lib/
├── main.dart              \# App entry point
├── screens/               \# UI screens
├── services/              \# API and WebSocket services
├── models/                \# Data models
├── widgets/               \# Reusable UI components
└── assets/                \# Images and other resources

```

## Setup Instructions

### Prerequisites
- Flutter SDK (v3.19+)
- Chrome (for web testing)
- Android Studio/Xcode (for mobile testing)

### Installation
1. Clone the repository:
```

git clone https://github.com/your-username/game_mind_connect.git

```
2. Install dependencies:
```

flutter pub get

```

## Running the Project

### Web Development
```


# Enable web support

flutter config --enable-web

# Run in Chrome

flutter run -d chrome

```

### Mobile Development
```


# Android

flutter run -d android

# iOS

flutter run -d ios

```

## Build Instructions
```


# Web build (outputs to /build/web)

flutter build web --release

# Android APK

flutter build apk --release

# iOS

flutter build ios

```

## POC Highlights
- **Cross-platform execution**: Same codebase runs on web browsers, Android, and iOS
- **Real-time visualization**: WebSocket integration for live match data
- **Interactive UI**: Touch-friendly controls for mobile and desktop

