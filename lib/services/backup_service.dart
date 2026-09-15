import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import '../models/wifi_network.dart';

class BackupService {
  /// Generates a 32-byte key from the user-provided password using SHA-256
  static encrypt.Key _generateKey(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return encrypt.Key(Uint8List.fromList(digest.bytes));
  }

  /// Encrypts the list of networks and returns the encrypted base64 string
  static String encryptBackup(List<WifiNetwork> networks, String password) {
    final key = _generateKey(password);
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    final jsonString = jsonEncode(networks.map((e) => e.toJson()).toList());
    final encrypted = encrypter.encrypt(jsonString, iv: iv);

    // Store IV along with the ciphertext so we can decrypt it later
    final payload = {
      'iv': iv.base64,
      'data': encrypted.base64,
    };
    return jsonEncode(payload);
  }

  /// Decrypts the backup payload and returns the list of networks
  static List<WifiNetwork> decryptBackup(String payloadStr, String password) {
    try {
      final key = _generateKey(password);
      final payload = jsonDecode(payloadStr);
      final iv = encrypt.IV.fromBase64(payload['iv']);
      final encryptedData = encrypt.Encrypted.fromBase64(payload['data']);

      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final decryptedJsonString = encrypter.decrypt(encryptedData, iv: iv);

      final List<dynamic> jsonList = jsonDecode(decryptedJsonString);
      return jsonList.map((e) => WifiNetwork.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Invalid password or corrupted backup file.');
    }
  }

  /// Creates a backup file in the temporary directory and returns its path
  static Future<String> createBackupFile(List<WifiNetwork> networks, String password) async {
    final encryptedPayload = encryptBackup(networks, password);
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${tempDir.path}/wifi_backup_$timestamp.json');
    await file.writeAsString(encryptedPayload);
    return file.path;
  }
}
