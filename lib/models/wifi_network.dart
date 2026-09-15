class WifiNetwork {
  final String ssid;
  final String password;
  final String securityType;
  final bool isHidden;
  final DateTime timestamp;
  
  // Customization fields
  final String? qrColorHex;
  final bool isSquareDots;
  final bool isSquareEyes;
  final bool useLogo;
  final String? category;

  WifiNetwork({
    required this.ssid,
    this.password = '',
    this.securityType = 'WPA',
    this.isHidden = false,
    DateTime? timestamp,
    this.qrColorHex,
    this.isSquareDots = true,
    this.isSquareEyes = true,
    this.useLogo = false,
    this.category,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'ssid': ssid,
        'password': password,
        'securityType': securityType,
        'isHidden': isHidden,
        'timestamp': timestamp.toIso8601String(),
        'qrColorHex': qrColorHex,
        'isSquareDots': isSquareDots,
        'isSquareEyes': isSquareEyes,
        'useLogo': useLogo,
        'category': category,
      };

  factory WifiNetwork.fromJson(Map<String, dynamic> json) {
    return WifiNetwork(
      ssid: json['ssid'] ?? '',
      password: json['password'] ?? '',
      securityType: json['securityType'] ?? 'WPA',
      isHidden: json['isHidden'] ?? false,
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : null,
      qrColorHex: json['qrColorHex'],
      isSquareDots: json['isSquareDots'] ?? true,
      isSquareEyes: json['isSquareEyes'] ?? true,
      useLogo: json['useLogo'] ?? false,
      category: json['category'],
    );
  }

  String get qrData {
    String formattedQrData = 'WIFI:S:$ssid;T:$securityType;';
    if (securityType != 'nopass') {
      formattedQrData += 'P:$password;';
    }
    if (isHidden) {
      formattedQrData += 'H:true;';
    }
    formattedQrData += ';';
    return formattedQrData;
  }
}
