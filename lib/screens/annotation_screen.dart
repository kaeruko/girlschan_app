import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../database/database.dart';
import '../models/annotation.dart';
import '../services/annotation_service.dart';
import '../widgets/annotation_comment_card.dart';
import 'annotation_topic_picker_screen.dart';

class AnnotationScreen extends StatefulWidget {
  const AnnotationScreen({super.key, this.service});

  final AnnotationService? service;

  @override
  State<AnnotationScreen> createState() => _AnnotationScreenState();
}

class _AnnotationScreenState extends State<AnnotationScreen> {
  late final AnnotationService _service;
  List<AnnotationProject> _projects = const [];
  AnnotationProject? _project;
  List<AnnotationTopicProgress> _topicProgress = const [];
  List<AnnotationItem> _items = const [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AnnotationService();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final projects = await _service.listProjects();
      if (!mounted) {
        return;
      }
      setState(() => _projects = projects);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectProject(AnnotationProject project) async {
    setState(() {
      _project = project;
      _isLoading = true;
      _error = null;
      _notice = null;
    });
    try {
      await _reloadSession(resumeAtFirstUnanswered: true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _reloadSession({required bool resumeAtFirstUnanswered}) async {
    final project = _project;
    if (project == null) {
      return;
    }
    final results = await Future.wait<Object>([
      _service.getTopicProgress(project.id),
      _service.getActiveItems(project.id),
    ]);
    final progress = results[0] as List<AnnotationTopicProgress>;
    final items = results[1] as List<AnnotationItem>;
    final resumeIndex = _service.findResumeIndex(items);
    if (!mounted) {
      return;
    }
    setState(() {
      _topicProgress = progress;
      _items = items;
      if (resumeAtFirstUnanswered) {
        _currentIndex = resumeIndex < 0 ? items.length : resumeIndex;
      } else {
        _currentIndex = _currentIndex.clamp(0, items.length);
      }
    });
  }

  Future<void> _createProject() async {
    final controller = TextEditingController();
    final name = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('プロジェクトを作成'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            autofocus: true,
            placeholder: 'プロジェクト名',
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('キャンセル'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('作成'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final project = await _service.createProject(name);
      final projects = await _service.listProjects();
      if (!mounted) {
        return;
      }
      setState(() => _projects = projects);
      await _selectProject(project);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openTopicPicker() async {
    final project = _project;
    if (project == null) {
      return;
    }
    await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => AnnotationTopicPickerScreen(
          projectId: project.id,
          service: _service,
        ),
      ),
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _reloadSession(resumeAtFirstUnanswered: true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveLabel(AnnotationLabel label) async {
    if (_isSaving || _currentIndex < 0 || _currentIndex >= _items.length) {
      return;
    }
    final item = _items[_currentIndex];
    final savedIndex = _currentIndex;
    setState(() {
      _isSaving = true;
      _error = null;
      _notice = null;
    });
    try {
      await _service.saveLabel(
        projectId: item.projectId,
        topicId: item.topicId,
        commentNo: item.commentNo,
        label: label,
      );
      final project = _project!;
      final results = await Future.wait<Object>([
        _service.getTopicProgress(project.id),
        _service.getActiveItems(project.id),
      ]);
      final progress = results[0] as List<AnnotationTopicProgress>;
      final items = results[1] as List<AnnotationItem>;
      if (!mounted) {
        return;
      }
      setState(() {
        _topicProgress = progress;
        _items = items;
        _currentIndex = (savedIndex + 1).clamp(0, items.length);
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _goBack() {
    if (_isSaving || _items.isEmpty || _currentIndex <= 0) {
      return;
    }
    setState(() {
      _currentIndex = (_currentIndex - 1).clamp(0, _items.length - 1);
      _error = null;
      _notice = null;
    });
  }

  Future<void> _deactivateTopic(AnnotationTopicProgress topic) async {
    final shouldRemove = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('対象から外しますか？'),
        content: Text(
          '${topic.title}\n'
          'アノテーション済みデータは保持されます。',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('対象から外す'),
          ),
        ],
      ),
    );
    if (!(shouldRemove ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _service.deactivateTopic(_project!.id, topic.topicId);
      await _reloadSession(resumeAtFirstUnanswered: true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _export() async {
    final project = _project;
    if (project == null) {
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
      _notice = null;
    });
    try {
      final saved = await _service.exportJsonl(project.id);
      if (mounted) {
        setState(() {
          _notice = saved ? 'JSONLを保存しました。' : '保存をキャンセルしました。';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('コメントアノテーション'),
        trailing: _project == null
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _isLoading ? null : _createProject,
                child: const Icon(CupertinoIcons.add),
              )
            : null,
      ),
      child: SafeArea(
        child: _project == null
            ? _buildProjectList()
            : _buildAnnotationWorkspace(),
      ),
    );
  }

  Widget _buildProjectList() {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    return Column(
      children: [
        if (_error != null) _MessageBanner(message: _error!, isError: true),
        Expanded(
          child: _projects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('アノテーションプロジェクトはありません。'),
                      const SizedBox(height: 12),
                      CupertinoButton.filled(
                        onPressed: _createProject,
                        child: const Text('最初のプロジェクトを作成'),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _projects.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final project = _projects[index];
                    return CupertinoButton(
                      color: CupertinoColors.secondarySystemBackground
                          .resolveFrom(context),
                      padding: const EdgeInsets.all(16),
                      onPressed: () => _selectProject(project),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.folder),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  project.name,
                                  style: const TextStyle(
                                    color: CupertinoColors.label,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  project.createdAt.toLocal().toString(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: CupertinoColors.secondaryLabel,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(CupertinoIcons.chevron_forward),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAnnotationWorkspace() {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.digit1): () =>
            _saveLabel(AnnotationLabel.experience),
        const SingleActivator(LogicalKeyboardKey.numpad1): () =>
            _saveLabel(AnnotationLabel.experience),
        const SingleActivator(LogicalKeyboardKey.digit2): () =>
            _saveLabel(AnnotationLabel.notExperience),
        const SingleActivator(LogicalKeyboardKey.numpad2): () =>
            _saveLabel(AnnotationLabel.notExperience),
        const SingleActivator(LogicalKeyboardKey.keyS): () =>
            _saveLabel(AnnotationLabel.skipped),
        const SingleActivator(LogicalKeyboardKey.backspace): _goBack,
      },
      child: Focus(
        autofocus: true,
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProjectHeader(),
                    if (_error != null)
                      _MessageBanner(message: _error!, isError: true),
                    if (_notice != null)
                      _MessageBanner(message: _notice!, isError: false),
                    _buildProgressSummary(),
                    const SizedBox(height: 16),
                    _buildTopicList(),
                    const SizedBox(height: 16),
                    _buildCurrentComment(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildProjectHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            _project!.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            onPressed: () {
              setState(() {
                _project = null;
                _items = const [];
                _topicProgress = const [];
                _error = null;
                _notice = null;
              });
              _loadProjects();
            },
            child: const Text('プロジェクトを切り替え'),
          ),
          CupertinoButton(
            color: CupertinoColors.activeBlue,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            onPressed: _openTopicPicker,
            child: const Text('対象トピックを追加'),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            onPressed: _export,
            child: const Text('JSONLを出力'),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSummary() {
    final annotated = _items.where((item) => item.label != null).length;
    final total = _items.length;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '全体の進捗  $annotated / $total',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _ProgressBar(value: total == 0 ? 0 : annotated / total),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '選択済みトピック',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (_topicProgress.isEmpty)
          const Text(
            '対象トピックがありません。「対象トピックを追加」から追加してください。',
            style: TextStyle(color: CupertinoColors.secondaryLabel),
          )
        else
          for (final topic in _topicProgress)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: CupertinoColors.separator.resolveFrom(context),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              topic.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'ID ${topic.topicId} · '
                              '${topic.annotated} / ${topic.total}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.secondaryLabel,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _ProgressBar(
                              value: topic.total == 0
                                  ? 0
                                  : topic.annotated / topic.total,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      CupertinoButton(
                        padding: const EdgeInsets.all(6),
                        onPressed: () => _deactivateTopic(topic),
                        child: const Text('対象から外す'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildCurrentComment() {
    if (_items.isEmpty) {
      return const Center(child: Text('アノテーション対象のコメントがありません。'));
    }
    if (_currentIndex >= _items.length) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: CupertinoColors.systemGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(
                CupertinoIcons.check_mark_circled_solid,
                size: 42,
                color: CupertinoColors.systemGreen,
              ),
              const SizedBox(height: 10),
              const Text(
                'すべてのコメントへの回答が完了しました。',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              CupertinoButton(onPressed: _goBack, child: const Text('一つ前へ戻る')),
            ],
          ),
        ),
      );
    }

    final item = _items[_currentIndex];
    final anchorContexts = _items
        .where(
          (candidate) =>
              candidate.topicId == item.topicId &&
              item.anchorsSnapshot.contains(candidate.commentNo),
        )
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '現在 ${_currentIndex + 1} / ${_items.length}',
          style: const TextStyle(color: CupertinoColors.secondaryLabel),
        ),
        const SizedBox(height: 8),
        AnnotationCommentCard(
          item: item,
          anchorContexts: anchorContexts,
          isSaving: _isSaving,
          canGoBack: _currentIndex > 0,
          onLabel: _saveLabel,
          onBack: _goBack,
        ),
      ],
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? CupertinoColors.systemRed
        : CupertinoColors.systemGreen;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(message, style: TextStyle(color: color)),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 7,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: CupertinoColors.systemGrey5.resolveFrom(context),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: constraints.maxWidth * value.clamp(0, 1),
                  child: const ColoredBox(color: CupertinoColors.activeBlue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
