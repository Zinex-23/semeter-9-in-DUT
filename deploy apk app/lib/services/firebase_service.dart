import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_options.dart';

class FirebaseService {
  static FirebaseService? _instance;
  bool _isInitialized = false;
  String _error = '';

  // Singleton pattern
  static FirebaseService get instance {
    _instance ??= FirebaseService._();
    return _instance!;
  }

  FirebaseService._();

  bool get isInitialized => _isInitialized;
  String get error => _error;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _isInitialized = true;
      _error = '';
    } catch (e) {
      _error = e.toString();
      print('Firebase initialization error: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getLatestReadings() {
    if (!_isInitialized) {
      throw Exception('Firebase not initialized');
    }

    return FirebaseFirestore.instance
        .collection('readings')
        .orderBy('ts', descending: true)
        .limit(5)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        print('Raw reading data: $data'); // Debug log

        return {
          'timestamp': data['datetime']?.toString() ?? '',
          'temp': data['temperature_c'] != null
              ? data['temperature_c'].toStringAsFixed(2)
              : '—',
          'humidity': data['humidity_pct'] != null
              ? data['humidity_pct'].toStringAsFixed(1)
              : '—',
          'eCO2': data['eCO2_ppm']?.toString() ?? '—',
          'tvoc': data['TVOC_ppb']?.toString() ?? '—',
          'iaq': data['IAQ']?.toString() ?? '—',
        };
      }).toList();
    });
  }
}
