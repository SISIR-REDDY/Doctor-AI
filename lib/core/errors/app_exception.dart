class AppException implements Exception {
  final String code;
  final String message;
  final Object? cause;

  const AppException({
    required this.code,
    required this.message,
    this.cause,
  });

  @override
  String toString() {
    if (cause == null) {
      return message;
    }
    return '$message (cause: $cause)';
  }
}
