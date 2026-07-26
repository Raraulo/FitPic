import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();

  Future<String?> takePhoto(String prefix) async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (photo == null) return null;
    return _copyToLocal(photo.path, prefix);
  }

  Future<String?> pickPhoto(String prefix) async {
    final photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (photo == null) return null;
    return _copyToLocal(photo.path, prefix);
  }

  Future<String?> cropGarmentImage({
    required String sourcePath,
    required String garmentId,
    List<num>? bbox,
    int index = 0,
    int totalItems = 1,
  }) async {
    try {
      final file = File(sourcePath);
      if (!file.existsSync()) return null;
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      final imgW = decoded.width;
      final imgH = decoded.height;

      int x = 0, y = 0, w = imgW, h = imgH;

      if (bbox != null && bbox.length >= 4) {
        double ymin = bbox[0].toDouble();
        double xmin = bbox[1].toDouble();
        double ymax = bbox[2].toDouble();
        double xmax = bbox[3].toDouble();

        // If bbox is normalized in range [0.0, 1.0], scale to [0.0, 100.0]
        final maxVal = bbox.reduce((a, b) => a > b ? a : b);
        if (maxVal <= 1.0 && maxVal > 0.0) {
          ymin *= 100.0;
          xmin *= 100.0;
          ymax *= 100.0;
          xmax *= 100.0;
        } else if (ymax > 100 || xmax > 100) {
          ymin /= 10.0;
          xmin /= 10.0;
          ymax /= 10.0;
          xmax /= 10.0;
        }

        // Add padding margin to ensure entire garment is included cleanly
        ymin = (ymin - 3.0).clamp(0.0, 100.0);
        xmin = (xmin - 3.0).clamp(0.0, 100.0);
        ymax = (ymax + 3.0).clamp(ymin + 5.0, 100.0);
        xmax = (xmax + 3.0).clamp(xmin + 5.0, 100.0);

        x = (xmin * imgW / 100.0).round().clamp(0, imgW - 1);
        y = (ymin * imgH / 100.0).round().clamp(0, imgH - 1);
        w = ((xmax - xmin) * imgW / 100.0).round().clamp(1, imgW - x);
        h = ((ymax - ymin) * imgH / 100.0).round().clamp(1, imgH - y);
      } else if (totalItems > 1) {
        if (totalItems == 2) {
          w = (imgW * 0.5).round();
          x = (index % 2) * w;
        } else if (totalItems == 3) {
          if (index == 0) {
            x = 0; y = 0; w = (imgW * 0.48).round(); h = (imgH * 0.65).round();
          } else if (index == 1) {
            x = (imgW * 0.48).round(); y = 0; w = (imgW * 0.52).round(); h = imgH;
          } else {
            x = 0; y = (imgH * 0.60).round(); w = (imgW * 0.48).round(); h = (imgH * 0.40).round();
          }
        } else {
          int cols = 2;
          int rows = (totalItems / cols).ceil();
          w = (imgW / cols).round();
          h = (imgH / rows).round();
          x = (index % cols) * w;
          y = (index ~/ cols) * h;
        }
      }

      final cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
      final dir = await getApplicationDocumentsDirectory();
      final targetPath = '${dir.path}/crop_$garmentId.jpg';
      final croppedBytes = img.encodeJpg(cropped, quality: 85);
      await File(targetPath).writeAsBytes(croppedBytes);
      return targetPath;
    } catch (_) {
      return sourcePath;
    }
  }

  Future<String> _copyToLocal(String sourcePath, String prefix) async {
    final dir = await getApplicationDocumentsDirectory();
    final extension = _extensionFromPath(sourcePath);
    final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}$extension';
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

  /// Removes the background of a garment photo by flood-filling the
  /// background (sampled from corners) with white and saves a new file.
  /// Returns the path of the processed image.
  Future<String> removeBackground(String sourcePath) async {
    try {
      final bytes = await File(sourcePath).readAsBytes();
      final src = img.decodeImage(bytes);
      if (src == null) return sourcePath;

      // Convert to RGBA so we can manipulate transparency
      final image = img.Image(width: src.width, height: src.height, numChannels: 4);
      for (int y = 0; y < src.height; y++) {
        for (int x = 0; x < src.width; x++) {
          image.setPixel(x, y, src.getPixel(x, y));
        }
      }

      // Sample background color from the four corners (3×3 patch average)
      final bgColor = _sampleCornerColor(image);

      // Flood-fill from all four corners using a tolerance-based BFS
      const tolerance = 40;
      final white = img.ColorRgba8(255, 255, 255, 255);

      _floodFill(image, 0, 0, bgColor, white, tolerance);
      _floodFill(image, image.width - 1, 0, bgColor, white, tolerance);
      _floodFill(image, 0, image.height - 1, bgColor, white, tolerance);
      _floodFill(image, image.width - 1, image.height - 1, bgColor, white, tolerance);

      final dir = await getApplicationDocumentsDirectory();
      final outPath = '${dir.path}/bg_removed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(outPath).writeAsBytes(img.encodeJpg(image, quality: 90));
      return outPath;
    } catch (_) {
      return sourcePath; // return original if anything fails
    }
  }

  /// Averages the pixel color of small corner patches.
  img.Color _sampleCornerColor(img.Image image) {
    final corners = <img.Color>[];
    const patch = 3;
    final w = image.width;
    final h = image.height;
    for (int dy = 0; dy < patch; dy++) {
      for (int dx = 0; dx < patch; dx++) {
        corners.add(image.getPixel(dx, dy));
        corners.add(image.getPixel(w - 1 - dx, dy));
        corners.add(image.getPixel(dx, h - 1 - dy));
        corners.add(image.getPixel(w - 1 - dx, h - 1 - dy));
      }
    }
    final r = corners.map((c) => c.r.toInt()).reduce((a, b) => a + b) ~/ corners.length;
    final g = corners.map((c) => c.g.toInt()).reduce((a, b) => a + b) ~/ corners.length;
    final b = corners.map((c) => c.b.toInt()).reduce((a, b) => a + b) ~/ corners.length;
    return img.ColorRgba8(r, g, b, 255);
  }

  /// BFS flood-fill replacing pixels similar to [target] with [replacement].
  void _floodFill(img.Image image, int startX, int startY, img.Color target,
      img.Color replacement, int tolerance) {
    final queue = <(int, int)>[(startX, startY)];
    final visited = <int>{};
    final w = image.width;
    final h = image.height;

    while (queue.isNotEmpty) {
      final (x, y) = queue.removeLast();
      final key = y * w + x;
      if (x < 0 || x >= w || y < 0 || y >= h) continue;
      if (visited.contains(key)) continue;
      visited.add(key);

      final pixel = image.getPixel(x, y);
      if (!_colorSimilar(pixel, target, tolerance)) continue;

      image.setPixel(x, y, replacement);
      queue.add((x - 1, y));
      queue.add((x + 1, y));
      queue.add((x, y - 1));
      queue.add((x, y + 1));
    }
  }

  bool _colorSimilar(img.Color a, img.Color b, int tolerance) {
    return (a.r - b.r).abs() <= tolerance &&
        (a.g - b.g).abs() <= tolerance &&
        (a.b - b.b).abs() <= tolerance;
  }
}

