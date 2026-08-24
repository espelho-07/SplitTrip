import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'api_exceptions.dart';

class ApiClient {
  final http.Client _httpClient;
  String? _authToken;

  ApiClient({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  void setAuthToken(String? token) {
    _authToken = token;
  }

  String? get authToken => _authToken;

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  Uri _buildUri(String path, [Map<String, dynamic>? queryParams]) {
    final base = AppConfig.baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final urlStr = '$base$cleanPath';

    if (queryParams != null && queryParams.isNotEmpty) {
      final stringParams = queryParams.map((k, v) => MapEntry(k, v.toString()));
      return Uri.parse(urlStr).replace(queryParameters: stringParams);
    }
    return Uri.parse(urlStr);
  }

  static const Duration _defaultTimeout = Duration(seconds: 8);

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParams}) async {
    try {
      final uri = _buildUri(path, queryParams);
      final response = await _httpClient
          .get(uri, headers: _buildHeaders())
          .timeout(_defaultTimeout);
      return _processResponse(response);
    } on SocketException catch (_) {
      throw const NetworkException(message: 'Unable to reach server. Operating in offline mode.');
    } on TimeoutException catch (_) {
      throw const NetworkException(message: 'Request timed out. Please check your network and retry.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException(message: e.toString());
    }
  }

  Future<dynamic> post(String path, {dynamic body}) async {
    try {
      final uri = _buildUri(path);
      final response = await _httpClient
          .post(
            uri,
            headers: _buildHeaders(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_defaultTimeout);
      return _processResponse(response);
    } on SocketException catch (_) {
      throw const NetworkException(message: 'Unable to reach server. Operating in offline mode.');
    } on TimeoutException catch (_) {
      throw const NetworkException(message: 'Request timed out. Please check your network and retry.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException(message: e.toString());
    }
  }

  Future<dynamic> put(String path, {dynamic body}) async {
    try {
      final uri = _buildUri(path);
      final response = await _httpClient
          .put(
            uri,
            headers: _buildHeaders(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_defaultTimeout);
      return _processResponse(response);
    } on SocketException catch (_) {
      throw const NetworkException(message: 'Unable to reach server. Operating in offline mode.');
    } on TimeoutException catch (_) {
      throw const NetworkException(message: 'Request timed out. Please check your network and retry.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException(message: e.toString());
    }
  }

  Future<dynamic> patch(String path, {dynamic body}) async {
    try {
      final uri = _buildUri(path);
      final response = await _httpClient
          .patch(
            uri,
            headers: _buildHeaders(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_defaultTimeout);
      return _processResponse(response);
    } on SocketException catch (_) {
      throw const NetworkException(message: 'Unable to reach server. Operating in offline mode.');
    } on TimeoutException catch (_) {
      throw const NetworkException(message: 'Request timed out. Please check your network and retry.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException(message: e.toString());
    }
  }

  Future<dynamic> delete(String path) async {
    try {
      final uri = _buildUri(path);
      final response = await _httpClient
          .delete(uri, headers: _buildHeaders())
          .timeout(_defaultTimeout);
      return _processResponse(response);
    } on SocketException catch (_) {
      throw const NetworkException(message: 'Unable to reach server. Operating in offline mode.');
    } on TimeoutException catch (_) {
      throw const NetworkException(message: 'Request timed out. Please check your network and retry.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException(message: e.toString());
    }
  }

  dynamic _processResponse(http.Response response) {
    dynamic decoded;
    try {
      if (response.body.isNotEmpty) {
        decoded = jsonDecode(response.body);
      }
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
        return decoded['data'];
      }
      return decoded;
    }

    // Handle Error Status Codes
    String message = 'An error occurred';
    String code = 'API_ERROR';
    dynamic details;

    if (decoded is Map<String, dynamic> && decoded.containsKey('error')) {
      final err = decoded['error'];
      if (err is Map<String, dynamic>) {
        message = err['message'] ?? message;
        code = err['code'] ?? code;
        details = err['details'];
      }
    }

    switch (response.statusCode) {
      case 400:
        throw ValidationException(message: message, details: details);
      case 401:
        throw UnauthorizedException(message: message);
      case 403:
        throw ForbiddenException(message: message);
      case 404:
        throw NotFoundException(message: message);
      case 409:
        throw ConflictException(message: message, details: details);
      default:
        throw ApiException(
          message: message,
          code: code,
          statusCode: response.statusCode,
          details: details,
        );
    }
  }
}
