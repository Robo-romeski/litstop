import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt_lib;
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// SecureStorage utility class for handling encrypted data storage
///
/// This class provides methods to securely store, retrieve, and manage sensitive information
/// using flutter_secure_storage with additional encryption layer
class SecureStorage {
  // Singleton instance
  static SecureStorage? _instance;

  // The secure storage instance
  final FlutterSecureStorage _secureStorage;

  // Encryption key (stored securely)
  encrypt_lib.Key? _encryptionKey;

  // IV for encryption
  final encrypt_lib.IV _iv = encrypt_lib.IV.fromLength(16);

  // Private constructor
  SecureStorage._() : _secureStorage = const FlutterSecureStorage();

  // Factory constructor for singleton pattern
  factory SecureStorage() {
    _instance ??= SecureStorage._();
    return _instance!;
  }

  /// Initialize the encryption key
  ///
  /// This should be called early in the app lifecycle
  Future<void> initialize() async {
    try {
      // Try to retrieve existing key
      final keyString = await _secureStorage.read(key: 'encryption_key');

      if (keyString != null) {
        // Use existing key
        final keyBytes = base64Decode(keyString);
        _encryptionKey = encrypt_lib.Key(Uint8List.fromList(keyBytes));
      } else {
        // Generate and store a new key
        await _generateAndStoreKey();
      }
    } catch (e) {
      debugPrint('Error initializing secure storage: $e');
      // Fallback: Generate a new key if error occurs
      await _generateAndStoreKey();
    }
  }

  /// Generate and store a new encryption key
  Future<void> _generateAndStoreKey() async {
    try {
      // Generate a random key
      final key = encrypt_lib.Key.fromSecureRandom(32);
      _encryptionKey = key;

      // Store the key securely
      await _secureStorage.write(
        key: 'encryption_key',
        value: base64Encode(key.bytes),
      );
    } catch (e) {
      debugPrint('Error generating encryption key: $e');
    }
  }

  /// Encrypt a string value
  String? encryptValue(String value) {
    if (_encryptionKey == null) {
      debugPrint('Encryption key not initialized');
      return null;
    }

    try {
      final encrypter = encrypt_lib.Encrypter(encrypt_lib.AES(_encryptionKey!));
      final encrypted = encrypter.encrypt(value, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      debugPrint('Error encrypting data: $e');
      return null;
    }
  }

  /// Decrypt an encrypted string
  String? decryptValue(String encryptedValue) {
    if (_encryptionKey == null) {
      debugPrint('Encryption key not initialized');
      return null;
    }

    try {
      final encrypter = encrypt_lib.Encrypter(encrypt_lib.AES(_encryptionKey!));
      final decrypted = encrypter.decrypt(
        encrypt_lib.Encrypted.fromBase64(encryptedValue),
        iv: _iv,
      );
      return decrypted;
    } catch (e) {
      debugPrint('Error decrypting data: $e');
      return null;
    }
  }

  /// Store a value securely
  ///
  /// Encrypts the value before storing it
  Future<void> writeSecure(String key, String value) async {
    final encryptedValue = encryptValue(value);
    if (encryptedValue != null) {
      await _secureStorage.write(key: key, value: encryptedValue);
    }
  }

  /// Retrieve a secure value
  ///
  /// Decrypts the value after retrieving it
  Future<String?> readSecure(String key) async {
    final encryptedValue = await _secureStorage.read(key: key);
    if (encryptedValue == null) return null;

    return decryptValue(encryptedValue);
  }

  /// Delete a secure value
  Future<void> deleteSecure(String key) async {
    await _secureStorage.delete(key: key);
  }

  /// Check if a secure value exists
  Future<bool> containsKey(String key) async {
    return await _secureStorage.containsKey(key: key);
  }

  /// Delete all secure values
  Future<void> deleteAll() async {
    await _secureStorage.deleteAll();
  }
}
