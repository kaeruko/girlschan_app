// lib/utils/log.dart
import 'dart:math';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

void logd(String message, {String name = 'TopicDetail'}) {
  if (kReleaseMode) {
    dev.log(message, name: name);
  } else {
    const chunk = 800;
    for (int i = 0; i < message.length; i += chunk) {
      debugPrint(message.substring(i, min(i + chunk, message.length)));
    }
  }
}
