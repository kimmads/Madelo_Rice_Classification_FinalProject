import 'dart:typed_data';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'rice_classifier_service.dart';

class FirebaseService {
  static FirebaseService? _instance;
  static FirebaseService get instance => _instance ??= FirebaseService._();
  
  FirebaseService._();
  
  bool _isInitialized = false;
  String? _currentUserId;
  final List<Map<String, dynamic>> _mockData = [];
  static const String _mockDataKey = 'mock_classification_data';
  static const String _userIdKey = 'current_user_id';
  
  Future<void> initializeFirebase() async {
    try {
      if (_isInitialized) {
        return;
      }

      // Mock Firebase initialization
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Load persisted data from local storage
      await _loadPersistedData();
      
      _isInitialized = true;
      
      // Auto-generate a mock user for testing if none exists
      if (_currentUserId == null) {
        _currentUserId = 'mock_user_${DateTime.now().millisecondsSinceEpoch}';
        await _saveUserId();
      }
      
      // Add some test data for immediate verification
      _addTestData();
      
      print('Mock Firebase initialized successfully with user: $_currentUserId');
      print('Loaded ${_mockData.length} persisted classification records');
      
    } catch (e) {
      print('Failed to initialize Firebase: $e');
      throw Exception('Firebase initialization failed');
    }
  }
  
  Future<void> _loadPersistedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load user ID
      _currentUserId = prefs.getString(_userIdKey);
      
      // Load classification data
      final dataString = prefs.getString(_mockDataKey);
      if (dataString != null && dataString.isNotEmpty) {
        final List<dynamic> decodedData = json.decode(dataString);
        _mockData.clear();
        
        // Convert string dates back to DateTime objects
        for (final item in decodedData) {
          final Map<String, dynamic> dataItem = Map<String, dynamic>.from(item);
          if (dataItem['timestamp'] is String) {
            dataItem['timestamp'] = DateTime.parse(dataItem['timestamp'] as String);
          }
          if (dataItem['createdAt'] is String) {
            dataItem['createdAt'] = DateTime.parse(dataItem['createdAt'] as String);
          }
          _mockData.add(dataItem);
        }
        
        print('Loaded ${_mockData.length} classification records from local storage');
      }
    } catch (e) {
      print('Error loading persisted data: $e');
      // Start with empty data if loading fails
      _mockData.clear();
    }
  }
  
  Future<void> _savePersistedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convert DateTime objects to strings for JSON serialization
      final serializableData = _mockData.map((item) {
        final newItem = Map<String, dynamic>.from(item);
        // Convert DateTime objects to ISO strings
        if (newItem['timestamp'] is DateTime) {
          newItem['timestamp'] = (newItem['timestamp'] as DateTime).toIso8601String();
        }
        if (newItem['createdAt'] is DateTime) {
          newItem['createdAt'] = (newItem['createdAt'] as DateTime).toIso8601String();
        }
        return newItem;
      }).toList();
      
      await prefs.setString(_mockDataKey, json.encode(serializableData));
      print('Saved ${_mockData.length} classification records to local storage');
    } catch (e) {
      print('Error saving persisted data: $e');
    }
  }
  
  Future<void> _saveUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentUserId != null) {
        await prefs.setString(_userIdKey, _currentUserId!);
        print('Saved user ID to local storage: $_currentUserId');
      }
    } catch (e) {
      print('Error saving user ID: $e');
    }
  }
  
  void _addTestData() {
    // No test data - start with clean slate for user scanning
    print('Starting with no test data - user will scan samples');
  }
  
  Future<String> uploadImageToStorage(Uint8List imageBytes, String fileName) async {
    // Mock upload
    await Future.delayed(const Duration(seconds: 1));
    return 'https://mock-url.com/$fileName';
  }
  
  Future<void> saveClassificationResult(
    RiceClassificationResult result,
    String userId,
    {String imageSource = 'Unknown'}
  ) async {
    // Mock save to Firestore
    await Future.delayed(const Duration(milliseconds: 500));
    
    _mockData.add({
      'className': result.className,
      'confidence': result.confidence,
      'timestamp': result.timestamp,
      'imageSource': imageSource,
      'userId': userId,
      'createdAt': DateTime.now(),
    });
    
    // Save to persistent storage
    await _savePersistedData();
    
    print('Mock classification result saved: ${result.className} with ${(result.confidence * 100).toStringAsFixed(2)}% confidence from $imageSource');
    print('Total results in storage: ${_mockData.length}');
  }
  
  Future<List<DocumentSnapshot>> getClassificationHistory(String userId) async {
    // Mock query
    await Future.delayed(const Duration(milliseconds: 800));
    
    final userDocs = _mockData.where((doc) => doc['userId'] == userId).toList();
    
    print('Querying for userId: $userId');
    print('Found ${userDocs.length} documents for this user');
    print('Total mock data entries: ${_mockData.length}');
    
    return userDocs.map((data) => MockDocumentSnapshot(data)).toList();
  }
  
  Future<String?> signInAnonymously() async {
    try {
      // Mock anonymous sign-in
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Only generate new user ID if one doesn't already exist
      if (_currentUserId == null) {
        _currentUserId = 'mock_user_${DateTime.now().millisecondsSinceEpoch}';
        await _saveUserId();
        print('Generated new user ID: $_currentUserId');
      } else {
        print('Using existing user ID: $_currentUserId');
      }
      
      return _currentUserId;
    } catch (e) {
      print('Anonymous sign-in error: $e');
      return null;
    }
  }
  
  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userIdKey); // Clear persisted user ID
      _currentUserId = null;
      print('Mock signed out successfully and cleared saved user ID');
    } catch (e) {
      print('Error during sign out: $e');
      _currentUserId = null;
    }
  }
  
  String? getCurrentUserId() {
    return _currentUserId;
  }
  
  Future<void> clearAllClassifications(String userId) async {
    // Mock clear all data for user
    await Future.delayed(const Duration(milliseconds: 500));
    
    final userDocs = _mockData.where((doc) => doc['userId'] == userId).toList();
    _mockData.removeWhere((doc) => doc['userId'] == userId);
    
    // Save to persistent storage
    await _savePersistedData();
    
    print('Cleared ${userDocs.length} classification results for user $userId');
    print('Remaining mock data entries: ${_mockData.length}');
  }

  bool isUserSignedIn() {
    return _currentUserId != null;
  }
}

// Mock classes for Firebase types
class MockDocumentSnapshot implements DocumentSnapshot {
  final Map<String, dynamic> _data;
  
  MockDocumentSnapshot(this._data);
  
  @override
  Map<String, dynamic>? data() => _data;
  
  @override
  String get id => 'mock_doc_${DateTime.now().millisecondsSinceEpoch}';
  
  // Implement other required methods with mock behavior
  @override
  DocumentReference get reference => throw UnimplementedError();
  
  @override
  SnapshotMetadata get metadata => throw UnimplementedError();
  
  @override
  bool get exists => true;
}

abstract class DocumentSnapshot {
  Map<String, dynamic>? data();
  String get id;
  DocumentReference get reference;
  SnapshotMetadata get metadata;
  bool get exists;
}

class DocumentReference {}
class SnapshotMetadata {}
