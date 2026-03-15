import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/employee_badge.dart';

/// Reusable avatar widget that renders an employee photo with an optional
/// badge ring (solid/gradient/glow) and emoji chip overlay.
///
/// Usage:
/// ```dart
/// BadgeAvatar(
///   photoUrl: employee.photoUrl,
///   name: employee.name,
///   size: 52,
///   badge: resolvedBadge, // nullable -- no badge = no ring
/// )
/// ```
class BadgeAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double size;
  final EmployeeBadge? badge;

  const BadgeAvatar({
    super.key,
    this.photoUrl,
    required this.name,
    this.size = 52,
    this.badge,
  });

  /// Ring width scales with avatar size
  double get _ringWidth {
    if (size >= 52) return 3.0;
    if (size >= 40) return 2.5;
    return 2.0;
  }

  /// Gap between ring and avatar
  double get _ringGap {
    if (size >= 52) return 2.0;
    if (size >= 40) return 1.5;
    return 1.0;
  }

  /// Emoji chip size scales with avatar
  double get _emojiSize {
    if (size >= 52) return 20.0;
    if (size >= 40) return 18.0;
    return 16.0;
  }

  @override
  Widget build(BuildContext context) {
    if (badge == null) {
      return _buildPlainAvatar();
    }
    return _buildBadgedAvatar();
  }

  /// Plain avatar with no ring (badge is null)
  Widget _buildPlainAvatar() {
    return SizedBox(
      width: size,
      height: size,
      child: _buildAvatarImage(size),
    );
  }

  /// Avatar with badge ring and emoji chip
  Widget _buildBadgedAvatar() {
    final totalSize = size + (_ringWidth + _ringGap) * 2;

    return SizedBox(
      width: totalSize,
      height: totalSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Ring layer
          _buildRing(totalSize),
          // Avatar (centered inside ring)
          _buildAvatarImage(size),
          // Emoji chip overlay
          if (badge!.emoji.isNotEmpty) _buildEmojiChip(totalSize),
        ],
      ),
    );
  }

  /// Build the ring based on badge border style
  Widget _buildRing(double totalSize) {
    switch (badge!.style) {
      case BadgeBorderStyle.solid:
        return _buildSolidRing(totalSize);
      case BadgeBorderStyle.gradient:
        return _buildGradientRing(totalSize);
      case BadgeBorderStyle.glow:
        return _buildGlowRing(totalSize);
    }
  }

  /// Solid color ring
  Widget _buildSolidRing(double totalSize) {
    return Container(
      width: totalSize,
      height: totalSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: badge!.color1,
          width: _ringWidth,
        ),
      ),
    );
  }

  /// Gradient ring using CustomPaint with SweepGradient
  Widget _buildGradientRing(double totalSize) {
    return CustomPaint(
      size: Size(totalSize, totalSize),
      painter: _GradientRingPainter(
        color1: badge!.color1,
        color2: badge!.color2 ?? badge!.color1.withValues(alpha: 0.5),
        strokeWidth: _ringWidth,
      ),
    );
  }

  /// Solid ring with glow (BoxShadow)
  Widget _buildGlowRing(double totalSize) {
    return Container(
      width: totalSize,
      height: totalSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: badge!.color1,
          width: _ringWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: badge!.color1.withValues(alpha: 0.4),
            spreadRadius: 2,
            blurRadius: 6,
          ),
          BoxShadow(
            color: badge!.color1.withValues(alpha: 0.2),
            spreadRadius: 4,
            blurRadius: 12,
          ),
        ],
      ),
    );
  }

  /// Avatar image (photo or initial fallback)
  Widget _buildAvatarImage(double avatarSize) {
    return ClipOval(
      child: SizedBox(
        width: avatarSize,
        height: avatarSize,
        child: photoUrl != null && photoUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: photoUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _buildInitialAvatar(avatarSize),
                errorWidget: (_, __, ___) => _buildInitialAvatar(avatarSize),
              )
            : _buildInitialAvatar(avatarSize),
      ),
    );
  }

  /// Fallback avatar with employee initial
  Widget _buildInitialAvatar(double avatarSize) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: avatarSize,
      height: avatarSize,
      color: const Color(0xFFE5E7EB),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: avatarSize * 0.4,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF6B7280),
        ),
      ),
    );
  }

  /// Emoji chip overlay at bottom-right
  Widget _buildEmojiChip(double totalSize) {
    return Positioned(
      bottom: 0,
      right: 0,
      child: Container(
        width: _emojiSize,
        height: _emojiSize,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          badge!.emoji,
          style: TextStyle(fontSize: _emojiSize * 0.6),
        ),
      ),
    );
  }
}

/// CustomPainter for gradient ring using SweepGradient.
/// Same technique as Phase 6 kiosk idle screen _GradientRingPainter.
class _GradientRingPainter extends CustomPainter {
  final Color color1;
  final Color color2;
  final double strokeWidth;

  const _GradientRingPainter({
    required this.color1,
    required this.color2,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: math.pi * 2,
      colors: [color1, color2, color1],
      stops: const [0.0, 0.5, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientRingPainter oldDelegate) {
    return oldDelegate.color1 != color1 ||
        oldDelegate.color2 != color2 ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
