// lib/utils/log.dart
import 'dart:math';
import 'package:flutter/foundation.dart';

void logd(String message, {String name = 'TopicDetail'}) {
  assert(() {
    const chunk = 800;
    for (int i = 0; i < message.length; i += chunk) {
      debugPrint(
        '[$name] ${message.substring(i, min(i + chunk, message.length))}',
      );
    }
    return true;
  }());
}
