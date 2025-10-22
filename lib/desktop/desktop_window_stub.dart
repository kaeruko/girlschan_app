/// iOS/Android/Web 等、desktop_window が不要なプラットフォーム用の何もしない実装

Future<void> initDesktopWindow() async {
  // iOS の場合はここが呼ばれない（desktop_window.dart で Platform check）
  // しかし、もし呼ばれても何もしないので安全
}

Future<void> showDesktopWindow() async {
  // iOS の場合はここが呼ばれない
}
