import 'package:flutter/material.dart';

import '../models/image_file.dart';
import '../models/image_metadata.dart';
import '../models/novel_ai_metadata.dart';
import '../services/metadata_service.dart';

class MetadataSheet extends StatefulWidget {
  final ImageFile imageFile;

  const MetadataSheet({super.key, required this.imageFile});

  static Future<void> show(BuildContext context, ImageFile imageFile) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MetadataSheet(imageFile: imageFile),
    );
  }

  @override
  State<MetadataSheet> createState() => _MetadataSheetState();
}

class _MetadataSheetState extends State<MetadataSheet> {
  final _svc = MetadataService();
  ImageMetadata? _meta;
  NovelAiMetadata? _ai;
  bool _loading = true;
  bool _aiExpanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final meta = await _svc.getMetadata(widget.imageFile);
    final ai = await _svc.getNovelAi(widget.imageFile);
    if (mounted) {
      setState(() {
        _meta = meta;
        _ai = ai;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.92,
      minChildSize: 0.3,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(controller),
      ),
    );
  }

  Widget _buildContent(ScrollController controller) {
    final meta = _meta!;
    return ListView(
      controller: controller,
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(widget.imageFile.name,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        const Divider(height: 24),
        _row('Resolution', meta.resolution),
        _row('Color space', meta.colorSpace ?? 'Unknown'),
        _row(
          'Date taken',
          meta.dateTaken != null
              ? '${meta.dateTaken!.toLocal()}'.split('.').first
              : 'Unknown',
        ),
        _row('GPS', meta.gpsString),
        if (_ai != null) ...[
          const Divider(height: 24),
          InkWell(
            onTap: () => setState(() => _aiExpanded = !_aiExpanded),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                    child: Text('AI Generation',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                Icon(_aiExpanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
          if (_aiExpanded) ...[
            const SizedBox(height: 12),
            _aiSection(),
          ],
        ],
      ],
    );
  }

  Widget _aiSection() {
    final ai = _ai!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ai.prompt != null) ...[
          const Text('Prompt', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          SelectableText(ai.prompt!, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
        ],
        if (ai.negativePrompt != null) ...[
          const Text('Negative Prompt',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          SelectableText(ai.negativePrompt!,
              style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (ai.steps != null) _chip('Steps: ${ai.steps}'),
            if (ai.sampler != null) _chip('Sampler: ${ai.sampler}'),
            if (ai.seed != null) _chip('Seed: ${ai.seed}'),
            if (ai.cfgScale != null) _chip('CFG: ${ai.cfgScale}'),
            if (ai.imageSize != null) _chip('Size: ${ai.imageSize}'),
          ],
        ),
      ],
    );
  }

  Widget _chip(String label) => Chip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );
}
