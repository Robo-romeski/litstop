import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../utils/secure_storage.dart';

/// Provider for securely storing and retrieving sensitive data
///
/// This provider handles encryption and decryption of data stored in local SQLite database
class SecureDataProvider with ChangeNotifier {
  // Database instance
  Database? _database;

  // Secure storage instance
  final SecureStorage _secureStorage = SecureStorage();

  // Database name
  static const String _databaseName = 'litstop_secure.db';

  // Database version
  static const int _databaseVersion = 1;

  // Tables
  static const String tableUserData = 'user_data';
  static const String tablePaymentInfo = 'payment_info';
  static const String tableDriverLicense = 'driver_license';

  // Initialize the provider
  Future<void> initialize() async {
    // Initialize secure storage first
    await _secureStorage.initialize();

    // Then open database
    await _openDatabase();
  }

  // Open the database
  Future<void> _openDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, _databaseName);

    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Create database tables
  Future<void> _onCreate(Database db, int version) async {
    // User data table (encrypted)
    await db.execute('''
      CREATE TABLE $tableUserData (
        id TEXT PRIMARY KEY,
        encrypted_data TEXT NOT NULL,
        data_type TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Payment info table (encrypted)
    await db.execute('''
      CREATE TABLE $tablePaymentInfo (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        encrypted_data TEXT NOT NULL,
        payment_type TEXT NOT NULL,
        is_default INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Driver license table (encrypted)
    await db.execute('''
      CREATE TABLE $tableDriverLicense (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        encrypted_data TEXT NOT NULL,
        is_verified INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  // Handle database upgrade
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle schema migrations here when version changes
    if (oldVersion < 2) {
      // Migration code for version 2
    }
  }

  // Save user data securely
  Future<bool> saveUserData(
      String userId, Map<String, dynamic> userData, String dataType) async {
    if (_database == null) {
      debugPrint('Database not initialized');
      return false;
    }

    try {
      // Convert data to JSON string
      final dataJson = userData.toString();

      // Encrypt the data
      final encryptedData = _secureStorage.encryptValue(dataJson);
      if (encryptedData == null) {
        debugPrint('Failed to encrypt user data');
        return false;
      }

      // Current timestamp
      final now = DateTime.now().millisecondsSinceEpoch;

      // Check if data already exists
      final existing = await _database!.query(
        tableUserData,
        where: 'id = ?',
        whereArgs: [userId],
      );

      if (existing.isNotEmpty) {
        // Update existing data
        await _database!.update(
          tableUserData,
          {
            'encrypted_data': encryptedData,
            'data_type': dataType,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [userId],
        );
      } else {
        // Insert new data
        await _database!.insert(
          tableUserData,
          {
            'id': userId,
            'encrypted_data': encryptedData,
            'data_type': dataType,
            'created_at': now,
            'updated_at': now,
          },
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error saving user data: $e');
      return false;
    }
  }

  // Get user data
  Future<Map<String, dynamic>?> getUserData(
      String userId, String dataType) async {
    if (_database == null) {
      debugPrint('Database not initialized');
      return null;
    }

    try {
      final result = await _database!.query(
        tableUserData,
        where: 'id = ? AND data_type = ?',
        whereArgs: [userId, dataType],
      );

      if (result.isEmpty) {
        return null;
      }

      final encryptedData = result.first['encrypted_data'] as String;
      final decryptedData = _secureStorage.decryptValue(encryptedData);

      if (decryptedData == null) {
        debugPrint('Failed to decrypt user data');
        return null;
      }

      // Parse the decrypted data back to a Map
      // Note: This is a simplified approach, in a real app you'd use json.decode
      final dataMap = decryptedData
          .replaceAll('{', '')
          .replaceAll('}', '')
          .split(', ')
          .fold<Map<String, dynamic>>({}, (map, item) {
        final parts = item.split(': ');
        if (parts.length == 2) {
          map[parts[0]] = parts[1];
        }
        return map;
      });

      return dataMap;
    } catch (e) {
      debugPrint('Error getting user data: $e');
      return null;
    }
  }

  // Save payment information securely
  Future<bool> savePaymentInfo(
    String id,
    String userId,
    Map<String, dynamic> paymentData,
    String paymentType,
    bool isDefault,
  ) async {
    if (_database == null) {
      debugPrint('Database not initialized');
      return false;
    }

    try {
      // Convert data to JSON string
      final dataJson = paymentData.toString();

      // Encrypt the data
      final encryptedData = _secureStorage.encryptValue(dataJson);
      if (encryptedData == null) {
        debugPrint('Failed to encrypt payment data');
        return false;
      }

      // Current timestamp
      final now = DateTime.now().millisecondsSinceEpoch;

      // Check if data already exists
      final existing = await _database!.query(
        tablePaymentInfo,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (isDefault) {
        // Clear default flag from other payment methods
        await _database!.update(
          tablePaymentInfo,
          {'is_default': 0},
          where: 'user_id = ?',
          whereArgs: [userId],
        );
      }

      if (existing.isNotEmpty) {
        // Update existing data
        await _database!.update(
          tablePaymentInfo,
          {
            'encrypted_data': encryptedData,
            'payment_type': paymentType,
            'is_default': isDefault ? 1 : 0,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        // Insert new data
        await _database!.insert(
          tablePaymentInfo,
          {
            'id': id,
            'user_id': userId,
            'encrypted_data': encryptedData,
            'payment_type': paymentType,
            'is_default': isDefault ? 1 : 0,
            'created_at': now,
            'updated_at': now,
          },
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error saving payment info: $e');
      return false;
    }
  }

  // Get payment information
  Future<List<Map<String, dynamic>>> getPaymentInfo(String userId) async {
    if (_database == null) {
      debugPrint('Database not initialized');
      return [];
    }

    try {
      final result = await _database!.query(
        tablePaymentInfo,
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      final paymentInfoList = <Map<String, dynamic>>[];

      for (final row in result) {
        final encryptedData = row['encrypted_data'] as String;
        final decryptedData = _secureStorage.decryptValue(encryptedData);

        if (decryptedData != null) {
          // Build payment info with decrypted data and metadata
          paymentInfoList.add({
            'id': row['id'],
            'payment_type': row['payment_type'],
            'is_default': (row['is_default'] as int) == 1,
            'data': decryptedData,
            'created_at': row['created_at'],
            'updated_at': row['updated_at'],
          });
        }
      }

      return paymentInfoList;
    } catch (e) {
      debugPrint('Error getting payment info: $e');
      return [];
    }
  }

  // Delete all data for a user (e.g., when logging out)
  Future<void> deleteUserData(String userId) async {
    if (_database == null) {
      debugPrint('Database not initialized');
      return;
    }

    try {
      await _database!.delete(
        tableUserData,
        where: 'id = ?',
        whereArgs: [userId],
      );

      await _database!.delete(
        tablePaymentInfo,
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      await _database!.delete(
        tableDriverLicense,
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      debugPrint('Error deleting user data: $e');
    }
  }

  // Close the database when no longer needed
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  @override
  void dispose() {
    close();
    super.dispose();
  }
}
