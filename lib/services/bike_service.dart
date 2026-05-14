import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/bike_model.dart';

/// Service quản lý dữ liệu xe (bikes) trên Cloud Firestore
/// Bao gồm CRUD và tự động tạo QR code Base64 khi thêm xe
class BikeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _collectionName = 'bikes';

  // ===================== READ =====================

  /// Stream lắng nghe toàn bộ danh sách xe (realtime)
  Stream<List<Bike>> getBikesStream() {
    return _db.collection(_collectionName).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Bike.fromJson(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Lấy danh sách xe theo trạm (realtime)
  Stream<List<Bike>> getBikesByStationStream(String stationId) {
    return _db
        .collection(_collectionName)
        .where('stationId', isEqualTo: stationId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Bike.fromJson(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Lấy danh sách xe theo trạm (one-time)
  Future<List<Bike>> getBikesByStation(String stationId) async {
    final snapshot = await _db
        .collection(_collectionName)
        .where('stationId', isEqualTo: stationId)
        .get();
    return snapshot.docs.map((doc) {
      return Bike.fromJson(doc.data(), doc.id);
    }).toList();
  }

  /// Lấy thông tin một xe theo document ID
  Future<Bike?> getBikeById(String docId) async {
    final doc = await _db.collection(_collectionName).doc(docId).get();
    if (doc.exists && doc.data() != null) {
      return Bike.fromJson(doc.data()!, doc.id);
    }
    return null;
  }

  // ===================== CREATE =====================

  /// Thêm xe mới — tự động tạo QR code Base64
  /// [bike] là object Bike chưa có qrImageBase64
  /// Hàm sẽ tạo QR từ qrData, encode Base64, rồi lưu vào Firestore
  Future<String> addBike(Bike bike) async {
    // Tạo qrData nếu chưa có
    String qrData = bike.qrData.isNotEmpty ? bike.qrData : 'BIKE_${bike.bikeId}';

    // Tạo QR code Base64
    String qrBase64 = await _generateQrBase64(qrData);

    // Tạo map dữ liệu và ghi đè qrData + qrImageBase64
    final data = bike.toJson();
    data['qrData'] = qrData;
    data['qrImageBase64'] = qrBase64;

    final docRef = await _db.collection(_collectionName).add(data);
    return docRef.id;
  }

  // ===================== UPDATE =====================

  /// Cập nhật thông tin xe theo document ID
  Future<void> updateBike(String docId, Map<String, dynamic> data) async {
    await _db.collection(_collectionName).doc(docId).update(data);
  }

  /// Cập nhật toàn bộ xe từ object Bike
  Future<void> updateBikeFull(String docId, Bike bike) async {
    await _db.collection(_collectionName).doc(docId).set(bike.toJson());
  }

  /// Tái tạo QR code cho xe (khi cần cập nhật QR)
  Future<void> regenerateQr(String docId, String qrData) async {
    String qrBase64 = await _generateQrBase64(qrData);
    await _db.collection(_collectionName).doc(docId).update({
      'qrData': qrData,
      'qrImageBase64': qrBase64,
    });
  }

  // ===================== DELETE =====================

  /// Xóa xe theo document ID
  Future<void> deleteBike(String docId) async {
    await _db.collection(_collectionName).doc(docId).delete();
  }

  // ===================== QR GENERATION =====================

  /// Tạo QR code từ chuỗi [data] và trả về chuỗi Base64 (PNG)
  /// Sử dụng QrPainter từ thư viện qr_flutter
  Future<String> _generateQrBase64(String data) async {
    try {
      final qrValidationResult = QrValidator.validate(
        data: data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      );

      if (qrValidationResult.status != QrValidationStatus.valid) {
        debugPrint('QR data không hợp lệ: $data');
        return '';
      }

      final qrCode = qrValidationResult.qrCode!;
      final painter = QrPainter.withQr(
        qr: qrCode,
        color: const Color(0xFF000000),
        emptyColor: const Color(0xFFFFFFFF),
        gapless: true,
      );

      // Render thành image
      const double size = 300;
      final ui.Image image = await painter.toImage(size);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        debugPrint('Không thể render QR image');
        return '';
      }

      // Encode sang Base64
      final bytes = byteData.buffer.asUint8List();
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('Lỗi tạo QR Base64: $e');
      return '';
    }
  }
}
