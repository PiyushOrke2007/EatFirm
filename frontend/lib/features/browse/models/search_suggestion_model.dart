/// Search suggestion returned for auto-complete (SRS BROWSE-2, NFR-4).
class SearchSuggestionModel {
  final String type; // 'restaurant' | 'dish' | 'cuisine'
  final String text;
  final String? subtext;
  final String? id;

  const SearchSuggestionModel({
    required this.type,
    required this.text,
    this.subtext,
    this.id,
  });

  factory SearchSuggestionModel.fromJson(Map<String, dynamic> json) {
    return SearchSuggestionModel(
      type: (json['type'] ?? 'restaurant').toString(),
      text: (json['text'] ?? '').toString(),
      subtext: json['subtext']?.toString(),
      id: json['id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'text': text,
      'subtext': subtext,
      'id': id,
    };
  }
}

