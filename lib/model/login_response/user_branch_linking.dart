import 'package:json_annotation/json_annotation.dart';

import 'branch_details.dart';

part 'user_branch_linking.g.dart';

@JsonSerializable()
class UserBranchLinking {
  @JsonKey(name: '_userType')
  int? userType;
  BranchDetails? branchDetails;
  @JsonKey(name: '_id')
  String? id;
  @JsonKey(name: '_branchId')
  String? branchId;

  UserBranchLinking({
    this.userType,
    this.branchDetails,
    this.id,
    this.branchId,
  });

  factory UserBranchLinking.fromJson(Map<String, dynamic> json) {
    return _$UserBranchLinkingFromJson(json);
  }

  Map<String, dynamic> toJson() => _$UserBranchLinkingToJson(this);
}
