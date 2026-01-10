import 'package:flutter/cupertino.dart';

class InlineNotice extends StatelessWidget {
  final String text;
  final VoidCallback? onClose;
  final bool isError;

  const InlineNotice({
    super.key,
    required this.text,
    this.onClose,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isError
        ? CupertinoColors.systemRed.withValues(alpha: 0.08)
        : CupertinoColors.activeBlue.withValues(alpha: 0.07);
    final fg = isError ? CupertinoColors.systemRed : CupertinoColors.activeBlue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          bottom: BorderSide(color: fg.withValues(alpha: 0.2), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? CupertinoIcons.exclamationmark_circle
                    : CupertinoIcons.info,
            size: 18,
            color: fg,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: fg,
                fontSize: 13.5,
              ),
            ),
          ),
          if (onClose != null)
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size.square(28),
              onPressed: onClose,
              child: const Icon(CupertinoIcons.xmark, size: 16),
            ),
        ],
      ),
    );
  }
}
