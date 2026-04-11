import 'package:json_annotation/json_annotation.dart';

import 'user_branch_linking.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  @JsonKey(name: '_email')
  String? email;
  @JsonKey(name: '_id')
  String? id;
  @JsonKey(name: '_name')
  String? name;
  @JsonKey(name: '_status')
  int? status;
  List<UserBranchLinking>? userBranchLinkings;

  User({
    this.email,
    this.id,
    this.name,
    this.status,
    this.userBranchLinkings,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  Map<String, dynamic> toJson() => _$UserToJson(this);
}
