import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imageviewer/services/png_metadata_service.dart';

/// Builds a minimal valid PNG byte sequence with tEXt chunks.
/// Our parser does not verify CRC, so we use zero CRCs for simplicity.
Uint8List buildTestPng(Map<String, String> textChunks) {
  final buf = BytesBuilder();
  buf.add([137, 80, 78, 71, 13, 10, 26, 10]);
  final ihdr = Uint8List(13)
    ..[3] = 1
    ..[7] = 1
    ..[8] = 8
    ..[9] = 2;
  buf.add(_makeChunk('IHDR', ihdr));
  for (final e in textChunks.entries) {
    final data = Uint8List.fromList([
      ...utf8.encode(e.key),
      0,
      ...latin1.encode(e.value),
    ]);
    buf.add(_makeChunk('tEXt', data));
  }
  buf.add(_makeChunk('IEND', Uint8List(0)));
  return buf.toBytes();
}

Uint8List _makeChunk(String type, Uint8List data) {
  final b = BytesBuilder();
  b.addByte((data.length >> 24) & 0xFF);
  b.addByte((data.length >> 16) & 0xFF);
  b.addByte((data.length >> 8) & 0xFF);
  b.addByte(data.length & 0xFF);
  b.add(utf8.encode(type));
  b.add(data);
  b.add([0, 0, 0, 0]); // fake CRC
  return b.toBytes();
}

void main() {
  final svc = PngMetadataService();

  group('PngMetadataService', () {
    test('returns null for non-PNG bytes', () {
      final bytes = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7]);
      expect(svc.parseBytes(bytes), isNull);
    });

    test('returns null for PNG with no NovelAI chunks', () {
      final bytes = buildTestPng({'Software': 'GIMP'});
      expect(svc.parseBytes(bytes), isNull);
    });

    test('parses prompt from "parameters" tEXt chunk', () {
      final bytes = buildTestPng({'parameters': 'a cat, masterpiece'});
      final meta = svc.parseBytes(bytes);
      expect(meta, isNotNull);
      expect(meta!.prompt, 'a cat, masterpiece');
    });

    test('parses prompt from "Description" tEXt chunk', () {
      final bytes = buildTestPng({'Description': 'a dog'});
      final meta = svc.parseBytes(bytes);
      expect(meta!.prompt, 'a dog');
    });

    test('parses negativePrompt, steps, sampler, seed from "Comment" JSON', () {
      final comment = jsonEncode({
        'prompt': 'a fox',
        'uc': 'blurry, bad',
        'steps': 28,
        'sampler': 'k_euler',
        'seed': 12345,
        'scale': 7.0,
        'image_size': '512x768',
      });
      final bytes = buildTestPng({'Comment': comment});
      final meta = svc.parseBytes(bytes);
      expect(meta!.prompt, 'a fox');
      expect(meta.negativePrompt, 'blurry, bad');
      expect(meta.steps, 28);
      expect(meta.sampler, 'k_euler');
      expect(meta.seed, 12345);
      expect(meta.cfgScale, 7.0);
      expect(meta.imageSize, '512x768');
    });

    test('"parameters" key takes priority over "Description"', () {
      final bytes = buildTestPng({
        'parameters': 'primary prompt',
        'Description': 'secondary',
      });
      final meta = svc.parseBytes(bytes);
      expect(meta!.prompt, 'primary prompt');
    });
  });
}
