class AppException implements Exception {
  final String message;
  const AppException({required this.message});

  @override
  String toString() => 'AppException: $message';
}

class NetworkException extends AppException {
  const NetworkException({required super.message});
}

class ServerException extends AppException {
  final int? statusCode;
  const ServerException({required super.message, this.statusCode});
}

class CacheException extends AppException {
  const CacheException({required super.message});
}

class PermissionException extends AppException {
  const PermissionException({required super.message});
}

class AudioException extends AppException {
  const AudioException({required super.message});
}

class StreamException extends AppException {
  const StreamException({required super.message});
}
