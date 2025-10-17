class Comment {
  final int id;
  final String time;
  final String text;
  final int plus;
  final int minus;
  final String? imageUrl;

  Comment({
    required this.id,
    required this.time,
    required this.text,
    required this.plus,
    required this.minus,
    this.imageUrl,
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
}
