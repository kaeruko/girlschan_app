import 'package:flutter/foundation.dart';

/// 履歴が更新されたことを通知するためのNotifier
final historyUpdateNotifier = ValueNotifier<int>(0);

/// クリップが更新されたことを通知するためのNotifier
final clipsUpdateNotifier = ValueNotifier<int>(0);
