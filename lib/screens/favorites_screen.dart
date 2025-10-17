import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../config/app_config.dart';
import 'topic_detail.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<int> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final ids = await getFavoriteIds();  // ← ローカルから読む
    setState(() {
      _favorites = ids;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_favorites.isEmpty) {
      return const Center(child: Text('お気に入りはありません'));
    }

    return ListView.builder(
      itemCount: _favorites.length,
      itemBuilder: (context, i) {
        final id = _favorites[i];
        return ListTile(
          title: Text('トピックID: $id'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TopicDetailScreen(
                  topicId: id,
                  title: 'お気に入りトピック $id',
                  commentCount: 0,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
