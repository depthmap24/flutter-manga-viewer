import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/image_file.dart';
import '../models/novelai_metadata.dart';
import '../services/exif_service.dart';
import '../services/png_metadata.dart';

class MetadataSheet extends StatefulWidget {
  const MetadataSheet({super.key, required this.image});

  final ImageFile image;

  @override
  State<MetadataSheet> createState() => _MetadataSheetState();
}

class _MetadataSheetState extends State<MetadataSheet> {
  late final Future<_Bundle> _future = _load();

  Future<_Bundle> _load() async {
    final exif = await ExifService.read(File(widget.image.path));
    NovelAIMetadata? ai;
    if (widget.image.isPng) {
      final chunks = await PngMetadata.readTextChunks(File(widget.image.path));
      ai = PngMetadata.parse(chunks);
    }
    return _Bundle(exif, ai);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => Material(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: FutureBuilder<_Bundle>(
          future: _future,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final bundle = snap.data!;
            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(widget.image.name,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                if (bundle.ai != null && bundle.ai!.hasContent) ...[
                  Text('AI generation',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  _AiSection(meta: bundle.ai!),
                  const Divider(height: 32),
                ],
                Text('EXIF', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                if (bundle.exif.isEmpty)
                  Text('No EXIF data found.',
                      style: Theme.of(context).textTheme.bodyMedium)
                else
                  ...bundle.exif.entries.map(
                    (e) => _KeyValueRow(label: e.key, value: e.value),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Bundle {
  _Bundle(this.exif, this.ai);
  final Map<String, String> exif;
  final NovelAIMetadata? ai;
}

class _AiSection extends StatelessWidget {
  const _AiSection({required this.meta});
  final NovelAIMetadata meta;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (meta.software != null)
          _KeyValueRow(label: 'Software', value: meta.software!),
        if (meta.prompt != null) _PromptBlock(label: 'Prompt', text: meta.prompt!),
        if (meta.negativePrompt != null)
          _PromptBlock(label: 'Negative', text: meta.negativePrompt!),
        if (meta.seed != null) _KeyValueRow(label: 'Seed', value: meta.seed!),
        if (meta.steps != null) _KeyValueRow(label: 'Steps', value: meta.steps!),
        if (meta.cfgScale != null)
          _KeyValueRow(label: 'CFG', value: meta.cfgScale!),
        if (meta.sampler != null)
          _KeyValueRow(label: 'Sampler', value: meta.sampler!),
        if (meta.model != null) _KeyValueRow(label: 'Model', value: meta.model!),
        if (meta.size != null) _KeyValueRow(label: 'Size', value: meta.size!),
      ],
    );
  }
}

class _PromptBlock extends StatelessWidget {
  const _PromptBlock({required this.label, required this.text});
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const Spacer(),
              IconButton(
                tooltip: 'Copy',
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$label copied')),
                  );
                },
              ),
            ],
          ),
          SelectableText(text),
        ],
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
