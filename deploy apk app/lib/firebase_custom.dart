// Optional custom FirebaseOptions holder.
// If you want to override DefaultFirebaseOptions at runtime, set
// `FirebaseCustomOptions.options = yourOptions;`
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class FirebaseCustomOptions {
  // Keep null by default. Set to a FirebaseOptions instance to override.
  static FirebaseOptions? options;
}
