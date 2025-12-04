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
    if (_selectedTopicId != id) {
      _selectedTopicId = id;
      _title = title;
      _commentCount = comments;
      _postedAt = postedAt;
      notifyListeners(); // 画面を更新！
    }
  }

  // 選択を解除する（必要であれば）
  void clearSelection() {
    if (_selectedTopicId != null) {
      _selectedTopicId = null;
      notifyListeners();
    }
  }
}
