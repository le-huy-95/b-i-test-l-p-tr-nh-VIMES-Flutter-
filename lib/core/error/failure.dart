/// Standard Failure object to propagate API errors.
class Failure implements Exception {
  Failure({required this.message, this.code, this.details});

  final String message;
  final String? code;
  final Object? details;

  @override
  String toString() => code != null ? '[$code] $message' : message;
}
