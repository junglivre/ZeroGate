import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'local_storage.dart';

/// Base HTTP client shared by all Cloudflare API services (accounts, tunnels,
/// Access apps/policies). Handles auth headers, pagination and error
/// formatting the same way across the whole data layer.
class CloudflareApi {
  static const String baseUrl = kIsWeb
      ? 'http://localhost:8081/client/v4'
      : 'https://api.cloudflare.com/client/v4';

  static Future<Map<String, String>> headers() async {
    final token = await LocalStorage.getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Streams every page of a paginated Cloudflare list endpoint.
  static Stream<dynamic> streamPaginated(
    String path, {
    Map<String, String> extraParams = const {},
  }) async* {
    int page = 1;
    bool hasMore = true;
    final auth = await headers();

    while (hasMore) {
      final params = {
        'per_page': '50',
        'page': '$page',
        ...extraParams,
      };
      final uri = Uri.parse('$baseUrl$path').replace(queryParameters: params);
      final response = await http.get(uri, headers: auth);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          for (final item in json['result']) {
            yield item;
          }
          final resultInfo = json['result_info'];
          if (resultInfo != null && resultInfo['total_pages'] != null) {
            final int totalPages = resultInfo['total_pages'];
            if (page >= totalPages) {
              hasMore = false;
            } else {
              page++;
            }
          } else {
            hasMore = false;
          }
        } else {
          throw Exception('Failed to load $path: ${json['errors']}');
        }
      } else {
        throw Exception('Failed to load $path. HTTP ${response.statusCode}');
      }
    }
  }

  static Future<Map<String, dynamic>> getJson(String path) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: await headers(),
    );
    final json = jsonDecode(response.body);
    if (json['success'] != true) {
      throw Exception('Falha ao carregar: ${formatErrors(json)}');
    }
    return json;
  }

  static Future<Map<String, dynamic>> post(
      String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: await headers(),
      body: jsonEncode(body),
    );
    final json = jsonDecode(response.body);
    if (json['success'] != true) {
      throw Exception('Falha ao criar: ${formatErrors(json)}');
    }
    return json;
  }

  static Future<Map<String, dynamic>> put(
      String path, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: await headers(),
      body: jsonEncode(body),
    );
    final json = jsonDecode(response.body);
    if (json['success'] != true) {
      throw Exception('Falha ao atualizar: ${formatErrors(json)}');
    }
    return json;
  }

  static Future<void> delete(String path) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: await headers(),
    );
    final json = jsonDecode(response.body);
    if (json['success'] != true) {
      throw Exception('Falha ao excluir: ${formatErrors(json)}');
    }
  }

  static String formatErrors(Map<String, dynamic> json) {
    final errors = json['errors'];
    if (errors is List && errors.isNotEmpty) {
      return errors.map((error) {
        if (error is Map<String, dynamic>) {
          final code = error['code'];
          final message = error['message'];
          if (code != null && message != null) {
            return '$message (código $code)';
          }
          if (message != null) return message.toString();
        }
        return error.toString();
      }).join('; ');
    }
    return 'erro desconhecido da API Cloudflare';
  }

  /// Streams the Cloudflare accounts this API Token has access to, one page
  /// at a time, so callers can render results as they arrive instead of
  /// waiting for every page to load.
  static Stream<dynamic> streamAccounts() => streamPaginated('/accounts');

  /// Lists the Cloudflare accounts this API Token has access to. A token
  /// scoped to multiple accounts (selected when creating it) makes all of
  /// them show up here.
  static Future<List<dynamic>> listAccounts() async {
    final accounts = <dynamic>[];
    await for (final account in streamAccounts()) {
      accounts.add(account);
    }
    return accounts;
  }
}
