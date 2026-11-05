import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class Api {
  /// Vide = même origine (Cloudflare Pages). Dev : --dart-define=API_BASE=http://localhost:8788
  static const String base = String.fromEnvironment('API_BASE', defaultValue: '');
  static String? token;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString('token');
  }

  static Future<void> setToken(String? t) async {
    token = t;
    final p = await SharedPreferences.getInstance();
    if (t == null) {
      await p.remove('token');
    } else {
      await p.setString('token', t);
    }
  }

  static Uri uri(String path, [Map<String, String>? query]) {
    final full = base.isEmpty ? Uri.base.resolve('/api$path') : Uri.parse('$base/api$path');
    return query == null ? full : full.replace(queryParameters: query);
  }

  static String avatarUrl(String id, int v) => uri('/avatar/$id', {'v': '$v'}).toString();

  static Uri printUrl(String id) => uri('/prescriptions/$id/print', {'t': token ?? ''});

  static Future<dynamic> _send(String method, String path, {Map<String, String>? query, Object? body}) async {
    final u = uri(path, query);
    final h = <String, String>{'content-type': 'application/json'};
    if (token != null) h['authorization'] = 'Bearer $token';
    final String enc = jsonEncode(body ?? {});
    final http.Response r;
    switch (method) {
      case 'POST':
        r = await http.post(u, headers: h, body: enc);
        break;
      case 'PUT':
        r = await http.put(u, headers: h, body: enc);
        break;
      default:
        r = await http.get(u, headers: h);
    }
    dynamic data;
    try {
      data = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      data = null;
    }
    if (r.statusCode >= 400) {
      throw ApiException(data is Map && data['error'] != null ? '${data['error']}' : 'Erreur ${r.statusCode}');
    }
    return data;
  }

  static Future<dynamic> get(String path, [Map<String, String>? query]) => _send('GET', path, query: query);
  static Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body);
  static Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body: body);
}
