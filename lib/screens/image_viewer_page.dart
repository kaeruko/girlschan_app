import 'package:flutter/cupertino.dart';
import '../services/window_notifier.dart';
import '../utils/platform_helper.dart';

class ImageViewerPage extends StatelessWidget {
  final String url;
  const ImageViewerPage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final topPadding = PlatformHelper.isMacOS ? captionHeightNotifier.value : 0.0;
    final scaffold = CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black.withValues(alpha: 0.6),
        // 閉じるボタン
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Icon(CupertinoIcons.xmark, color: CupertinoColors.white),
        ),
      ),
      child: SafeArea(
        child: Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                CupertinoIcons.exclamationmark_circle,
                size: 40,
                color: CupertinoColors.white,
              ),
            ),
          ),
        ),
      ),
    );
    if (topPadding <= 0) return scaffold;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: MediaQuery.of(context).padding.copyWith(top: topPadding),
      ),
      child: scaffold,
    );
  }
}
