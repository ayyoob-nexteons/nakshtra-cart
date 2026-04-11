import 'package:json_annotation/json_annotation.dart';

import 'user.dart';

part 'login_response.g.dart';

@JsonSerializable()
class LoginResponse {
  String? accessToken;
  String? refreshToken;
  User? user;

  LoginResponse({this.accessToken, this.refreshToken, this.user});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return _$LoginResponseFromJson(json);
  }

  Map<String, dynamic> toJson() => _$LoginResponseToJson(this);
}
