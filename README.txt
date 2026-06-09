FundiHub Phase 7 safe update

Replace these files in your project:
- lib/services/user_service.dart
- lib/providers/auth_provider.dart
- lib/screens/profile/client_profile_completion_screen.dart
- lib/screens/profile/fundi_profile_completion_screen.dart
- android/app/src/main/AndroidManifest.xml

pubspec.yaml is included for reference; your current pubspec already has firebase_storage and image_picker.

After replacing:
flutter clean
flutter pub get
flutter run

Test:
1. Register a new client and add profile picture.
2. Register a new fundi and add profile picture.
3. Use current location and confirm Region/District/Area text fields.
4. Save profile and re-open app; profile image should remain.
