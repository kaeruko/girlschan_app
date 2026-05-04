import 'package:flutter/foundation.dart';
import '../utils/log.dart';

/// 右ペインのトピックタブ1枚分のデータ
class TopicTab {
  final int topicId;
  final String title;
  final int commentCount;
  final String postedAt;

  const TopicTab({
    required this.topicId,
    required this.title,
    required this.commentCount,
    required this.postedAt,
  });
}

/// 複数トピックタブの状態を管理するコントローラー
class TabsController extends ChangeNotifier {
  static const int maxTabs = 8;

  final List<TopicTab> _tabs = [];
  int _activeIndex = -1;

  List<TopicTab> get tabs => List.unmodifiable(_tabs);
  int get activeIndex => _activeIndex;
  TopicTab? get activeTab => _activeIndex >= 0 && _activeIndex < _tabs.length
      ? _tabs[_activeIndex]
      : null;

  /// 現在のアクティブタブにトピックを開く。タブがなければ新規作成。
  void openInCurrent(TopicTab tab) {
    if (_tabs.isEmpty) {
      _tabs.add(tab);
      _activeIndex = 0;
    } else {
      _tabs[_activeIndex] = tab;
    }
    notifyListeners();
  }

  /// 新規タブでトピックを開く。上限(maxTabs)に達している場合は何もしない。
  /// 戻り値: 追加できた場合 true
  bool openInNew(TopicTab tab) {
    logd('🗂️ [TabsController] openInNew: topicId=${tab.topicId}, currentTabCount=${_tabs.length}', name: 'Tabs');
    if (_tabs.length >= maxTabs) {
      logd('⚠️ [TabsController] openInNew: maxTabs reached, ignoring', name: 'Tabs');
      return false;
    }
    _tabs.add(tab);
    _activeIndex = _tabs.length - 1;
    logd('✅ [TabsController] openInNew: added, activeIndex=$_activeIndex, totalTabs=${_tabs.length}', name: 'Tabs');
    notifyListeners();
    return true;
  }

  /// タブを閉じる
  void closeTab(int index) {
    if (index < 0 || index >= _tabs.length) return;
    _tabs.removeAt(index);
    if (_tabs.isEmpty) {
      _activeIndex = -1;
    } else {
      _activeIndex = (index - 1).clamp(0, _tabs.length - 1);
    }
    notifyListeners();
  }

  /// アクティブタブを切り替える
  void setActive(int index) {
    logd('🗂️ [TabsController] setActive: index=$index, currentActive=$_activeIndex, totalTabs=${_tabs.length}', name: 'Tabs');
    if (index < 0 || index >= _tabs.length) return;
    if (index == _activeIndex) return;
    _activeIndex = index;
    notifyListeners();
  }
}
