import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import '../core/supabase_client.dart';
import '../main.dart' as app_main;

class AttendancePhotoUploadResult {
  final String photoUrl;
  final String storagePath;

  const AttendancePhotoUploadResult({
    required this.photoUrl,
    required this.storagePath,
  });
}

class PhotoUploadService {
  PhotoUploadService._();

  static final PhotoUploadService instance = PhotoUploadService._();

  /// Phase 66: Upload attendance photo to Cloudflare R2 via a Supabase
  /// Edge Function that mints a short-lived presigned PUT URL. The kiosk
  /// uploads bytes directly to R2; only the public read URL is returned to
  /// the caller for attachment to the attendance log.
  Future<AttendancePhotoUploadResult> uploadAttendancePhoto({
    required String outletId,
    required String employeeId,
    required DateTime logDate,
    required String logId,
    required Uint8List bytes,
    http.Client? httpClient,
  }) async {
    _ensureSupabaseReady();
    final fallbackPath = buildStoragePath(
      outletId: outletId,
      employeeId: employeeId,
      logDate: logDate,
      logId: logId,
    );

    final signResponse = await SupabaseClientFactory.kiosk.functions.invoke(
      'sign-r2-upload',
      body: {
        'outlet_id': outletId,
        'employee_id': employeeId,
        'log_date': _formatDate(logDate),
        'log_id': logId,
      },
    );

    if (signResponse.status >= 400 || signResponse.data is! Map) {
      throw StateError(
        'Failed to obtain R2 upload URL: status=${signResponse.status}',
      );
    }

    final data = (signResponse.data as Map).cast<String, dynamic>();
    final uploadUrl = (data['upload_url'] as String?)?.trim();
    final publicUrl = (data['public_url'] as String?)?.trim();
    final storagePath =
        (data['storage_path'] as String?)?.trim() ?? fallbackPath;

    if (uploadUrl == null ||
        uploadUrl.isEmpty ||
        publicUrl == null ||
        publicUrl.isEmpty) {
      throw StateError(
        'R2 upload URL response missing upload_url or public_url',
      );
    }

    final client = httpClient ?? http.Client();
    try {
      final putResponse = await client.put(
        Uri.parse(uploadUrl),
        headers: const {'Content-Type': 'image/jpeg'},
        body: bytes,
      );

      if (putResponse.statusCode < 200 || putResponse.statusCode >= 300) {
        throw StateError(
          'R2 upload failed: ${putResponse.statusCode} ${putResponse.body}',
        );
      }
    } finally {
      if (httpClient == null) client.close();
    }

    return AttendancePhotoUploadResult(
      photoUrl: publicUrl,
      storagePath: storagePath,
    );
  }

  Future<String> uploadAndAttachAttendancePhoto({
    required String outletId,
    required String employeeId,
    required DateTime logDate,
    required String logId,
    required Uint8List bytes,
  }) async {
    final upload = await uploadAttendancePhoto(
      outletId: outletId,
      employeeId: employeeId,
      logDate: logDate,
      logId: logId,
      bytes: bytes,
    );

    await attachAttendancePhoto(
      logId: logId,
      photoUrl: upload.photoUrl,
    );
    unawaited(
      requestGroomingAnalysis(
        logId: logId,
        photoPath: upload.storagePath,
        photoUrl: upload.photoUrl,
      ),
    );
    return upload.photoUrl;
  }

  Future<void> attachAttendancePhoto({
    required String logId,
    required String photoUrl,
  }) async {
    _ensureSupabaseReady();
    await SupabaseClientFactory.kiosk.rpc(
      'attach_attendance_photo',
      params: {
        'p_attendance_log_id': logId,
        'p_selfie_url': photoUrl,
        'p_photo_required': true,
      },
    );
  }

  Future<void> requestGroomingAnalysis({
    required String logId,
    required String photoPath,
    required String photoUrl,
  }) async {
    try {
      if (!app_main.supabaseReady) return;
      await SupabaseClientFactory.kiosk.functions.invoke(
        'analyze-attendance-photo',
        body: {
          'attendance_log_id': logId,
          'photo_path': photoPath,
          'photo_url': photoUrl,
        },
      );
    } catch (_) {
      // Grooming analysis is async QC only; attendance success must not depend
      // on the Edge Function being deployed or available.
    }
  }

