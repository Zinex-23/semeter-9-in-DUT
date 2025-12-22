import 'dart:convert';
import 'package:http/http.dart' as http;

class RealtimeDbService {
  static const String defaultBaseUrl = String.fromEnvironment(
    'RTDB_URL',
    defaultValue:
        'https://simulated-d40be-default-rtdb.asia-southeast1.firebasedatabase.app',
  );
  static const String _auth = String.fromEnvironment('RTDB_AUTH');

  static Future<void> patch({
    required String baseUrl,
    Map<String, dynamic> data = const {},
    String path = '/',
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final String root = baseUrl.trim().replaceAll(RegExp(r"/+$"), '');
    final String p = path.startsWith('/') ? path : '/$path';
    final String jsonPath = p.endsWith('.json') ? p : '$p.json';

    final uri = Uri.parse('$root$jsonPath').replace(
      queryParameters: {
        if (_auth.isNotEmpty) 'auth': _auth,
      },
    );

    final resp = await http
        .patch(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(data),
        )
        .timeout(timeout);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('RTDB PATCH ${resp.statusCode}: ${resp.body}');
    }
  }

  static Future<void> put({
    required String baseUrl,
    required Map<String, dynamic> data,
    String path = '/',
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final String root = baseUrl.trim().replaceAll(RegExp(r"/+$"), '');
    final String p = path.startsWith('/') ? path : '/$path';
    final String jsonPath = p.endsWith('.json') ? p : '$p.json';
    final uri = Uri.parse('$root$jsonPath').replace(
      queryParameters: {
        if (_auth.isNotEmpty) 'auth': _auth,
      },
    );

    final resp = await http
        .put(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(data),
        )
        .timeout(timeout);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('RTDB PUT ${resp.statusCode}: ${resp.body}');
    }
  }
}
