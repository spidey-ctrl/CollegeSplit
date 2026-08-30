import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Firebase configuration for the CollegeSplit Android app.
/// Values are mirrored from `android/app/google-services.json`.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDjzlLXxnQzXVw9A3_lU72A0N4Dj0R3H1k',
    appId: '1:266111353980:android:156ea812502a9ac6e3b5f9',
    messagingSenderId: '266111353980',
    projectId: 'collegesplit',
  );
}
