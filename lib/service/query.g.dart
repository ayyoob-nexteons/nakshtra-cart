// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'query.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QueryRequest _$QueryRequestFromJson(Map<String, dynamic> json) => QueryRequest(
      query: json['query'] as String,
      variables: json['variables'],
    );

Map<String, dynamic> _$QueryRequestToJson(QueryRequest instance) =>
    <String, dynamic>{
      'query': instance.query,
      'variables': instance.variables,
    };
