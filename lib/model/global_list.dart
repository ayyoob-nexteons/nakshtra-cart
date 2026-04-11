class GlobalList<T> {
  List<T>? list;
  int? totalCount;

  GlobalList({this.list, this.totalCount});

  // Factory method to deserialize

  factory GlobalList.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> item) parser,
  ) =>
      GlobalList<T>(
        list: (json['list'] as List<dynamic>?)?.map((item) {
          return parser(item);
        }).toList(),
        totalCount: json['totalCount'] as int?,
      );

  // Method to serialize
  Map<String, dynamic> toJson(Map<String, dynamic> listJson) =>
      <String, dynamic>{'list': listJson, 'totalCount': totalCount};
}

/*
Generic	Works with any model (User, Product, etc.)
fromJson	Parses JSON into list of objects
toJson	Converts list and total count back to JSON
Usage	Ideal for paginated API responses
*/
