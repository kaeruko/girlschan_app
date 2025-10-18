class Comment {
  final int id;
  final String time;
  final String text;
  final int plus;
  final int minus;
  final String? imageUrl;
  final List<int> anchors;
  final List<int> reverseAnchors;

  Comment({
    required this.id,
    required this.time,
    required this.text,
    required this.plus,
    required this.minus,
    this.imageUrl,
    this.anchors = const [],
    this.reverseAnchors = const [],
  });

  factory Comment.fromCsv(List<String> row) {
    return Comment(
      id: int.tryParse(row[0]) ?? 0,
      time: row[1],
      text: row[2],
      plus: int.tryParse(row[3]) ?? 0,
      minus: int.tryParse(row[4]) ?? 0,
      imageUrl: row.length > 5 ? row[5] : null,
    );
  }

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['no'] ?? 0,
      time: json['time'] ?? '',
      text: json['body'] ?? '',
      plus: json['plus'] ?? 0,
      minus: json['minus'] ?? 0,
      imageUrl: json['image_url'],
      anchors: List<int>.from(json['anchors'] ?? []),
      reverseAnchors: List<int>.from(json['reverse_anchors'] ?? []),
    );
  }
}
