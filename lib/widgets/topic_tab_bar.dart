import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../controllers/tabs_controller.dart';

/// 右ペイン上部に表示するトピックタブバー
class TopicTabBar extends StatelessWidget {
  final List<TopicTab> tabs;
  final int activeIndex;
  final void Function(int index) onTabTap;
  final void Function(int index) onTabClose;

  const TopicTabBar({
    super.key,
    required this.tabs,
    required this.activeIndex,
    required this.onTabTap,
    required this.onTabClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        border: Border(
          bottom: BorderSide(color: CupertinoColors.separator, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < tabs.length; i++)
              _TabChip(
                tab: tabs[i],
                isActive: i == activeIndex,
                onTap: () => onTabTap(i),
                onClose: () => onTabClose(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final TopicTab tab;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _TabChip({
    required this.tab,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 80, maxWidth: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border(
            right: const BorderSide(color: CupertinoColors.separator, width: 1),
            bottom: isActive
                ? const BorderSide(color: CupertinoColors.activeBlue, width: 2)
                : BorderSide.none,
          ),
          color: isActive
              ? CupertinoColors.systemBackground
              : CupertinoColors.systemGrey6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                tab.title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive
                      ? CupertinoColors.label
                      : CupertinoColors.secondaryLabel,
                ),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onClose,
              child: const Icon(
                CupertinoIcons.xmark,
                size: 12,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
