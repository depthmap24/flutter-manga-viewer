class NovelAiMetadata {
  final String? prompt;
  final String? negativePrompt;
  final int? steps;
  final String? sampler;
  final int? seed;
  final double? cfgScale;
  final String? imageSize;

  const NovelAiMetadata({
    this.prompt,
    this.negativePrompt,
    this.steps,
    this.sampler,
    this.seed,
    this.cfgScale,
    this.imageSize,
  });
}
