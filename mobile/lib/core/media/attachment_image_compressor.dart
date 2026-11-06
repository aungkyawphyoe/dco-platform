import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'media_api.dart';

/// Native decoding handles orientation and platform formats (including HEIC).
/// JPEG encoding and progressive resizing run in a worker isolate.
class AttachmentImageCompressor {
  const AttachmentImageCompressor();
  static const targetBytes = 500 * 1024;

  Future<File> compress(File source, Directory destination) async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(source.path);
    final codec = await ui.instantiateImageCodecWithSize(
      buffer,
      getTargetSize: (width, height) => width >= height
          ? ui.TargetImageSize(width: math.min(width, 2400))
          : ui.TargetImageSize(height: math.min(height, 2400)),
    );
    late Uint8List encoded;
    try {
      final frame = await codec.getNextFrame();
      try {
        final pixels = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        if (pixels == null) throw const FormatException('Cannot decode image');
        encoded = await compute(_encodeAttachment, (
          pixels: pixels.buffer.asUint8List(
            pixels.offsetInBytes,
            pixels.lengthInBytes,
          ),
          width: frame.image.width,
          height: frame.image.height,
        ));
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
    if (encoded.length > MediaApi.maxBytes) {
      throw const FormatException('Image exceeds the 15 MB limit');
    }
    await destination.create(recursive: true);
    final output = File('${destination.path}/${const Uuid().v4()}.jpg');
    try {
      return await output.writeAsBytes(encoded, flush: true);
    } catch (_) {
      if (await output.exists()) await output.delete();
      rethrow;
    }
  }
}

typedef _Pixels = ({Uint8List pixels, int width, int height});
Uint8List _encodeAttachment(_Pixels data) {
  final rgba = img.Image.fromBytes(
    width: data.width,
    height: data.height,
    bytes: data.pixels.buffer,
    bytesOffset: data.pixels.offsetInBytes,
    numChannels: 4,
  );
  final original = img.Image(width: data.width, height: data.height);
  img.fill(original, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(original, rgba);
  Uint8List? smallest;
  var previousEdge = 0;
  for (final edge in [2400, 2000, 1600]) {
    final target = math.min(edge, math.max(original.width, original.height));
    if (target == previousEdge) continue;
    previousEdge = target;
    final resized = target == math.max(original.width, original.height)
        ? original
        : img.copyResize(
            original,
            width: original.width >= original.height ? target : null,
            height: original.height > original.width ? target : null,
            interpolation: img.Interpolation.average,
          );
    for (final quality in [85, 80, 75]) {
      final bytes = img.encodeJpg(resized, quality: quality);
      if (smallest == null || bytes.length < smallest.length) smallest = bytes;
      if (bytes.length <= AttachmentImageCompressor.targetBytes) return bytes;
    }
  }
  // The byte target is soft: never sacrifice the approved readability floor.
  return smallest!;
}

final attachmentImagePickerProvider = Provider<AttachmentImagePicker>(
  (ref) => AttachmentImagePicker(),
);

class AttachmentImagePicker {
  Future<File?> pick(ImageSource source, {required String folder}) async {
    // Decode/encode once in our compressor, not once here and again afterward.
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return null;
    final root = await getApplicationDocumentsDirectory();
    return const AttachmentImageCompressor().compress(
      File(picked.path),
      Directory('${root.path}/$folder'),
    );
  }
}
