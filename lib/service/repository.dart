import 'package:dartz/dartz.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nakshatra/config/db.dart';
import 'package:nakshatra/env/env.dart';
import 'package:nakshatra/model/api_error.dart';
import 'package:nakshatra/service/query.dart';
import 'package:nakshatra/utils/queue_manager.dart';

class Repository {
  static final Repository _instance = Repository._privateConstructor();
  Repository._privateConstructor();
  factory Repository() {
    return _instance;
  }
  static final Map<String, String> _headerMap = {
    'Content-Type': 'application/json',
  };
  late final HttpLink _httpLink = HttpLink(
    '${AppEnv.host}/graphql',
    defaultHeaders: _headerMap,
  );
  final AuthLink _authLink = AuthLink(
    getToken: () async {
      final token = await LocalDb.getAccessToken();
      if (token == null || token.trim().isEmpty) return null;
      final trimmedToken = token.trim();
      return trimmedToken.startsWith('Bearer ')
          ? trimmedToken
          : 'Bearer $trimmedToken';
    },
  );

  void setToken(String token) {
    // Deprecated: Token is now fetched from LocalDb automatically
  }

  void clearToken() {
    // Deprecated: Token is now fetched from LocalDb automatically
  }

  Future<Either<ApiError, T>> query<T>({
    required QueryRequest request,
    required T Function(Map<String, dynamic> data) parser,
  }) async {
    try {
      print("========== GRAPHQL REQUEST START ==========");
      print("Query:");
      print(request.query);
      print("Variables:");
      print(request.variables);

      final token = await LocalDb.getAccessToken();
      print("Token being sent: $token");

      Link link = _authLink.concat(_httpLink);

      var client = GraphQLClient(
        cache: GraphQLCache(partialDataPolicy: PartialDataCachePolicy.reject),
        link: link,
      );

      QueryResult data = await QueueManager().enqueueCall(client.query, [
        QueryOptions(
          fetchPolicy: FetchPolicy.noCache,
          cacheRereadPolicy: CacheRereadPolicy.ignoreAll,
          document: gql(request.query),
          variables: request.variables ?? {},
        ),
      ]);

      print("Has Exception: ${data.hasException}");
      print("Raw Response: ${data.data}");
      print("Exception: ${data.exception}");
      print("========== GRAPHQL REQUEST END ==========");

      if (data.hasException) {
        return Left(
          ApiError(
            code: 0,
            message: (data.exception?.graphqlErrors ?? []).isNotEmpty
                ? data.exception!.graphqlErrors.first.message
                : data.exception.toString(),
          ),
        );
      }

      if (data.data == null) {
        return Left(ApiError(code: 0, message: "No data found"));
      }

      return Right(parser(data.data!));
    } on Exception catch (e) {
      print("Exception caught: $e");
      return Left(ApiError(message: '$e', code: 0));
    }
  }
}
