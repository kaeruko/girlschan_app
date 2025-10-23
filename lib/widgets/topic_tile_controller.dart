import 'dart:collection';

/// タイルが実装すべき最小インターフェース
abstract class TileRefreshable {
  /// 自分のキャッシュ・表示状態を再評価して反映する
  Future<void> refreshCacheState();
}

/// TopicTile 群の更新をまとめて指示する超薄いコントローラ
class TopicTileController {
  // 同一インスタンスの多重登録を避けたいので identity セット
  final Set<TileRefreshable> _subs = LinkedHashSet<TileRefreshable>.identity();

  /// タイルが mount 時に登録
  void register(TileRefreshable sub) {
    _subs.add(sub);
  }

  /// タイルが dispose 時に解除
  void unregister(TileRefreshable sub) {
    _subs.remove(sub);
  }

  /// まとめて再評価。順次 or 並列の両対応
  Future<void> refreshAll({bool parallel = false}) async {
    // スナップショットを取って、更新中の add/remove で壊れないようにする
    final list = List<TileRefreshable>.from(_subs);
    if (parallel) {
      await Future.wait(list.map((s) => s.refreshCacheState()));
    } else {
      for (final s in list) {
        await s.refreshCacheState();
      }
    }
  }

  /// 登録を全クリア（画面破棄時などに明示的に呼ぶ用。通常不要）
  void clear() => _subs.clear();

  /// 現在の登録数（デバッグ向け）
  int get subscriberCount => _subs.length;
}
