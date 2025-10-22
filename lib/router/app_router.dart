import 'package:flutter/cupertino.dart';
import '../screens/topic_list.dart';
import '../screens/topic_detail.dart';
import '../screens/search_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/clips_screen.dart';
import '../screens/new_list.dart';
import 'app_routes.dart';

/// Centralized router for the application.
/// 
/// This class handles route generation, deep linking, and provides type-safe
/// navigation helpers. All screen transitions use CupertinoPageRoute for
/// consistent navigation experience across iOS and macOS.
/// 
/// Usage:
/// 1. Named route with arguments:
///    Navigator.of(context).pushNamed(
///      AppRoutes.topicDetail,
///      arguments: TopicDetailArgs(topicId: '123', title: 'Topic'),
///    );
/// 
/// 2. Dynamic path (deep linking):
///    Navigator.of(context).pushNamed(AppRoutes.topicDetailPath(topicId: '123'));
/// 
/// 3. Type-safe navigation helper:
///    AppRouter.pushTopicDetail(context, topicId: '123', title: 'Topic');
class AppRouter {
  /// Main onGenerateRoute handler for CupertinoApp and CupertinoTabView.
  /// 
  /// Supports both:
  /// - Named routes with arguments: /topic/detail (with TopicDetailArgs)
  /// - Dynamic paths with query parameters: /topic/detail/123?title=...
  /// 
  /// Returns CupertinoPageRoute for all transitions, ensuring consistent
  /// Cupertino design language across the app.
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? '/';
    final args = settings.arguments;

    // Extract URI from route name for query parameter parsing
    final uri = Uri.parse(name);
    final pathSegments = uri.pathSegments;

    // Home / Root
    if (name == AppRoutes.home || name == '/') {
      return CupertinoPageRoute(
        builder: (_) => const TopicListScreen(),
        settings: settings,
      );
    }

    // Topic List
    if (name == AppRoutes.topicList || pathSegments.contains('list') && pathSegments.contains('topic')) {
      return CupertinoPageRoute(
        builder: (_) => const TopicListScreen(),
        settings: settings,
      );
    }

    // Topic Detail - supports both named route with args and dynamic path
    if (name == AppRoutes.topicDetail || 
        (pathSegments.contains('detail') && pathSegments.contains('topic'))) {
      
      TopicDetailArgs detailArgs;
      
      if (args is TopicDetailArgs) {
        // Named route variant: arguments passed directly
        detailArgs = args;
      } else {
        // Dynamic path variant: parse from URI
        detailArgs = TopicDetailArgs.fromUri(uri);
      }

      return CupertinoPageRoute(
        builder: (_) => TopicDetailScreen(
          topicId: detailArgs.topicId,
          title: detailArgs.title,
          comments: detailArgs.comments,
        ),
        settings: settings,
      );
    }

    // Search
    if (name == AppRoutes.search || pathSegments.contains('search')) {
      return CupertinoPageRoute(
        builder: (_) => const SearchScreen(),
        settings: settings,
      );
    }

    // Favorites
    if (name == AppRoutes.favorites || pathSegments.contains('favorites')) {
      return CupertinoPageRoute(
        builder: (_) => const FavoritesScreen(),
        settings: settings,
      );
    }

    // Clips
    if (name == AppRoutes.clips || pathSegments.contains('clips')) {
      return CupertinoPageRoute(
        builder: (_) => const ClipsScreen(),
        settings: settings,
      );
    }

    // New List
    if (name == AppRoutes.newList || 
        (pathSegments.contains('list') && pathSegments.contains('new'))) {
      
      NewListArgs newListArgs;
      
      if (args is NewListArgs) {
        newListArgs = args;
      } else {
        newListArgs = NewListArgs.fromUri(uri);
      }

      return CupertinoPageRoute(
        builder: (_) => NewListScreen(sortOrder: newListArgs.sortOrder),
        settings: settings,
      );
    }

    // Unknown route - fallback to home
    return CupertinoPageRoute(
      builder: (_) => const TopicListScreen(),
      settings: const RouteSettings(name: AppRoutes.home),
    );
  }

  // ============================================================================
  // Type-safe navigation helpers
  // ============================================================================
  // These methods provide a convenient, type-safe way to navigate to screens
  // without manually constructing route names or arguments.

  /// Navigate to TopicDetail with type-safe arguments.
  /// 
  /// Example:
  /// ```dart
  /// AppRouter.pushTopicDetail(
  ///   context,
  ///   topicId: '123',
  ///   title: 'My Topic',
  /// );
  /// ```
  static Future<T?> pushTopicDetail<T>(
    BuildContext context, {
    required String topicId,
    String? title,
    String? comments,
  }) {
    return Navigator.of(context).pushNamed<T>(
      AppRoutes.topicDetail,
      arguments: TopicDetailArgs(
        topicId: topicId,
        title: title,
        comments: comments,
      ),
    );
  }

  /// Navigate to TopicDetail using dynamic path (deep linking style).
  /// 
  /// Example:
  /// ```dart
  /// AppRouter.pushTopicDetailByPath(
  ///   context,
  ///   topicId: '123',
  ///   title: 'My Topic',
  /// );
  /// ```
  static Future<T?> pushTopicDetailByPath<T>(
    BuildContext context, {
    required String topicId,
    String? title,
    String? comments,
  }) {
    return Navigator.of(context).pushNamed<T>(
      AppRoutes.topicDetailPath(
        topicId: topicId,
        title: title,
        comments: comments,
      ),
    );
  }

  /// Navigate to NewList with optional sort order.
  /// 
  /// Example:
  /// ```dart
  /// AppRouter.pushNewList(context, sortOrder: 'latest');
  /// ```
  static Future<T?> pushNewList<T>(
    BuildContext context, {
    String? sortOrder,
  }) {
    return Navigator.of(context).pushNamed<T>(
      AppRoutes.newList,
      arguments: NewListArgs(sortOrder: sortOrder),
    );
  }

  /// Navigate to Search screen.
  static Future<T?> pushSearch<T>(BuildContext context) {
    return Navigator.of(context).pushNamed<T>(AppRoutes.search);
  }

  /// Navigate to Favorites screen.
  static Future<T?> pushFavorites<T>(BuildContext context) {
    return Navigator.of(context).pushNamed<T>(AppRoutes.favorites);
  }

  /// Navigate to Clips screen.
  static Future<T?> pushClips<T>(BuildContext context) {
    return Navigator.of(context).pushNamed<T>(AppRoutes.clips);
  }

  /// Navigate to TopicList screen.
  static Future<T?> pushTopicList<T>(BuildContext context) {
    return Navigator.of(context).pushNamed<T>(AppRoutes.topicList);
  }

  /// Replace current route with TopicDetail.
  static Future<T?> replaceWithTopicDetail<T>(
    BuildContext context, {
    required String topicId,
    String? title,
    String? comments,
  }) {
    return Navigator.of(context).pushReplacementNamed<T, T>(
      AppRoutes.topicDetail,
      arguments: TopicDetailArgs(
        topicId: topicId,
        title: title,
        comments: comments,
      ),
    );
  }

  /// Replace current route with home.
  static Future<T?> replaceWithHome<T>(BuildContext context) {
    return Navigator.of(context).pushReplacementNamed<T, T>(AppRoutes.home);
  }

  /// Pop to TopicList (or home if TopicList not found).
  static void popToHome(BuildContext context) {
    Navigator.of(context).popUntil(
      (route) => route.settings.name == AppRoutes.topicList || 
                  route.settings.name == AppRoutes.home ||
                  route.isFirst,
    );
  }
}
