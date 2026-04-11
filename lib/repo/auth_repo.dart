import 'package:dartz/dartz.dart';
import 'package:nakshatra/model/api_error.dart';
import 'package:nakshatra/model/login_request/login_request.dart';
import 'package:nakshatra/model/login_response/login_response.dart';
import 'package:nakshatra/service/query.dart';
import 'package:nakshatra/service/repository.dart';

class AuthRepo {
  static Future<Either<ApiError, LoginResponse>> login(
    LoginRequest filter,
  ) async {
    final loginUser = <String, dynamic>{
      "password": filter.password,
      "email": filter.email,
    };

    var res = await Repository().query(
      request: QueryRequest(
        query: _AuthQuery.login,
        variables: {"loginUser": loginUser},
      ),
      parser: (data) {
        return LoginResponse.fromJson(data['User_Login']);
      },
    );
    return res.fold((left) => Left(left), (right) => Right(right));
  }
}

class _AuthQuery {
  static const String login =
      r'''mutation User_Login($loginUser: LoginUserInput!) {
  User_Login(loginUser: $loginUser) {
    accessToken
    refreshToken
    user {
      _email
      _id
      _name
      _status
      userBranchLinkings {
        _userType
        branchDetails {
          _address
          _name
          _id
        }
        _id
        _branchId
      }
    }
  }
}''';
}
