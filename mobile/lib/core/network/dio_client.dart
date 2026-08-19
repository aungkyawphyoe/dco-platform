import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_store.dart';
import 'auth_interceptor.dart';

class DioClient {
  DioClient({
    required AppConfig config,
    required TokenStore tokenStore,
    required RefreshTokens refreshTokens,
  }) : dio = Dio(
         BaseOptions(
           baseUrl: config.apiBaseUrl,
           connectTimeout: const Duration(seconds: 15),
           receiveTimeout: const Duration(seconds: 20),
           headers: const {
             'Accept': 'application/json',
             'Content-Type': 'application/json',
           },
         ),
       ) {
    dio.interceptors.add(
      AuthInterceptor(
        tokenStore: tokenStore,
        refreshTokens: refreshTokens,
        skipAuthPaths: const {
          '/auth/login',
          '/auth/signup',
          '/auth/refresh',
          '/auth/forgot-password',
          '/auth/reset-password',
          '/auth/verify-email',
        },
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.extra['dio'] = dio;
          handler.next(options);
        },
      ),
    );
  }

  final Dio dio;
}
