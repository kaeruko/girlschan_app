/// Application route constants and argument types.
/// 
/// This file centralizes all navigation routes and argument types for type-safe routing.
/// Each route has associated constants and optional argument classes.

// Named route constants
class AppRoutes {
  // Root/main routes
  static const String home = '/';
  static const String topicList = '/topic/list';
  static const String topicDetail = '/topic/detail';
  static const String search = '/search';
  static const String favorites = '/favorites';
  static const String clips = '/clips';
  static const String newList = '/new/list';

  // Dynamic path builders (for deep linking and direct navigation)
  /// Build topic detail path: /topic/detail/<id>?title=...&comments=...
  static String topicDetailPath({
    required String topicId,
    String? title,
    String? comments,
  }) {
    String path = '/topic/detail/$topicId';
    final params = <String>[];
    if (title != null) params.add('title=${Uri.encodeComponent(title)}');
    if (comments != null) params.add('comments=${Uri.encodeComponent(comments)}');
    if (params.isNotEmpty) {
      path += '?${params.join('&')}';
    }
    return path;
  }

  /// Build new list path: /new/list?sortOrder=...
  static String newListPath({String? sortOrder}) {
    if (sortOrder == null) return newList;
    return '$newList?sortOrder=${Uri.encodeComponent(sortOrder)}';
  }
}

/// Argument type for TopicDetail route (named route variant).
/// Use this when navigating via named route with arguments.
/// 
/// Example:
/// ```dart
/// Navigator.of(context).pushNamed(
///   AppRoutes.topicDetail,
///   arguments: TopicDetailArgs(topicId: '123', title: 'My Topic'),
/// );
/// ```
class TopicDetailArgs {
  final String topicId;
  final String? title;
  final String? comments;

  TopicDetailArgs({
    required this.topicId,
    this.title,
    this.comments,
  });

  /// Parse arguments from route path (/topic/detail/<id>?title=...&comments=...)
  factory TopicDetailArgs.fromUri(Uri uri) {
    final pathSegments = uri.pathSegments;
    final topicId = pathSegments.lastWhere((seg) => seg.isNotEmpty);
    final title = uri.queryParameters['title'];
    final comments = uri.queryParameters['comments'];
    return TopicDetailArgs(
      topicId: topicId,
      title: title,
      comments: comments,
    );
  }

  /// Convert to URI for deep linking
  Uri toUri() {
    return Uri.parse(AppRoutes.topicDetailPath(
      topicId: topicId,
      title: title,
      comments: comments,
    ));
  }

  @override
  String toString() =>
      'TopicDetailArgs(topicId: $topicId, title: $title, comments: $comments)';
}

/// Argument type for NewList route (named route variant).
/// Use this when navigating via named route with arguments.
class NewListArgs {
  final String? sortOrder;

  NewListArgs({this.sortOrder});

  /// Parse arguments from route path (/new/list?sortOrder=...)
  factory NewListArgs.fromUri(Uri uri) {
    final sortOrder = uri.queryParameters['sortOrder'];
    return NewListArgs(sortOrder: sortOrder);
  }

  /// Convert to URI for deep linking
  Uri toUri() {
    return Uri.parse(AppRoutes.newListPath(sortOrder: sortOrder));
  }

  @override
  String toString() => 'NewListArgs(sortOrder: $sortOrder)';
}
