# Secure PII App (Android)

This is the Flutter Android app for the Secure PII Redaction System.

## Requirements
- Flutter SDK
- Android Studio
- Android emulator or physical device
- Android minSdk 23+ (biometric support)

## Run (Dev)
```bash
flutter pub get
flutter run --dart-define=BASE_URL=http://10.0.2.2:8000 --dart-define=ENV=dev
```

For a physical device on the same LAN:
```bash
flutter run --dart-define=BASE_URL=http://<your-ip>:8000 --dart-define=ENV=dev
```

## Build (Release)
```bash
flutter build apk --dart-define=BASE_URL=https://your-api.example.com --dart-define=ENV=prod
```

## Features
- File picker upload
- Redacted text output
- Optional redacted PDF download
- Base URL settings (in-app)
- API token (optional) set in app Settings when backend requires `APP_API_TOKEN`
- Audit log saved as JSON in app documents
- PIN + biometric lock

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
