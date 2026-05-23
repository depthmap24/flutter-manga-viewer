/// Parsed NovelAI / Stable-Diffusion generation parameters from PNG metadata.
class NovelAIMetadata {
  NovelAIMetadata({
    this.software,
    this.prompt,
    this.negativePrompt,
    this.seed,
    this.steps,
    this.cfgScale,
    this.sampler,
    this.model,
    this.size,
    this.raw,
  });

  /// "NovelAI", "Stable Diffusion web UI", etc.
  final String? software;
  final String? prompt;
  final String? negativePrompt;
  final String? seed;
  final String? steps;
  final String? cfgScale;
  final String? sampler;
  final String? model;
  final String? size;

  /// Original key/value pairs from the file.
  final Map<String, String>? raw;

  bool get hasContent =>
      prompt != null ||
      negativePrompt != null ||
      seed != null ||
      (raw != null && raw!.isNotEmpty);
}
