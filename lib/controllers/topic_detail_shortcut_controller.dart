import 'package:flutter/foundation.dart';

class TopicDetailShortcutController {
  VoidCallback? focusSearch;
  VoidCallback? nextHit;
  VoidCallback? prevHit;
  VoidCallback? nextUnread;
  VoidCallback? prevUnread;
  VoidCallback? jumpToComment;

  void bind({
    required VoidCallback focusSearch,
    required VoidCallback nextHit,
    required VoidCallback prevHit,
    required VoidCallback nextUnread,
    required VoidCallback prevUnread,
    required VoidCallback jumpToComment,
  }) {
    this.focusSearch = focusSearch;
    this.nextHit = nextHit;
    this.prevHit = prevHit;
    this.nextUnread = nextUnread;
    this.prevUnread = prevUnread;
    this.jumpToComment = jumpToComment;
  }

  void clear() {
    focusSearch = null;
    nextHit = null;
    prevHit = null;
    nextUnread = null;
    prevUnread = null;
    jumpToComment = null;
  }
}
