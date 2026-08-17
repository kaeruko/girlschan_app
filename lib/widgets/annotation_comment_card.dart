import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;

import '../database/database.dart';
import '../models/annotation.dart';

class AnnotationCommentCard extends StatelessWidget {
  const AnnotationCommentCard({
    super.key,
    required this.item,
    required this.anchorContexts,
    required this.isSaving,
    required this.canGoBack,
    required this.onLabel,
    required this.onBack,
  });

  final AnnotationItem item;
  final List<AnnotationItem> anchorContexts;
  final bool isSaving;
  final bool canGoBack;
  final ValueChanged<AnnotationLabel> onLabel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final rawLabel = item.label;
    final label = rawLabel == null ? null : AnnotationLabel.parse(rawLabel);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  item.topicTitleSnapshot,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'No.${item.commentNo}',
                  style: const TextStyle(color: CupertinoColors.secondaryLabel),
                ),
                _LabelBadge(label: label),
              ],
            ),
            const SizedBox(height: 16),
            SelectableText(
              item.bodySnapshot,
              style: const TextStyle(fontSize: 17, height: 1.55),
            ),
            if (item.nameSnapshot != null || item.postedAtSnapshot != null) ...[
              const SizedBox(height: 12),
              Text(
                [
                  if (item.nameSnapshot != null) item.nameSnapshot!,
                  if (item.postedAtSnapshot != null) item.postedAtSnapshot!,
                ].join(' · '),
                style: const TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
            const SizedBox(height: 18),
            _AnchorContext(
              anchorNumbers: item.anchorsSnapshot,
              contexts: anchorContexts,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                CupertinoButton(
                  color: CupertinoColors.activeGreen,
                  onPressed: isSaving
                      ? null
                      : () => onLabel(AnnotationLabel.experience),
                  child: const Text('1  体験談'),
                ),
                CupertinoButton(
                  color: CupertinoColors.systemRed,
                  onPressed: isSaving
                      ? null
                      : () => onLabel(AnnotationLabel.notExperience),
                  child: const Text('2  体験談じゃない'),
                ),
                CupertinoButton(
                  color: CupertinoColors.systemGrey,
                  onPressed: isSaving
                      ? null
                      : () => onLabel(AnnotationLabel.skipped),
                  child: const Text('S  保留'),
                ),
                CupertinoButton(
                  onPressed: !isSaving && canGoBack ? onBack : null,
                  child: const Text('Backspace  一つ前へ'),
                ),
              ],
            ),
            if (isSaving) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  CupertinoActivityIndicator(),
                  SizedBox(width: 8),
                  Text('保存中…'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LabelBadge extends StatelessWidget {
  const _LabelBadge({required this.label});

  final AnnotationLabel? label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5.resolveFrom(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label?.displayName ?? '未回答',
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }
}

class _AnchorContext extends StatelessWidget {
  const _AnchorContext({required this.anchorNumbers, required this.contexts});

  final List<int> anchorNumbers;
  final List<AnnotationItem> contexts;

  @override
  Widget build(BuildContext context) {
    if (anchorNumbers.isEmpty) {
      return const Text(
        'アンカー先: なし',
        style: TextStyle(color: CupertinoColors.secondaryLabel),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'アンカー先コメントの文脈',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        for (final number in anchorNumbers)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Builder(
                  builder: (_) {
                    final matches = contexts.where(
                      (item) => item.commentNo == number,
                    );
                    if (matches.isEmpty) {
                      return Text('No.$number（スナップショット内にありません）');
                    }
                    final item = matches.single;
                    return Text('No.$number  ${item.bodySnapshot}');
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