  Future<String> savePhotoForRetry({
    required String outletId,
    required String employeeId,
    required DateTime logDate,
    required String logId,
    required Uint8List bytes,
  }) async {
    final photoFile = await _localPhotoFile(
      outletId: outletId,
      employeeId: employeeId,
      logDate: logDate,
      logId: logId,
    );
    await photoFile.parent.create(recursive: true);
    await photoFile.writeAsBytes(bytes, flush: true);

    final manifestFile = File('${photoFile.path}.json');
    await manifestFile.writeAsString(
      jsonEncode({
        'outlet_id': outletId,
        'employee_id': employeeId,
        'log_date': _formatDate(logDate),
        'log_id': logId,
        'photo_path': photoFile.path,
        'retry_count': 0,
      }),
      flush: true,
    );
    return photoFile.path;
  }

  Future<String> savePendingPhotoFile({
    required String outletId,
    required String employeeId,
    required DateTime logDate,
    required String localId,
    required Uint8List bytes,
  }) async {
    final photoFile = await _localPhotoFile(
      outletId: outletId,
      employeeId: employeeId,
      logDate: logDate,
      logId: localId,
    );
    await photoFile.parent.create(recursive: true);
    await photoFile.writeAsBytes(bytes, flush: true);
    return photoFile.path;
  }

  Future<bool> uploadLocalPhoto({
    required String outletId,
    required String employeeId,
    required DateTime logDate,
    required String logId,
    required String localPhotoPath,
  }) async {
    final file = File(localPhotoPath);
    if (!await file.exists()) return true;
    final bytes = await file.readAsBytes();
    await uploadAndAttachAttendancePhoto(
      outletId: outletId,
      employeeId: employeeId,
      logDate: logDate,
      logId: logId,
      bytes: bytes,
    );
    await _deletePhotoAndManifest(file);
    return true;
  }

  Future<int> retrySavedPhotos() async {
    final queueRoot = await _queueRoot();
    if (!await queueRoot.exists()) return 0;

    var uploaded = 0;
    final manifests = queueRoot
        .list(recursive: true)
        .where((entity) => entity is File && entity.path.endsWith('.json'));

    await for (final entity in manifests) {
      final manifest = entity as File;
      try {
        final data =
            jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
        final retryCount = (data['retry_count'] as num?)?.toInt() ?? 0;
        if (retryCount >= AppConstants.attendancePhotoUploadMaxRetries) {
          continue;
        }

        final photoPath = data['photo_path']?.toString();
        final logDate = DateTime.tryParse(data['log_date']?.toString() ?? '');
        final outletId = data['outlet_id']?.toString();
        final employeeId = data['employee_id']?.toString();
        final logId = data['log_id']?.toString();
        if (photoPath == null ||
            logDate == null ||
            outletId == null ||
            employeeId == null ||
            logId == null) {
          continue;
        }

        await uploadLocalPhoto(
          outletId: outletId,
          employeeId: employeeId,
          logDate: logDate,
          logId: logId,
          localPhotoPath: photoPath,
        );
        uploaded++;
      } catch (_) {
        await _incrementManifestRetry(manifest);
      }
    }

    return uploaded;
  }

  String buildStoragePath({
    required String outletId,
    required String employeeId,
    required DateTime logDate,
    required String logId,
  }) {
    return '${_cleanPathSegment(outletId)}/${_cleanPathSegment(employeeId)}/'
        '${_formatDate(logDate)}/${_cleanPathSegment(logId)}.jpg';
  }

  Future<File> _localPhotoFile({
    required String outletId,
    required String employeeId,
    required DateTime logDate,
    required String logId,
  }) async {
    final root = await _queueRoot();
    return File(
      p.join(
        root.path,
        _cleanPathSegment(outletId),
        _cleanPathSegment(employeeId),
        _formatDate(logDate),
        '${_cleanPathSegment(logId)}.jpg',
      ),
    );
  }

  Future<Directory> _queueRoot() async {
    final dir = await getApplicationDocumentsDirectory();
    return Directory(p.join(dir.path, 'attendance_photo_queue'));
  }

  Future<void> _deletePhotoAndManifest(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
    final manifest = File('${file.path}.json');
    if (await manifest.exists()) {
      await manifest.delete();
    }
  }

  Future<void> _incrementManifestRetry(File manifest) async {
    try {
      final data =
          jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
      final retryCount = (data['retry_count'] as num?)?.toInt() ?? 0;
      data['retry_count'] = retryCount + 1;
      await manifest.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {}
  }

  void _ensureSupabaseReady() {
    if (!app_main.supabaseReady) {
      throw StateError('Supabase is not initialized');
    }
  }

  static String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _cleanPathSegment(String value) {
    return value.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }
}
