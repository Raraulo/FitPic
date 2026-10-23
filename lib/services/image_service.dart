import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();

  Future<String?> takePhoto(String prefix) async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
    );
    if (photo == null) return null;
    return _copyToLocal(photo.path, prefix);
  }

  Future<String?> pickPhoto(String prefix) async {
    final photo = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (photo == null) return null;
    return _copyToLocal(photo.path, prefix);
  }

  Future<String> _copyToLocal(String sourcePath, String prefix) async {
    final dir = await getApplicationDocumentsDirectory();
    final extension = _extensionFromPath(sourcePath);
    final fileName =
        '${prefix}_${DateTime.now().millisecondsSinceEpoch}$extension';
    final target = File('${dir.path}/$fileName');
    await File(sourcePath).copy(target.path);
    return target.path;
  }

  String _extensionFromPath(String path) {
    final fileName = path.split(RegExp(r'[\\/]')).last;
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) return '.jpg';
    return fileName.substring(dotIndex).toLowerCase();
  }

  /// Keep the selected photo as the garment image, without crops or re-encoding.
  Future<String> prepareGarmentImage(String sourcePath) async => sourcePath;

  /// Only the API receives a reduced copy; the saved file remains unchanged.
  static Future<Uint8List> visionBytes(String path) async {
    final original = await File(path).readAsBytes();
    return compute(encodeVisionPhoto, original);
  }
}

Uint8List encodeVisionPhoto(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  var photo = img.bakeOrientation(decoded);
  final longest = photo.width > photo.height ? photo.width : photo.height;
  if (longest > 1024) {
    photo = img.copyResize(
      photo,
      width: (photo.width * 1024 / longest).round().clamp(1, 1024),
      height: (photo.height * 1024 / longest).round().clamp(1, 1024),
      interpolation: img.Interpolation.linear,
    );
  }
  final canvas =
      img.Image(width: photo.width, height: photo.height, numChannels: 3);
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(canvas, photo);
  return img.encodeJpg(canvas, quality: 85);
}
