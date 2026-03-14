import 'package:flutter/foundation.dart';

class TopicDetailShortcutController {
  VoidCallback? focusSearch;
  VoidCallback? nextHit;
  VoidCallback? prevHit;
  VoidCallback? nextUnread;
  VoidCallback? prevUnread;
  VoidCallback? jumpToComment;
  VoidCallback? refresh;
  VoidCallback? scrollDown;
  VoidCallback? scrollUp;
  VoidCallback? scrollDownStep;
  VoidCallback? scrollUpStep;

  void bind({
    required VoidCallback focusSearch,
    required VoidCallback nextHit,
    required VoidCallback prevHit,
    required VoidCallback nextUnread,
    required VoidCallback prevUnread,
    required VoidCallback jumpToComment,
    VoidCallback? refresh,
    VoidCallback? scrollDown,
    VoidCallback? scrollUp,
    VoidCallback? scrollDownStep,
    VoidCallback? scrollUpStep,
  }) {
    this.focusSearch = focusSearch;
    this.nextHit = nextHit;
    this.prevHit = prevHit;
    this.nextUnread = nextUnread;
    this.prevUnread = prevUnread;
    this.jumpToComment = jumpToComment;
    this.refresh = refresh;
    this.scrollDown = scrollDown;
    this.scrollUp = scrollUp;
    this.scrollDownStep = scrollDownStep;
    this.scrollUpStep = scrollUpStep;
  }

  void clear() {
    focusSearch = null;
    nextHit = null;
    prevHit = null;
    nextUnread = null;
    prevUnread = null;
    jumpToComment = null;
    refresh = null;
    scrollDown = null;
    scrollUp = null;
    scrollDownStep = null;
    scrollUpStep = null;
  }
}
