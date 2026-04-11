import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nakshatra/model/login_response/user.dart';
import 'package:nakshatra/model/login_response/user_branch_linking.dart';

class LocalDb {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // ==========================
  // 🔑 Keys
  // ==========================

  static const String _accessTokenKey = "accessToken";
  static const String _refreshTokenKey = "refreshToken";
  static const String _userKey = "userData";
  static const String _userBranchLinkingsKey = "userBranchLinkings";
  static const String _isLoggedInKey = "isLoggedIn";

  // ==========================
  // 🔐 ACCESS TOKEN
  // ==========================

  static Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  static Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  // ==========================
  // 🔄 REFRESH TOKEN
  // ==========================

  static Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  // ==========================
  // 👤 USER DATA
  // ==========================

  static Future<void> saveUser(User user) async {
    final jsonString = jsonEncode(user.toJson());
    await _storage.write(key: _userKey, value: jsonString);
  }

  static Future<User?> getUser() async {
    final jsonString = await _storage.read(key: _userKey);
    if (jsonString == null) return null;
    return User.fromJson(jsonDecode(jsonString));
  }

  // ==========================
  // 🏢 USER BRANCH LINKINGS
  // ==========================

  static Future<void> saveUserBranchLinkings(
    List<UserBranchLinking> linkings,
  ) async {
    final jsonList = linkings.map((e) => e.toJson()).toList();
    await _storage.write(
        key: _userBranchLinkingsKey, value: jsonEncode(jsonList));
  }

  static Future<List<UserBranchLinking>> getUserBranchLinkings() async {
    final jsonString = await _storage.read(key: _userBranchLinkingsKey);
    if (jsonString == null || jsonString.trim().isEmpty) return [];
    final decoded = jsonDecode(jsonString);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(UserBranchLinking.fromJson)
        .toList();
  }

  // ==========================
  // ✅ LOGIN STATUS
  // ==========================

  static Future<void> setLoggedIn(bool value) async {
    await _storage.write(key: _isLoggedInKey, value: value.toString());
  }

  static Future<bool> isLoggedIn() async {
    final value = await _storage.read(key: _isLoggedInKey);
    return value == "true";
  }

  // ==========================
  // 🚪 LOGOUT / CLEAR
  // ==========================

  static Future<void> logout() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _userBranchLinkingsKey);
    await _storage.delete(key: _isLoggedInKey);
  }
}
