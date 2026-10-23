import 'dart:io';

import 'package:fitpic/services/image_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('garment preparation keeps the original path and bytes', () async {
    final original = File('assets/ropa/camisa.png');
    final bytes = await original.readAsBytes();
    final path = await ImageService().prepareGarmentImage(original.path);
    expect(path, original.path);
    expect(await original.readAsBytes(), bytes);
  });

  test('API copy preserves the entire frame and aspect ratio', () {
    final source = img.Image(width: 800, height: 1600);
    img.fill(source, color: img.ColorRgb8(20, 40, 80));
    img.fillRect(source,
        x1: 0, y1: 0, x2: 799, y2: 80, color: img.ColorRgb8(220, 0, 0));
    img.fillRect(source,
        x1: 0, y1: 1520, x2: 799, y2: 1599, color: img.ColorRgb8(0, 220, 0));
    final result = img.decodeJpg(encodeVisionPhoto(img.encodePng(source)))!;
    expect(result.width, 512);
    expect(result.height, 1024);
    expect(result.getPixel(200, 10).r, greaterThan(200));
    expect(result.getPixel(200, 1010).g, greaterThan(200));
  });

  test('small photos are not enlarged or cropped for the API', () {
    final source = img.Image(width: 90, height: 130);
    final result = img.decodeJpg(encodeVisionPhoto(img.encodePng(source)))!;
    expect(result.width, 90);
    expect(result.height, 130);
  });

  test('transparent pixels get white backing only in the API copy', () {
    final source = img.Image(width: 100, height: 100, numChannels: 4);
    img.fillRect(source,
        x1: 30, y1: 10, x2: 70, y2: 90, color: img.ColorRgba8(0, 0, 0, 255));
    final original = img.encodePng(source);
    final result = img.decodeJpg(encodeVisionPhoto(original))!;
    expect(result.getPixel(0, 0).r, greaterThan(245));
    expect(result.getPixel(50, 50).r, lessThan(10));
    expect(img.decodePng(original)!.getPixel(0, 0).a, 0);
  });
}
