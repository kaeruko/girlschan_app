import 'package:flutter/widgets.dart';

/// タイルを一括で再評価するためのコントローラ
class TopicTileController {
  final Set<TileRefreshable> _tiles = {}; // ← _TileRefreshable -> TileRefreshable

  void register(TileRefreshable tile) => _tiles.add(tile);     // 型を公開型に
  void unregister(TileRefreshable tile) => _tiles.remove(tile);

  Future<void> refreshAll() async {
    final snapshot = List.of(_tiles);
    for (final t in snapshot) {
      if (t.mounted) {
        await t.refreshCacheState();
      }
    }
  }
}

/// 公開インターフェース（先頭アンダースコアを外す）
abstract class TileRefreshable {
  bool get mounted;
  Future<void> refreshCacheState();
}
