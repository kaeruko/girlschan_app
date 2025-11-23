class CommentUrl {
  final String url;
  final String title;
  final String? description;
  final String? thumbnail;

  CommentUrl({
    required this.url,
    required this.title,
    this.description,
    this.thumbnail,
  });

  factory CommentUrl.fromJson(Map<String, dynamic> json) {
    return CommentUrl(
      url: json['url'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      thumbnail: json['thumbnail'],
    );
  }
}

enum CommentUserStatus {
  none,      // 何もなし
  clipped,   // クリップ済み（通常）
  myComment, // 自分のコメント（かつクリップ済み）
}

class Comment {
  final int id;
  final String postedAt;
  final String body;
  final String name; // ★ 追加
  int plus; // mutable
  int minus; // mutable
  final String? imageUrl;
  final String? originalImageUrl;
  final List<int> anchors;
  final List<int> reverseAnchors;
  final List<CommentUrl> urls;
  final bool isLocal;

  Comment({
    required this.id,
    required this.postedAt,
    required this.body,
    this.name = '匿名', // ★ 追加
    required this.plus,
    required this.minus,
    this.imageUrl,
    this.anchors = const [],
    this.reverseAnchors = const [],
    this.urls = const [],
    this.originalImageUrl, // added field
    this.isLocal = false,
  });

  factory Comment.fromCsv(List<String> row) {
    return Comment(
      id: int.tryParse(row[0]) ?? 0,
      postedAt: row[1],
      body: row[2],
      plus: int.tryParse(row[3]) ?? 0,
      minus: int.tryParse(row[4]) ?? 0,
      imageUrl: row.length > 5 ? row[5] : null,
    );
  }

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['no'] ?? 0,
      postedAt: json['posted_at'] ?? '',
      body: json['body'] ?? '',
      name: json['name'] ?? '匿名', // ★ 追加
      plus: json['plus'] ?? 0,
      minus: json['minus'] ?? 0,
      imageUrl: json['image_url'],
      originalImageUrl: json['original_image_url'],
      anchors: List<int>.from(json['anchors'] ?? []),
      reverseAnchors: List<int>.from(json['reverse_anchors'] ?? []),
      urls: (json['urls'] as List<dynamic>?)
          ?.map((e) => CommentUrl.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      isLocal: json['isLocal'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'no': id,
        'posted_at': postedAt,
        'body': body,
        'name': name,
        'plus': plus,
        'minus': minus,
        'original_image_url': originalImageUrl,
        'image_url': imageUrl,
        'anchors': anchors,
        'reverse_anchors': reverseAnchors,
        'urls': urls
            .map((u) => {
                  'url': u.url,
                  'title': u.title,
                  'description': u.description,
                  'thumbnail': u.thumbnail,
                })
            .toList(),
        'isLocal': isLocal,
      };
}
