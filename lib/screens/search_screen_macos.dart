import 'package:flutter/cupertino.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../utils/log.dart';
import '../widgets/topic_tile.dart';
import '../widgets/topic_tile_controller.dart';
import '../widgets/common/app_spinner.dart';
import '../widgets/common/app_toast.dart';

class SearchScreenMacOS extends StatefulWidget {
  const SearchScreenMacOS({super.key});

  @override
  State<SearchScreenMacOS> createState() => _SearchScreenMacOSState();
}

class _SearchScreenMacOSState extends State<SearchScreenMacOS> {
  final TextEditingController _searchController = TextEditingController();
  final _controller = TopicTileController();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String _currentQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      await AppToast.show(context, '検索キーワードを入力してください');
      return;
    }

    setState(() {
      _isSearching = true;
      _currentQuery = query;
    });

    try {
      logd('🔍 [SearchScreen] 検索開始: $query', name: 'SearchScreen');

      final uri = Uri.parse('${AppConfig.apiBase}/search').replace(
        queryParameters: {
          'q': query,
          'page': '1',
          'count': '50',
        },
      );

      logd('🔍 [SearchScreen] API URL: $uri', name: 'SearchScreen');

      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('タイムアウト'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        logd('🔍 [SearchScreen] 検索成功', name: 'SearchScreen');

        if (!mounted) return;

        final results = data['results'] is List
            ? (data['results'] as List).cast<Map<String, dynamic>>()
            : (data['topics'] is List
                ? (data['topics'] as List).cast<Map<String, dynamic>>()
                : <Map<String, dynamic>>[]);

        setState(() {
          _searchResults = results;
          _hasSearched = true;
        });

        if (results.isEmpty && mounted) {
          await AppToast.show(context, '該当するトピックが見つかりません');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      logd('❌ [SearchScreen] エラー: $e', name: 'SearchScreen');
      if (mounted) {
        await AppToast.show(context, 'エラーが発生しました: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 検索バー
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6.withOpacity(0.5),
            border: Border(
              bottom: BorderSide(
                color: CupertinoColors.separator.withOpacity(0.3),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: _searchController,
                  placeholder: 'キーワードを入力',
                  placeholderStyle: const TextStyle(
                    color: CupertinoColors.placeholderText,
                  ),
                  prefix: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      CupertinoIcons.search,
                      color: CupertinoColors.label,
                      size: 16,
                    ),
                  ),
                  suffix: _searchController.text.isNotEmpty
                      ? CupertinoButton(
                          padding: EdgeInsets.zero,
                          minSize: 0,
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchResults = [];
                              _hasSearched = false;
                            });
                          },
                          child: const Icon(
                            CupertinoIcons.xmark_circle_fill,
                            color: CupertinoColors.label,
                            size: 16,
                          ),
                        )
                      : null,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: _performSearch,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: CupertinoColors.systemBlue,
                onPressed: _isSearching
                    ? null
                    : () => _performSearch(_searchController.text),
                child: _isSearching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CupertinoActivityIndicator(radius: 7),
                      )
                    : const Text('検索'),
              ),
            ],
          ),
        ),
        // 検索結果
        Expanded(
          child: _buildResultsView(),
        ),
      ],
    );
  }

  Widget _buildResultsView() {
    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.search,
              size: 48,
              color: CupertinoColors.systemGrey,
            ),
            const SizedBox(height: 16),
            const Text(
              'キーワードを入力して検索',
              style: TextStyle(
                color: CupertinoColors.systemGrey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppSpinner(size: 20),
            SizedBox(height: 16),
            Text(
              '検索中...',
              style: TextStyle(
                color: CupertinoColors.systemGrey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.info_circle,
              size: 48,
              color: CupertinoColors.systemGrey,
            ),
            const SizedBox(height: 16),
            Text(
              '"$_currentQuery"に該当するトピックが見つかりません',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CupertinoColors.systemGrey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return CupertinoScrollbar(
      controller: _scrollController,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final topic = _searchResults[index];
          return TopicTile(
            topic: topic,
            controller: _controller,
            showThumb: true,
          );
        },
      ),
    );
  }
}
