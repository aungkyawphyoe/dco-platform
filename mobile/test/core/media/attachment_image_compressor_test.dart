import 'dart:io';
import 'dart:math';
import 'package:dco_mobile/core/media/attachment_image_compressor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(
    () async =>
        directory = await Directory.systemTemp.createTemp('attachment-test'),
  );
  tearDown(() async => directory.delete(recursive: true));
  Future<File> source(img.Image image, {bool jpeg = false}) async =>
      File('${directory.path}/original.${jpeg ? 'jpg' : 'png'}').writeAsBytes(
        jpeg ? img.encodeJpg(image, quality: 100) : img.encodePng(image),
      );

  test(
    'large document becomes a real JPEG under target, within 2400 pixels',
    () async {
      final image = img.Image(width: 3200, height: 2000);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      img.drawString(
        image,
        'Receipt: Oil service 8000 MMK',
        font: img.arial48,
        x: 100,
        y: 100,
        color: img.ColorRgb8(0, 0, 0),
      );
      final original = await source(image);
      final originalBytes = await original.readAsBytes();
      final output = await const AttachmentImageCompressor().compress(
        original,
        directory,
      );
      final bytes = await output.readAsBytes();
      expect(output.path, endsWith('.jpg'));
      expect(output.path, isNot(original.path));
      expect(bytes.take(2), [0xff, 0xd8]);
      expect(bytes.length, lessThanOrEqualTo(500 * 1024));
      final decoded = img.decodeJpg(bytes)!;
      expect(decoded.width, 2400);
      expect(decoded.height, 1500);
      expect(await original.readAsBytes(), originalBytes);
    },
  );

  test(
    'small transparent PNG stays small and transparent pixels become white',
    () async {
      final input = img.Image(width: 100, height: 50, numChannels: 4);
      img.fill(input, color: img.ColorRgba8(0, 0, 0, 0));
      input.setPixelRgba(50, 25, 0, 0, 0, 255);
      final output = await const AttachmentImageCompressor().compress(
        await source(input),
        directory,
      );
      final decoded = img.decodeJpg(await output.readAsBytes())!;
      expect((decoded.width, decoded.height), (100, 50));
      expect(decoded.getPixel(0, 0).r, greaterThan(245));
      expect(decoded.getPixel(0, 0).g, greaterThan(245));
      expect(decoded.getPixel(0, 0).b, greaterThan(245));
    },
  );

  test('EXIF rotated JPEG is upright after conversion', () async {
    final input = img.Image(width: 80, height: 40);
    img.fill(input, color: img.ColorRgb8(220, 20, 10));
    input.exif.imageIfd.orientation = 6;
    final output = await const AttachmentImageCompressor().compress(
      await source(input, jpeg: true),
      directory,
    );
    final decoded = img.decodeJpg(await output.readAsBytes())!;
    expect((decoded.width, decoded.height), (40, 80));
    expect(decoded.exif.imageIfd.orientation, anyOf(isNull, 1));
  });

  test(
    'noisy image may exceed target rather than shrink below readability floor',
    () async {
      final input = img.Image(width: 1700, height: 1700);
      final random = Random(42);
      for (final pixel in input) {
        pixel.setRgb(
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(256),
        );
      }
      final output = await const AttachmentImageCompressor().compress(
        await source(input),
        directory,
      );
      final bytes = await output.readAsBytes();
      final decoded = img.decodeJpg(bytes)!;
      expect(decoded.width, greaterThanOrEqualTo(1600));
      expect(decoded.height, greaterThanOrEqualTo(1600));
      expect(bytes.length, greaterThan(500 * 1024));
      expect(bytes.length, lessThanOrEqualTo(15 * 1024 * 1024));
    },
  );

  test(
    'corrupt input fails without changing source or leaving output',
    () async {
      final original = await File(
        '${directory.path}/broken.jpg',
      ).writeAsString('not an image');
      await expectLater(
        const AttachmentImageCompressor().compress(original, directory),
        throwsA(anything),
      );
      expect(await original.readAsString(), 'not an image');
      expect(await directory.list().length, 1);
    },
  );
}
