import 'package:dio/dio.dart';

import '../network/api_error.dart';
import '../network/auth_interceptor.dart';

class SyncOperationDto {
  const SyncOperationDto({
    required this.entityType,
    required this.entityId,
    required this.op,
    required this.payload,
    required this.clientTs,
  });

  final String entityType;
  final String entityId;
  final String op;
  final Map<String, dynamic> payload;
  final DateTime clientTs;

  Map<String, dynamic> toJson() => {
    'entity_type': entityType,
    'entity_id': entityId,
    'op': op,
    'payload': payload,
    'client_ts': clientTs.toIso8601String(),
  };
}

enum SyncPushStatus {
  applied,
  idempotent,
  conflict,
  rejected;

  static SyncPushStatus parse(String value) {
    return SyncPushStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => throw FormatException('Unknown push status: $value'),
    );
  }
}

class SyncPushResult {
  const SyncPushResult({
    required this.entityId,
    required this.status,
    this.error,
  });

  final String entityId;
  final SyncPushStatus status;
  final ApiError? error;

  bool get acked => status == SyncPushStatus.applied || status == SyncPushStatus.idempotent;

  factory SyncPushResult.fromJson(Map<String, dynamic> json) {
    return SyncPushResult(
      entityId: json['entity_id'] as String,
      status: SyncPushStatus.parse(json['status'] as String),
      error: json['error'] is Map<String, dynamic>
          ? ApiError.fromBody(json['error'] as Map<String, dynamic>)
          : null,
    );
  }
}

enum SyncChangeOp {
  upsert,
  archive,
  delete;

  static SyncChangeOp parse(String value) {
    return SyncChangeOp.values.firstWhere(
      (op) => op.name == value,
      orElse: () => throw FormatException('Unknown change op: $value'),
    );
  }
}

class SyncChange {
  const SyncChange({
    required this.entityType,
    required this.entityId,
    required this.op,
    required this.payload,
    required this.serverTs,
  });

  final String entityType;
  final String entityId;
  final SyncChangeOp op;
  final Map<String, dynamic> payload;
  final DateTime serverTs;

  factory SyncChange.fromJson(Map<String, dynamic> json) {
    return SyncChange(
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      op: SyncChangeOp.parse(json['op'] as String),
      payload: (json['payload'] ?? const {}) as Map<String, dynamic>,
      serverTs: DateTime.parse(json['server_ts'] as String),
    );
  }
}

class SyncPullPage {
  const SyncPullPage({required this.cursor, required this.changes});

  final String cursor;
  final List<SyncChange> changes;
}

abstract class SyncApi {
  Future<List<SyncPushResult>> push(List<SyncOperationDto> operations);
  Future<SyncPullPage> pull(String cursor);
}

class DioSyncApi implements SyncApi {
  DioSyncApi(this._dio);

  final Dio _dio;

  @override
  Future<List<SyncPushResult>> push(List<SyncOperationDto> operations) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/sync/push',
        data: {
          'operations': operations.map((operation) => operation.toJson()).toList(),
        },
      );
      final results = response.data?['results'];
      if (results is! List) return const [];
      return results
          .whereType<Map<String, dynamic>>()
          .map(SyncPushResult.fromJson)
          .toList();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<SyncPullPage> pull(String cursor) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/sync/changes',
        queryParameters: {'cursor': cursor},
      );
      final data = response.data ?? const {};
      final changes = data['changes'];
      return SyncPullPage(
        cursor: data['cursor'] as String? ?? cursor,
        changes: changes is List
            ? changes
                  .whereType<Map<String, dynamic>>()
                  .map(SyncChange.fromJson)
                  .toList()
            : const [],
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }
}
