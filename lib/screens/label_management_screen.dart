import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // For Colors
import '../services/api_service.dart';
import '../widgets/common/app_toast.dart';

class LabelManagementScreen extends StatefulWidget {
  const LabelManagementScreen({super.key});

  @override
  State<LabelManagementScreen> createState() => _LabelManagementScreenState();
}

class _LabelManagementScreenState extends State<LabelManagementScreen> {
  List<Map<String, dynamic>> _labels = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLabels();
  }

  Future<void> _loadLabels() async {
    try {
      final labels = await getClipLabels();
      if (mounted) {
        setState(() {
          _labels = labels.where((l) => l['id'] != 0).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _addLabel() async {
    final controller = TextEditingController();
    await showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('ラベルを追加'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'ラベル名',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context);
                await addClipLabel(name);
                await _loadLabels();
                if (mounted) AppToast.show(context, 'ラベル「$name」を追加しました');
              }
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }

  Future<void> _editLabel(Map<String, dynamic> label) async {
    final id = label['id'] as int;
    if (id == 0) return; // Default label cannot be edited

    final controller = TextEditingController(text: label['name'] as String);
    await showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('ラベル名を変更'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'ラベル名',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _deleteLabel(label);
            },
            child: const Text('このラベルを削除'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context);
                await updateClipLabel(id, name);
                await _loadLabels();
                if (mounted) AppToast.show(context, 'ラベル名を変更しました');
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteLabel(Map<String, dynamic> label) async {
    final id = label['id'] as int;
    final name = label['name'] as String;
    if (id == 0) return;

    await showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('ラベル「$name」を削除'),
        content: const Text('このラベルに含まれるクリップは「未分類」に移動します。よろしいですか？'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              await deleteClipLabel(id);
              await _loadLabels();
              if (mounted) AppToast.show(context, 'ラベルを削除しました');
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('ラベル管理'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _addLabel,
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : ListView.builder(
                itemCount: _labels.length,
                itemBuilder: (context, index) {
                  final label = _labels[index];
                  final id = label['id'] as int;
                  final name = label['name'] as String;
                  final isDefault = id == 0;
                  final displayName = isDefault && name.isEmpty ? '未分類' : name;

                  if (isDefault) {
                    return Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: CupertinoColors.systemGrey5,
                            width: 1.0,
                          ),
                        ),
                      ),
                      child: CupertinoListTile(
                        title: Text(displayName,
                            style: const TextStyle(color: CupertinoColors.systemGrey)),
                        leading: const Icon(CupertinoIcons.folder, color: CupertinoColors.systemGrey),
                        trailing: const Text('編集不可',
                            style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),
                      ),
                    );
                  }

                  return Dismissible(
                    key: Key('label_$id'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: CupertinoColors.destructiveRed,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16.0),
                      child: const Icon(CupertinoIcons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) async {
                      await _deleteLabel(label);
                      return false; // _deleteLabel handles deletion and reload
                    },
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: CupertinoColors.systemGrey5,
                            width: 1.0,
                          ),
                        ),
                      ),
                      child: CupertinoListTile(
                        title: Text(displayName),
                        leading: const Icon(CupertinoIcons.tag),
                        onTap: () => _editLabel(label),
                        trailing: const Icon(CupertinoIcons.forward, size: 16, color: CupertinoColors.systemGrey3),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
