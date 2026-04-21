import 'package:dio/dio.dart';

import '../errors/app_exceptions.dart';
import '../../utils/logger.dart';

/// Thin Dio wrapper that normalises errors into our app exceptions.
class ApiClient {
  final Dio _dio;

  ApiClient({required String baseUrl, Duration? connectTimeout, Duration? receiveTimeout})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: connectTimeout ?? const Duration(seconds: 6),
          receiveTimeout: receiveTimeout ?? const Duration(seconds: 10),
          sendTimeout:    const Duration(seconds: 10),
          responseType:   ResponseType.json,
          headers: const {'Accept': 'application/json'},
        ));

  Dio get dio => _dio;

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    try {
      return await _dio.get<T>(path, queryParameters: query);
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  Future<Response<T>> post<T>(String path, {Object? data}) async {
    try {
      return await _dio.post<T>(path, data: data);
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  Exception _translate(DioException e) {
    Log.w('[api] ${e.requestOptions.method} ${e.requestOptions.path} -> ${e.type} ${e.message}');
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.unknown:
        return NetworkException(e.message ?? 'Network error', cause: e);
      case DioExceptionType.badResponse:
        return ApiException(
          e.response?.statusCode ?? 0,
          e.message ?? 'Bad response',
          body: e.response?.data,
        );
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
        return NetworkException(e.message ?? 'Request cancelled/cert error', cause: e);
    }
  }
}
