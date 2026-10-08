# Szczoteczki

Flutter app for keeping a local record of repaired toothbrushes. Each record has
a photo, serial number, and repair date. The gallery supports serial-number
search, record details, and deletion.

All records are stored on the device. Photos are copied to the app's documents
directory; record metadata is stored with `shared_preferences`.

## Run

```sh
flutter pub get
flutter run
```

To run the widget tests and static analysis:

```sh
flutter test
flutter analyze
```

The app is configured for Android and iOS. iOS camera and photo-library
permission descriptions are included in `ios/Runner/Info.plist`.
