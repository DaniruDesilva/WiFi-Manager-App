/// Data model for a default router credential entry.
class RouterCredential {
  final String brand;
  final List<String> models;
  final String defaultUsername;
  final String defaultPassword;
  final String? defaultLoginUrl;

  RouterCredential({
    required this.brand,
    required this.models,
    required this.defaultUsername,
    required this.defaultPassword,
    this.defaultLoginUrl,
  });

  factory RouterCredential.fromJson(Map<String, dynamic> json) {
    return RouterCredential(
      brand: json['brand'] ?? '',
      models: (json['models'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      defaultUsername: json['username'] ?? '',
      defaultPassword: json['password'] ?? '',
      defaultLoginUrl: json['loginUrl'],
    );
  }

  /// Returns a comma-separated string of models for display.
  String get modelsDisplay => models.join(', ');
}
