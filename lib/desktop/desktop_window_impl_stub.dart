// iOS/Android/Web 等、desktop_window が不要なプラットフォーム用の何もしない実装

abstract class DesktopWindowImpl {
  Future<void> init();
  Future<void> show();
}

class _StubDesktopWindowImpl implements DesktopWindowImpl {
  @override
  Future<void> init() async {
    // iOS の場合はここが呼ばれない（desktop_window.dart で Platform check）
    // しかし、もし呼ばれても何もしないので安全
  }

  @override
  Future<void> show() async {
    // iOS の場合はここが呼ばれない
  }
}

/// 条件付き import で呼ばれるファクトリ
/// iOS/Android/Web ではこれが使われる
DesktopWindowImpl createDesktopWindowImpl() => _StubDesktopWindowImpl();
