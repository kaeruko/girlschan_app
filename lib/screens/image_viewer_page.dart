import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ImageViewerPage extends StatelessWidget {
  final String url;
  const ImageViewerPage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black.withOpacity(0.6),
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
  }
}
