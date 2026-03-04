import 'package:flutter/foundation.dart';

/// macOSのネイティブタイトルバー高さを通知するNotifier
/// MacShellが初期化時にセットし、画面側で参照する
final captionHeightNotifier = ValueNotifier<double>(28.0);
