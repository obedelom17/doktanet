import 'package:flutter/foundation.dart';
import 'api.dart';

class Session extends ChangeNotifier {
  Map<String, dynamic>? user;
  bool loading = true;

  Future<void> init() async {
    await Api.load();
    if (Api.token != null) {
      try {
        await refresh();
      } catch (_) {
        await Api.setToken(null);
        user = null;
      }
    }
    loading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    user = Map<String, dynamic>.from(await Api.get('/me') as Map);
    notifyListeners();
  }

  /// Retourne true si un code 2FA est demandé (rappeler avec [code]).
  Future<bool> login(String email, String password, {String? code}) async {
    final r = await Api.post('/auth/login', {
      'email': email,
      'password': password,
      if (code != null && code.isNotEmpty) 'code': code,
    });
    if (r['need_2fa'] == true) return true;
    await Api.setToken(r['token'] as String);
    await refresh();
    return false;
  }

  Future<void> register(Map<String, dynamic> data) async {
    final r = await Api.post('/auth/register', data);
    await Api.setToken(r['token'] as String);
    await refresh();
  }

  Future<void> logout() async {
    await Api.setToken(null);
    user = null;
    notifyListeners();
  }
}

final session = Session();
