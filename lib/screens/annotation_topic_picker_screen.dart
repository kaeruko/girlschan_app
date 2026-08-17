import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider;

import '../models/annotation.dart';
import '../services/annotation_service.dart';

class AnnotationTopicPickerScreen extends StatefulWidget {
  const AnnotationTopicPickerScreen({
    super.key,
    required this.projectId,
    required this.service,
  });

  final int projectId;
  final AnnotationService service;

  @override
  State<AnnotationTopicPickerScreen> createState() =>
      _AnnotationTopicPickerScreenState();
}

class _AnnotationTopicPickerScreenState
    extends State<AnnotationTopicPickerScreen> {
  final _searchController = TextEditingController();
  final _directController = TextEditingController();
  List<AnnotationTopicCandidate> _results = const [];
  final Set<int> _selectedIds = {};
  bool _isSearching = false;
  bool _isAdding = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    _directController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _isSearching = true;
      _error = null;
    });
    try {
      final results = await widget.service.searchTopicCandidates(
        _searchController.text,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _results = results;
        _selectedIds.clear();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _addSelected() async {
    final selected = _results
        .where((topic) => _selectedIds.contains(topic.topicId))
        .toList(growable: false);
    await _runAdd(() => widget.service.addTopics(widget.projectId, selected));
  }

  Future<void> _addDirect() async {
    await _runAdd(
      () => widget.service.addTopicFromInput(
        widget.projectId,
        _directController.text,
      ),
    );
  }

  Future<void> _runAdd(Future<void> Function() operation) async {
    setState(() {
      _isAdding = true;
      _error = null;
    });
    try {
      await operation();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _isSearching || _isAdding;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('対象トピックを追加')),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'キーワード検索',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoSearchTextField(
                          controller: _searchController,
                          placeholder: '任意の検索キーワード',
                          onSubmitted: busy ? null : (_) => _search(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CupertinoButton.filled(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        onPressed: busy ? null : _search,
                        child: const Text('検索'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'IDまたはURLから直接追加',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoTextField(
                          controller: _directController,
                          placeholder:
                              '123456 または '
                              'https://girlschannel.net/topics/123456/',
                          onSubmitted: busy ? null : (_) => _addDirect(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CupertinoButton(
                        color: CupertinoColors.activeBlue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        onPressed: busy ? null : _addDirect,
                        child: const Text('直接追加'),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: CupertinoColors.systemRed),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isSearching
                  ? const Center(child: CupertinoActivityIndicator())
                  : _results.isEmpty
                  ? const Center(child: Text('検索結果はまだありません'))
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final topic = _results[index];
                        final selected = _selectedIds.contains(topic.topicId);
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: busy
                              ? null
                              : () {
                                  setState(() {
                                    if (selected) {
                                      _selectedIds.remove(topic.topicId);
                                    } else {
                                      _selectedIds.add(topic.topicId);
                                    }
                                  });
                                },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                CupertinoCheckbox(
                                  value: selected,
                                  onChanged: busy
                                      ? null
                                      : (value) {
                                          setState(() {
                                            if (value ?? false) {
                                              _selectedIds.add(topic.topicId);
                                            } else {
                                              _selectedIds.remove(
                                                topic.topicId,
                                              );
                                            }
                                          });
                                        },
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        topic.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'ID ${topic.topicId} · '
                                        '${topic.totalComments}コメント',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: CupertinoColors.secondaryLabel,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: Text('${_selectedIds.length}件を選択中')),
                  CupertinoButton.filled(
                    onPressed: busy || _selectedIds.isEmpty
                        ? null
                        : _addSelected,
                    child: _isAdding
                        ? const CupertinoActivityIndicator(
                            color: CupertinoColors.white,
                          )
                        : const Text('選択したトピックを追加'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
