import 'dart:convert';
import 'package:fetch_client/fetch_client.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// Réseau indisponible (hors-ligne, serveur injoignable). Distinct d'une erreur renvoyée par le serveur.
class OfflineException extends ApiException {
  OfflineException() : super('Connexion indisponible. Vérifiez votre réseau.');
}

class Api {
  /// Vide = même origine (Cloudflare Pages). Dev : --dart-define=API_BASE=http://localhost:8788
  static const String base = String.fromEnvironment('API_BASE', defaultValue: '');
  static String? token;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString('token');
  }

  /// Écrans lisibles hors-ligne : dernière réponse mémorisée. Jamais les messages, documents, exports ni le chat.
  static const _cacheable = {
    '/me', '/appointments', '/prescriptions', '/orders', '/reminders',
    '/doctors', '/pharmacies', '/me/notifications', '/doctor/availability',
  };

  static String _ckey(String path, Map<String, String>? q) =>
      'cache:$path?${(q ?? const <String, String>{}).entries.map((e) => '${e.key}=${e.value}').join('&')}';

  /// Efface les données mémorisées (déconnexion, changement de compte).
  static Future<void> clearCache() async {
    final p = await SharedPreferences.getInstance();
    for (final k in p.getKeys().where((k) => k.startsWith('cache:')).toList()) {
      await p.remove(k);
    }
  }

  static Future<void> setToken(String? t) async {
    token = t;
    await clearCache();
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

  static Uri documentUrl(String id) => uri('/documents/$id', {'t': token ?? ''});

  static Uri printUrl(String id) => uri('/prescriptions/$id/print', {'t': token ?? ''});

  static Future<dynamic> _send(String method, String path, {Map<String, String>? query, Object? body}) async {
    final u = uri(path, query);
    final h = <String, String>{'content-type': 'application/json'};
    if (token != null) h['authorization'] = 'Bearer $token';
    final String enc = jsonEncode(body ?? {});
    final http.Response r = await _req(method, u, h, enc);
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

  static Future<http.Response> _req(String method, Uri u, Map<String, String> h, String enc) async {
    try {
      switch (method) {
        case 'POST':
          return await http.post(u, headers: h, body: enc);
        case 'PUT':
          return await http.put(u, headers: h, body: enc);
        default:
          return await http.get(u, headers: h);
      }
    } catch (_) {
      throw OfflineException();
    }
  }

  /// GET avec repli hors-ligne : si le réseau est coupé, renvoie la dernière réponse mémorisée (écrans de lecture).
  static Future<dynamic> get(String path, [Map<String, String>? query]) async {
    try {
      final d = await _send('GET', path, query: query);
      if (_cacheable.contains(path)) {
        try {
          final p = await SharedPreferences.getInstance();
          await p.setString(_ckey(path, query), jsonEncode(d));
        } catch (_) {/* quota plein : on ignore */}
      }
      return d;
    } on OfflineException {
      if (_cacheable.contains(path)) {
        final p = await SharedPreferences.getInstance();
        final s = p.getString(_ckey(path, query));
        if (s != null) return jsonDecode(s);
      }
      rethrow;
    }
  }

  /// POST dont la réponse est un flux SSE (`data: {...}` par ligne) : un événement JSON par élément.
  static Stream<Map<String, dynamic>> postStream(String path, Object body) async* {
    final client = FetchClient(mode: RequestMode.cors);
    try {
      final req = http.Request('POST', uri(path));
      req.headers['content-type'] = 'application/json';
      if (token != null) req.headers['authorization'] = 'Bearer $token';
      req.body = jsonEncode(body);
      final http.StreamedResponse resp;
      try {
        resp = await client.send(req);
      } catch (_) {
        throw OfflineException();
      }
      if (resp.statusCode >= 400) {
        final txt = await resp.stream.bytesToString();
        dynamic d;
        try {
          d = jsonDecode(txt);
        } catch (_) {
          d = null;
        }
        throw ApiException(d is Map && d['error'] != null ? '${d['error']}' : 'Erreur ${resp.statusCode}');
      }
      final lines = resp.stream.transform(utf8.decoder).transform(const LineSplitter());
      await for (final line in lines) {
        if (!line.startsWith('data:')) continue;
        final j = jsonDecode(line.substring(5).trim());
        if (j is Map<String, dynamic>) yield j;
      }
    } finally {
      client.close();
    }
  }
  static Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body);
  static Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body: body);
}
