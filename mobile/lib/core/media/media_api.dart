import 'dart:io';

import 'package:dio/dio.dart';

import '../network/api_error.dart';
import '../network/auth_interceptor.dart';

enum MediaPurpose {
  vehiclePhoto('vehicle_photo'),
  document('document'),
  serviceReceipt('service_receipt'),
  expenseReceipt('expense_receipt');

  const MediaPurpose(this.storage);

  final String storage;
}

class MediaObject {
  const MediaObject({
    required this.id,
    required this.contentType,
    required this.byteSize,
    this.downloadUrl,
    this.expiresAt,
  });

  factory MediaObject.fromJson(Map<String, dynamic> json) {
    return MediaObject(
      id: json['id'] as String,
      contentType: json['content_type'] as String? ?? '',
      byteSize: json['byte_size'] as int? ?? 0,
      downloadUrl: json['download_url'] as String?,
      expiresAt: json['expires_at'] is String ? DateTime.parse(json['expires_at'] as String) : null,
    );
  }

  final String id;
  final String contentType;
  final int byteSize;
  final String? downloadUrl;
  final DateTime? expiresAt;
}

abstract class MediaApi {
  static const maxBytes = 15 * 1024 * 1024;

  Future<MediaObject> upload({
    required String id,
    required File file,
    required MediaPurpose purpose,
  });

  Future<MediaObject> get(String mediaId);
}

class DioMediaApi implements MediaApi {
  DioMediaApi(this._dio);

  final Dio _dio;

  @override
  Future<MediaObject> upload({
    required String id,
    required File file,
    required MediaPurpose purpose,
  }) async {
    final size = file.lengthSync();
    if (size > MediaApi.maxBytes) {
      throw const ApiError(
        code: 'media_too_large',
        message: 'File exceeds the 15MB limit',
      );
    }
    try {
      final form = FormData.fromMap({
        'id': id,
        'purpose': purpose.storage,
        'file': await MultipartFile.fromFile(file.path),
      });
      final response = await _dio.post<Map<String, dynamic>>('/media', data: form);
      return MediaObject.fromJson(response.data!);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<MediaObject> get(String mediaId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/media/$mediaId');
      return MediaObject.fromJson(response.data!);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }
}
