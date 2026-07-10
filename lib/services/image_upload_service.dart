import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';

/// Shared helper for picking, cropping, and uploading avatar/photo images
/// to the private `avatars` Supabase Storage bucket.
///
/// Path convention: `{family_id}/{entityType}/{entityId}.jpg`
/// where entityType is one of 'profiles' | 'children' | 'devices'.
class ImageUploadService {
  final _client = Supabase.instance.client;

  /// Opens the picker, crops to a square, uploads to the `avatars` bucket,
  /// and returns the storage path plus the local cropped file (for an
  /// instant preview without waiting on a signed URL). Returns null if the
  /// user cancels at any step (picker or cropper).
  Future<UploadedImage?> pickCropAndUpload({
    required ImageSource source,
    required String familyId,
    required String entityType,
    required String entityId,
  }) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) return null;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: AppColors.navy,
          toolbarWidgetColor: Colors.white,
          aspectRatioPresets: [CropAspectRatioPreset.square],
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop Photo',
          aspectRatioLockEnabled: true,
          aspectRatioPresets: [CropAspectRatioPreset.square],
        ),
      ],
    );
    if (cropped == null) return null;

    final path = '$familyId/$entityType/$entityId.jpg';
    final localFile = File(cropped.path);
    final bytes = await localFile.readAsBytes();

    await _client.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(
        contentType: 'image/jpeg',
        upsert: true,
      ),
    );

    return UploadedImage(path: path, localFile: localFile);
  }

  /// Resolves a stored path into a time-limited signed URL for display.
  /// Returns null if [path] is null/empty or generation fails (e.g. the
  /// object was deleted).
  Future<String?> signedUrlFor(String? path,
      {int expiresInSeconds = 3600}) async {
    if (path == null || path.isEmpty) return null;
    try {
      return await _client.storage
          .from('avatars')
          .createSignedUrl(path, expiresInSeconds);
    } catch (_) {
      return null;
    }
  }
}

/// Result of a successful pick-crop-upload: the storage path to persist in
/// the database, plus the local cropped file for an instant UI preview.
class UploadedImage {
  const UploadedImage({required this.path, required this.localFile});
  final String path;
  final File localFile;
}
