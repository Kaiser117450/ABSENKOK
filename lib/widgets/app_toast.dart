import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

/// Centralized toast helper wrapping toastification with brand-consistent defaults.
///
/// Requires [ToastificationWrapper] or [Toastification] at the widget tree root.
///
/// Usage:
/// ```dart
/// AppToast.success(context, 'Data berhasil disimpan');
/// AppToast.error(context, 'Terjadi kesalahan, coba lagi');
/// AppToast.info(context, 'Sinkronisasi berjalan di latar belakang');
/// ```
class AppToast {
  AppToast._(); // prevent instantiation

  /// Show a success toast (green, auto-closes after 3 seconds).
  static void success(BuildContext context, String message) {
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.flat,
      title: Text(
        message,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      autoCloseDuration: const Duration(seconds: 3),
      showProgressBar: false,
    );
  }

  /// Show an error toast (red, auto-closes after 4 seconds).
  static void error(BuildContext context, String message) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.flat,
      title: Text(
        message,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      autoCloseDuration: const Duration(seconds: 4),
      showProgressBar: false,
    );
  }

  /// Show an info toast (blue, auto-closes after 3 seconds).
  static void info(BuildContext context, String message) {
    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.flat,
      title: Text(
        message,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      autoCloseDuration: const Duration(seconds: 3),
      showProgressBar: false,
    );
  }
}
