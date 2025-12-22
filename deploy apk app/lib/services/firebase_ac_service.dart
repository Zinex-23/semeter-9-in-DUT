import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Firebase Service để đồng bộ dữ liệu điều hòa
class FirebaseACService {
  static final FirebaseACService _instance = FirebaseACService._internal();
  factory FirebaseACService() => _instance;
  FirebaseACService._internal();

  // Khởi tạo Firestore với try-catch để handle lỗi version
  FirebaseFirestore get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      debugPrint('⚠️ Firestore initialization error: $e');
      rethrow;
    }
  }

  /// Lưu trạng thái điều hòa lên Firebase
  Future<void> saveACState({
    required String acId,
    required double temperature,
    required String mode,
    required bool isOn,
  }) async {
    try {
      await _firestore.collection('air_conditioners').doc(acId).set({
        'temperature': temperature,
        'mode': mode,
        'isOn': isOn,
        'lastUpdated': FieldValue.serverTimestamp(),
        'location': acId == 'ac_unit_1' ? 'Office Room 1' : 'Office Room 2',
      }, SetOptions(merge: true));

      debugPrint(
          '✅ AC $acId saved to Firebase: ${temperature}°C, $mode, ${isOn ? "ON" : "OFF"}');
    } catch (e) {
      debugPrint('❌ Failed to save AC $acId to Firebase: $e');
    }
  }

  /// Lắng nghe thay đổi từ Firebase
  Stream<DocumentSnapshot> getACStateStream(String acId) {
    return _firestore.collection('air_conditioners').doc(acId).snapshots();
  }

  /// Lấy trạng thái hiện tại từ Firebase
  Future<Map<String, dynamic>?> getACState(String acId) async {
    try {
      final doc =
          await _firestore.collection('air_conditioners').doc(acId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('❌ Failed to get AC $acId from Firebase: $e');
      return null;
    }
  }

  /// Khởi tạo dữ liệu mặc định cho AC units
  Future<void> initializeACUnits() async {
    final defaultData = {
      'ac_unit_1': {
        'temperature': 25.0,
        'mode': 'Cool',
        'isOn': true,
        'location': 'Office Room 1',
        'lastUpdated': FieldValue.serverTimestamp(),
      },
      'ac_unit_2': {
        'temperature': 25.0,
        'mode': 'Cool',
        'isOn': true,
        'location': 'Office Room 2',
        'lastUpdated': FieldValue.serverTimestamp(),
      },
    };

    for (final entry in defaultData.entries) {
      final acId = entry.key;
      final data = entry.value;

      // Chỉ tạo nếu chưa có dữ liệu
      final existing = await getACState(acId);
      if (existing == null) {
        await _firestore.collection('air_conditioners').doc(acId).set(data);
        debugPrint('🏗️ Initialized $acId with default data');
      }
    }
  }
}
