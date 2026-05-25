import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../core/log_service.dart';
import '../models/novel_ai_metadata.dart';

class PngMetadataService {
  static const _sig = [137, 80, 78, 71, 13, 10, 26, 10];

  Future<NovelAiMetadata?> parse(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return parseBytes(bytes);
    } catch (e, st) {
      LogService.instance.warning('PNG parse failed for ${file.path}: $e', st);
      return null;
    }
  }

  /// Exposed for unit tests (no file I/O).
  NovelAiMetadata? parseBytes(Uint8List bytes) {
    if (bytes.length < 8) return null;
    for (int i = 0; i < 8; i++) {
      if (bytes[i] != _sig[i]) return null;
    }

    final chunks = <String, String>{};
    int offset = 8;

    while (offset + 12 <= bytes.length) {
      final length = _u32(bytes, offset);
      if (length > 100 * 1024 * 1024) break; // reject absurd chunk sizes (>100MB)
      final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
      final dataEnd = offset + 8 + length;
      if (dataEnd + 4 > bytes.length) break;

      if (type == 'tEXt') {
        _parseTExt(bytes.sublist(offset + 8, dataEnd), chunks);
      } else if (type == 'iTXt') {
        _parseITxt(bytes.sublist(offset + 8, dataEnd), chunks);
      }

      offset = dataEnd + 4; // skip 4-byte CRC
    }

    return _build(chunks);
  }

  void _parseTExt(Uint8List data, Map<String, String> out) {
    final nullIdx = data.indexOf(0);
    if (nullIdx <= 0) return;
    final key = utf8.decode(data.sublist(0, nullIdx), allowMalformed: true);
    final value = latin1.decode(data.sublist(nullIdx + 1), allowInvalid: true);
    out[key] = value;
  }

  void _parseITxt(Uint8List data, Map<String, String> out) {
    try {
      int pos = 0;
      final nullIdx = data.indexOf(0, pos);
      if (nullIdx < 0) return;
      final key = utf8.decode(data.sublist(pos, nullIdx), allowMalformed: true);
      pos = nullIdx + 1;
      if (pos >= data.length) return;
      final compressionFlag = data[pos++];
      pos++; // compression method
      final langEnd = data.indexOf(0, pos);
      if (langEnd < 0) return;
      pos = langEnd + 1;
      final transEnd = data.indexOf(0, pos);
      if (transEnd < 0) return;
      pos = transEnd + 1;
      if (pos >= data.length) return;

      final raw = data.sublist(pos);
      final value = compressionFlag == 1
          ? utf8.decode(zlib.decode(raw), allowMalformed: true)
          : utf8.decode(raw, allowMalformed: true);
      out[key] = value;
    } catch (_) {}
  }

  NovelAiMetadata? _build(Map<String, String> chunks) {
    String? prompt;
    String? negativePrompt;
    int? steps;
    String? sampler;
    int? seed;
    double? cfgScale;
    String? imageSize;

    prompt = chunks['parameters'] ?? chunks['Description'];

    if (chunks.containsKey('Comment')) {
      try {
        final json = jsonDecode(chunks['Comment']!) as Map<String, dynamic>;
        prompt ??= json['prompt'] as String?;
        negativePrompt = json['uc'] as String?;
        steps = json['steps'] as int?;
        sampler = json['sampler'] as String?;
        seed = (json['seed'] as num?)?.toInt();
        cfgScale = (json['scale'] as num?)?.toDouble();
        imageSize = json['image_size'] as String?;
      } catch (_) {}
    }

    if (prompt == null) return null;

    return NovelAiMetadata(
      prompt: prompt,
      negativePrompt: negativePrompt,
      steps: steps,
      sampler: sampler,
      seed: seed,
      cfgScale: cfgScale,
      imageSize: imageSize,
    );
  }

  int _u32(Uint8List b, int o) =>
      (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
}
