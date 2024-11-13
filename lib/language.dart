class Language {
  final String code;
  final String name;

  const Language({required this.code, required this.name});

  factory Language.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'language' : String code,
        'name' : String name,
      } => Language(
        code: code,
        name: name,
      ),
      _ => throw const FormatException('Invalid Language.fromJson()'),
    };
  }

  @override
  int get hashCode => code.hashCode;

  @override
  bool operator ==(Object other) {
    return other is Language && other.code == code;
  }
}
