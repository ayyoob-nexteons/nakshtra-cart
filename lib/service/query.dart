import 'package:json_annotation/json_annotation.dart';
part 'query.g.dart';

@JsonSerializable()
class QueryRequest {
  String query;
  dynamic variables;

  QueryRequest({required this.query, required this.variables});

  factory QueryRequest.fromJson(Map<String, dynamic> json) =>
      _$QueryRequestFromJson(json);

  Map<String, dynamic> toJson() => _$QueryRequestToJson(this);
}
