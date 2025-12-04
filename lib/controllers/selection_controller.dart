import 'package:flutter/material.dart';

class SelectionController extends ChangeNotifier {
  int? _selectedTopicId;
  String _title = '';
  int _commentCount = 0;
  String _postedAt = '';

  // 現在選ばれているトピックID
  int? get selectedTopicId => _selectedTopicId;
  String get title => _title;
  int get commentCount => _commentCount;
  String get postedAt => _postedAt;

  // トピックを選択する
  void selectTopic(int id, {String title = '', int comments = 0, String postedAt = ''}) {
    print('🔍 [SelectionController] selectTopic called: id=$id, title="$title", comments=$comments, postedAt="$postedAt"');
    bool shouldNotify = false;

    // IDが変わった場合
    if (_selectedTopicId != id) {
      _selectedTopicId = id;
      shouldNotify = true;
    }

    // ★ ここが修正点: IDが同じでも、タイトル等の情報が増えていれば更新する
    if (title.isNotEmpty && _title != title) {
      _title = title;
      shouldNotify = true;
    }
    if (comments > 0 && _commentCount != comments) {
      _commentCount = comments;
      shouldNotify = true;
    }
    if (postedAt.isNotEmpty && _postedAt != postedAt) {
      _postedAt = postedAt;
      shouldNotify = true;
    }

    if (shouldNotify) {
      print('✅ [SelectionController] Updated: _title="$_title", _commentCount=$_commentCount, _postedAt="$_postedAt"');
      notifyListeners(); // 変更があった場合のみ画面更新
    }
  }

  // 選択を解除する（必要であれば）
  void clearSelection() {
    if (_selectedTopicId != null) {
      _selectedTopicId = null;
      _title = ''; // クリア時は情報もリセット
      _commentCount = 0;
      _postedAt = '';
      notifyListeners();
    }
  }
}
