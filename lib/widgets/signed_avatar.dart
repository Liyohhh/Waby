import 'package:flutter/material.dart';
import '../services/image_upload_service.dart';

/// Circular avatar that resolves a private Supabase Storage path into a
/// signed URL and displays it, falling back to an initial letter or icon
/// while loading or when no photo is set.
///
/// Resolved signed URLs are cached per path for the lifetime of the app
/// session, so repeated rebuilds (e.g. from frequent live-data stream
/// ticks on the home dashboard) don't re-request a new signed URL on
/// every frame.
class SignedAvatar extends StatelessWidget {
  const SignedAvatar({
    super.key,
    required this.photoPath,
    required this.radius,
    required this.backgroundColor,
    this.fallbackText,
    this.fallbackIcon,
    this.iconColor = Colors.white,
  });

  final String? photoPath;
  final double radius;
  final Color backgroundColor;
  final String? fallbackText;
  final IconData? fallbackIcon;
  final Color iconColor;

  static final Map<String, Future<String?>> _cache = {};

  /// Call this immediately after a successful re-upload to the same path,
  /// so the next build fetches a fresh signed URL instead of reusing the
  /// stale cached one from before the photo changed.
  static void invalidate(String path) => _cache.remove(path);

  Future<String?> _resolve() {
    final path = photoPath;
    if (path == null || path.isEmpty) return Future.value(null);
    return _cache.putIfAbsent(
        path, () => ImageUploadService().signedUrlFor(path));
  }

  @override
  Widget build(BuildContext context) {
    if (photoPath == null || photoPath!.isEmpty) {
      return _fallback();
    }
    return FutureBuilder<String?>(
      future: _resolve(),
      builder: (context, snap) {
        final url = snap.data;
        if (url == null) return _fallback();
        return CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor,
          backgroundImage: NetworkImage(url),
        );
      },
    );
  }

  Widget _fallback() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: fallbackIcon != null
          ? Icon(fallbackIcon, color: iconColor, size: radius * 0.85)
          : Text(
              fallbackText ?? '?',
              style: TextStyle(
                color: iconColor,
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.75,
              ),
            ),
    );
  }
}
