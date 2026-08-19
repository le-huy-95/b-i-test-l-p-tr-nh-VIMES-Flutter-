class UploadedFile {
  const UploadedFile({
    required this.id,
    required this.tenantId,
    required this.uploadedById,
    required this.url,
    required this.originalName,
    required this.mimeType,
    required this.size,
    required this.kind,
    required this.createdAt,
  });

  final String id;
  final String tenantId;
  final String uploadedById;
  final String url;
  final String originalName;
  final String mimeType;
  final int size;
  final String kind;
  final DateTime createdAt;

  factory UploadedFile.fromJson(Map<String, dynamic> json) {
    return UploadedFile(
      id: '${json['id'] ?? ''}',
      tenantId: '${json['tenantId'] ?? ''}',
      uploadedById: '${json['uploadedById'] ?? ''}',
      url: '${json['url'] ?? ''}',
      originalName: '${json['originalName'] ?? ''}',
      mimeType: '${json['mimeType'] ?? ''}',
      size: int.tryParse('${json['size'] ?? 0}') ?? 0,
      kind: '${json['kind'] ?? 'general'}',
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
    );
  }
}
