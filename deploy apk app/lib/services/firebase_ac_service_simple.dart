import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Firebase Service đơn giản để đồng bộ AC data
class FirebaseACService {
  static final FirebaseACService _instance = FirebaseACService._internal();
  factory FirebaseACService() => _instance;
  FirebaseACService._internal();

  /// Lưu trạng thái AC lên Firebase
  Future<void> saveACState({
    required String acId,
    required double temperature,
    required String mode,
    required bool isOn,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('air_conditioners')
          .doc(acId)
          .set({
        'temperature': temperature,
        'mode': mode,
        'isOn': isOn,
        'lastUpdated': FieldValue.serverTimestamp(),
        'location': acId == 'ac_unit_1' ? 'Office Room 1' : 'Office Room 2',
      });

      debugPrint(
          '✅ Firebase saved: $acId = ${temperature}°C, $mode, ${isOn ? "ON" : "OFF"}');
    } catch (e) {
      debugPrint('❌ Firebase error: $e');
    }
  }

  /// Lắng nghe thay đổi từ Firebase
  Stream<DocumentSnapshot> getACStateStream(String acId) {
    return FirebaseFirestore.instance
        .collection('air_conditioners')
        .doc(acId)
        .snapshots();
  }

  /// Khởi tạo dữ liệu mặc định
  Future<void> initializeACUnits() async {
    final units = ['ac_unit_1', 'ac_unit_2'];

    for (final unitId in units) {
      try {
        // Kiểm tra xem document đã tồn tại chưa
        final doc = await FirebaseFirestore.instance
            .collection('air_conditioners')
            .doc(unitId)
            .get();

        if (!doc.exists) {
          // Tạo document mới với dữ liệu mặc định
          await saveACState(
            acId: unitId,
            temperature: 25.0,
            mode: 'Cool',
            isOn: true,
          );
          debugPrint('🏗️ Initialized $unitId');
        }
      } catch (e) {
        debugPrint('❌ Init error for $unitId: $e');
      }
    }
  }
}
