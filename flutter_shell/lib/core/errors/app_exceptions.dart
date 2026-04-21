/// Thrown when we can't even reach the network (DNS fail, no internet, timeout).
class NetworkException implements Exception {
  final String message;
  final Object? cause;
  NetworkException(this.message, {this.cause});

  @override
  String toString() => 'NetworkException($message)';
}

/// Thrown when the server responded but with a non-2xx status code.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Object? body;
  ApiException(this.statusCode, this.message, {this.body});

  @override
  String toString() => 'ApiException($statusCode, $message)';
}
