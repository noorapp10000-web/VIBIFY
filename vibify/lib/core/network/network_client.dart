import 'package:dio/dio.dart';

import '../constants/app_constants.dart';

class NetworkClient {
  NetworkClient._();

  static Dio createDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(milliseconds: AppConstants.networkTimeout),
        receiveTimeout: const Duration(milliseconds: AppConstants.networkTimeout),
        sendTimeout: const Duration(milliseconds: AppConstants.networkTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.addAll([
      _RetryInterceptor(dio),
      _LoggingInterceptor(),
    ]);

    return dio;
  }
}

class _RetryInterceptor extends Interceptor {
  final Dio dio;
  int _retryCount = 0;

  _RetryInterceptor(this.dio);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_retryCount < AppConstants.maxRetries &&
        (err.type == DioExceptionType.connectionTimeout ||
            err.type == DioExceptionType.receiveTimeout ||
            err.type == DioExceptionType.connectionError)) {
      _retryCount++;
      await Future.delayed(Duration(seconds: _retryCount));
      try {
        final response = await dio.fetch(err.requestOptions);
        _retryCount = 0;
        return handler.resolve(response);
      } catch (e) {
        // fall through
      }
    }
    _retryCount = 0;
    handler.next(err);
  }
}

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err);
  }
}
