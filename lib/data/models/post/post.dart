class Post {
  const Post({
    required this.id,
    required this.title,
    required this.body,
    this.userId,
  });

  final int id;
  final String title;
  final String body;
  final int? userId;

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      userId: json['userId'] is int ? json['userId'] as int : int.tryParse('${json['userId']}'),
    );
  }
}
