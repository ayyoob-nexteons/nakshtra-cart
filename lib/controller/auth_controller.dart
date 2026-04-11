import 'package:flutter/foundation.dart';
import 'package:nakshatra/config/db.dart';
import 'package:nakshatra/model/login_request/login_request.dart';
import 'package:nakshatra/model/login_response/login_response.dart';
import 'package:nakshatra/repo/auth_repo.dart';

class AuthController extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setError(null);
    _setLoading(true);
    try {
      final res = await AuthRepo.login(
        LoginRequest(email: email.trim(), password: password),
      );

      return await res.fold((err) async {
        _setError(err.message);
        return false;
      }, (LoginResponse data) async {
        final accessToken = data.accessToken ?? '';
        final refreshToken = data.refreshToken ?? '';
        final user = data.user;

        if (accessToken.trim().isEmpty ||
            refreshToken.trim().isEmpty ||
            user == null) {
          _setError('Invalid login response');
          return false;
        }

        await LocalDb.saveAccessToken(accessToken);
        await LocalDb.saveRefreshToken(refreshToken);
        await LocalDb.saveUser(user);
        await LocalDb.saveUserBranchLinkings(user.userBranchLinkings ?? []);
        await LocalDb.setLoggedIn(true);
        return true;
      });
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await LocalDb.logout();
    notifyListeners();
  }
}
