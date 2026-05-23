import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/novelai_metadata.dart';

/// Parses PNG `tEXt`, `iTXt`, and `zTXt` chunks for AI image metadata
/// (NovelAI, Stable Diffusion / Automatic1111, ComfyUI).
class PngMetadata {
  PngMetadata._();

  static const List<int> _magic = [137, 80, 78, 71, 13, 10, 26, 10];

  static Future<Map<String, String>> readTextChunks(File file) async {
    final raf = await file.open();
    try {
      final header = await raf.read(8);
      if (header.length < 8) return const {};
      for (var i = 0; i < 8; i++) {
        if (header[i] != _magic[i]) return const {};
      }

      final result = <String, String>{};
      while (true) {
        final lenBytes = await raf.read(4);
        if (lenBytes.length < 4) break;
        final length = ByteData.sublistView(lenBytes).getUint32(0);
        final typeBytes = await raf.read(4);
        if (typeBytes.length < 4) break;
        final type = String.fromCharCodes(typeBytes);
        if (type == 'IEND') break;

        final data = await raf.read(length);
        await raf.read(4); // skip CRC

        if (type == 'tEXt') {
          _parseTextChunk(data, result);
        } else if (type == 'iTXt') {
          _parseITextChunk(data, result);
        } else if (type == 'zTXt') {
          _parseZTextChunk(data, result);
        }
      }
      return result;
    } finally {
      await raf.close();
    }
  }

  static NovelAIMetadata? parse(Map<String, String> chunks) {
    if (chunks.isEmpty) return null;

    // Automatic1111: single "parameters" key with multi-line content
    final params = chunks['parameters'];
    if (params != null && params.isNotEmpty) {
      return _parseA1111(params, chunks);
    }

    // NovelAI: separate keys "Software"/"Source"/"Description"/"Comment"
    final software = chunks['Software'] ?? chunks['Source'];
    if (software != null && software.toLowerCase().contains('novelai')) {
      return _parseNovelAI(chunks);
    }

    // ComfyUI: stores JSON in "prompt"/"workflow"
    if (chunks.containsKey('prompt') || chunks.containsKey('workflow')) {
      return NovelAIMetadata(
        software: 'ComfyUI',
        prompt: chunks['prompt'],
        raw: chunks,
      );
    }

    return NovelAIMetadata(raw: chunks);
  }

  static NovelAIMetadata _parseA1111(
    String params,
    Map<String, String> chunks,
  ) {
    // Format:
    //   <prompt>
    //   Negative prompt: <neg>
    //   Steps: 28, Sampler: Euler a, CFG scale: 7, Seed: 12345, Size: 512x768, ...
    String? prompt;
    String? negativePrompt;
    final tail = <String, String>{};
    final negIdx = params.indexOf('Negative prompt:');
    String rest;
    if (negIdx >= 0) {
      prompt = params.substring(0, negIdx).trim();
      rest = params.substring(negIdx + 'Negative prompt:'.length);
      final firstLineBreak = rest.indexOf('\n');
      if (firstLineBreak >= 0) {
        negativePrompt = rest.substring(0, firstLineBreak).trim();
        rest = rest.substring(firstLineBreak + 1);
      } else {
        negativePrompt = rest.trim();
        rest = '';
      }
    } else {
      final newline = params.indexOf('\n');
      prompt = (newline >= 0 ? params.substring(0, newline) : params).trim();
      rest = newline >= 0 ? params.substring(newline + 1) : '';
    }
    for (final part in rest.split(',')) {
      final idx = part.indexOf(':');
      if (idx < 0) continue;
      tail[part.substring(0, idx).trim()] = part.substring(idx + 1).trim();
    }
    return NovelAIMetadata(
      software: 'Stable Diffusion (Automatic1111)',
      prompt: prompt,
      negativePrompt: negativePrompt,
      seed: tail['Seed'],
      steps: tail['Steps'],
      cfgScale: tail['CFG scale'],
      sampler: tail['Sampler'],
      model: tail['Model'],
      size: tail['Size'],
      raw: chunks,
    );
  }

  static NovelAIMetadata _parseNovelAI(Map<String, String> chunks) {
    String? prompt = chunks['Description'];
    String? negativePrompt;
    String? seed;
    String? steps;
    String? cfgScale;
    String? sampler;
    String? model;

    final comment = chunks['Comment'];
    if (comment != null) {
      try {
        final json = jsonDecode(comment) as Map<String, dynamic>;
        prompt = (json['prompt'] as String?) ?? prompt;
        negativePrompt = json['uc'] as String?;
        seed = json['seed']?.toString();
        steps = json['steps']?.toString();
        cfgScale = json['scale']?.toString();
        sampler = json['sampler'] as String?;
        model = json['noise_schedule'] as String?;
      } catch (_) {
        // Malformed JSON — fall back to raw display.
      }
    }
    return NovelAIMetadata(
      software: 'NovelAI',
      prompt: prompt,
      negativePrompt: negativePrompt,
      seed: seed,
      steps: steps,
      cfgScale: cfgScale,
      sampler: sampler,
      model: model,
      raw: chunks,
    );
  }

  static void _parseTextChunk(Uint8List data, Map<String, String> out) {
    final nullIdx = data.indexOf(0);
    if (nullIdx < 0) return;
    final keyword = latin1.decode(data.sublist(0, nullIdx));
    final text = latin1.decode(data.sublist(nullIdx + 1));
    out[keyword] = text;
  }

  static void _parseITextChunk(Uint8List data, Map<String, String> out) {
    // keyword\0 compressionFlag compressionMethod langTag\0 translatedKey\0 text
    final nullIdx = data.indexOf(0);
    if (nullIdx < 0) return;
    final keyword = latin1.decode(data.sublist(0, nullIdx));
    if (data.length < nullIdx + 3) return;
    final compressed = data[nullIdx + 1] == 1;
    var cursor = nullIdx + 3;
    // skip language tag
    final langEnd = data.indexOf(0, cursor);
    if (langEnd < 0) return;
    cursor = langEnd + 1;
    // skip translated keyword
    final translatedEnd = data.indexOf(0, cursor);
    if (translatedEnd < 0) return;
    cursor = translatedEnd + 1;
    final payload = data.sublist(cursor);
    String text;
    if (compressed) {
      try {
        text = utf8.decode(zlib.decode(payload));
      } catch (_) {
        return;
      }
    } else {
      text = utf8.decode(payload, allowMalformed: true);
    }
    out[keyword] = text;
  }

  static void _parseZTextChunk(Uint8List data, Map<String, String> out) {
    final nullIdx = data.indexOf(0);
    if (nullIdx < 0 || data.length < nullIdx + 2) return;
    final keyword = latin1.decode(data.sublist(0, nullIdx));
    final payload = data.sublist(nullIdx + 2);
    try {
      final text = latin1.decode(zlib.decode(payload));
      out[keyword] = text;
    } catch (_) {
      // ignore malformed
    }
  }
}
