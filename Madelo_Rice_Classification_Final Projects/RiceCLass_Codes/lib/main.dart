import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'camera_service.dart';
import 'rice_classifier_service.dart';
import 'firebase_service.dart';
import 'home_screen.dart';
import 'analytics_screen.dart';

void main() {
  runApp(const RiceClassifierApp());
}

class RiceClassifierApp extends StatelessWidget {
  const RiceClassifierApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rice Classifier',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const WelcomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const HomeScreen(),
      const CameraScreen(),
      const AnalyticsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Camera',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            label: 'Analytics',
          ),
        ],
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/rice_bg.jpeg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xCC2E7D32), // dark green
                Color(0xCC66BB6A), // light green
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 40.0),
                  child: Column(
                    children: [
                      Text(
                        'Welcome to',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Rice Classifier',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Capture. Classify. Analyze.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Use your camera to identify rice varieties and see detailed analytics of all your captures.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF2E7D32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const MainNavigation()),
                        );
                      },
                      child: const Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final CameraService _cameraService = CameraService();
  final RiceClassifierService _classifierService = RiceClassifierService();
  final FirebaseService _firebaseService = FirebaseService.instance;
  final ImagePicker _imagePicker = ImagePicker();
  
  bool _isCameraInitialized = false;
  bool _isModelLoaded = false;
  bool _isFirebaseInitialized = false;
  bool _isProcessing = false;
  String? _lastImageSource; // Track if last image was from Camera or Gallery
  bool _cameraInitFailed = false;
  String? _cameraError;
  RiceClassificationResult? _lastResult;
  String? _capturedImagePath;
  String? _userId;
  Map<String, int> _classCounts = {};
  int _totalClassifications = 0;
  double _averageConfidence = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize Firebase
      await _firebaseService.initializeFirebase();
      setState(() {
        _isFirebaseInitialized = true;
      });

      // Sign in anonymously
      final cameraInitializationFuture = _cameraService.initializeCamera();
      final modelLoadFuture = _classifierService.loadModel();

      String? userId = await _firebaseService.signInAnonymously();
      if (userId != null) {
        setState(() {
          _userId = userId;
        });
        _loadAnalytics();
      }

      // Initialize camera
      await cameraInitializationFuture;
      setState(() {
        _isCameraInitialized = true;
        _cameraInitFailed = false;
        _cameraError = null;
      });

      // Load ML model
      await modelLoadFuture;
      setState(() {
        _isModelLoaded = true;
      });
    } catch (e) {
      print('Initialization error: $e');
      if (e.toString().contains('Camera')) {
        setState(() {
          _cameraInitFailed = true;
          _cameraError = e.toString();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Initialization failed: $e')),
        );
      }
    }
  }

  Future<void> _loadAnalytics() async {
    if (_userId == null) return;

    try {
      const timeout = Duration(seconds: 8);
      final history = await _firebaseService.getClassificationHistory(_userId!)
          .timeout(timeout, onTimeout: () {
        throw Exception('Analytics loading timed out. Please check your connection and try again.');
      });

      final Map<String, int> counts = {};
      double totalConfidence = 0.0;
      int total = 0;

      for (var doc in history) {
        try {
          final data = doc.data();
          if (data == null) continue;

          final className = (data['className'] ?? '').toString();
          if (className.isEmpty) continue;

          final confidenceRaw = data['confidence'];
          final confidence = confidenceRaw is num ? confidenceRaw.toDouble() : 0.0;

          counts[className] = (counts[className] ?? 0) + 1;
          total++;
          totalConfidence += confidence;
        } catch (_) {
          // Ignore malformed documents
        }
      }

      setState(() {
        _classCounts = counts;
        _totalClassifications = total;
        _averageConfidence = total > 0 ? totalConfidence / total : 0.0;
      });
    } catch (e) {
      print('Failed to load analytics: $e');
      // Optionally show a snackbar for analytics failure
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Analytics failed to load: $e')),
      );
    }
  }

  Future<void> _retryCameraInit() async {
    setState(() {
      _cameraInitFailed = false;
      _cameraError = null;
    });
    try {
      await _cameraService.initializeCamera();
      setState(() {
        _isCameraInitialized = true;
        _cameraInitFailed = false;
        _cameraError = null;
      });
    } catch (e) {
      setState(() {
        _cameraInitFailed = true;
        _cameraError = e.toString();
      });
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _capturedImagePath = null;
      _lastResult = null;
    });

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (pickedFile == null) {
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      setState(() {
        _capturedImagePath = pickedFile.path;
      });

      // Classify immediately after selection
      File imageFile = File(pickedFile.path);
      Uint8List imageBytes = await imageFile.readAsBytes();
      RiceClassificationResult result = _classifierService.classifyImage(imageBytes);
      
      setState(() {
        _lastResult = result;
        _lastImageSource = 'Gallery';
      });
      
      // Note: Result will be saved when user clicks submit button
    } catch (e) {
      print('Gallery selection or classification error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to process image: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _captureOnly() async {
    if (!_isCameraInitialized || _cameraService.controller == null || _isProcessing) {
      print('Cannot capture: Camera not ready or already processing');
      return;
    }

    setState(() {
      _isProcessing = true;
      _capturedImagePath = null;
      _lastResult = null;
    });

    try {
      String? imagePath = await _cameraService.captureImage();
      if (imagePath == null) {
        throw Exception('Failed to capture image - camera returned null path');
      }

      setState(() {
        _capturedImagePath = imagePath;
      });

      // Classify immediately after capture
      File imageFile = File(imagePath);
      Uint8List imageBytes = await imageFile.readAsBytes();
      RiceClassificationResult result = _classifierService.classifyImage(imageBytes);
      
      setState(() {
        _lastResult = result;
        _lastImageSource = 'Camera';
      });
      
      // Note: Result will be saved when user clicks submit button
    } catch (e) {
      print('Capture or classification error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Capture failed: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _submitOnly() async {
    if (_capturedImagePath == null || _lastResult == null || 
        !_isFirebaseInitialized || 
        _isProcessing) {
      print('Cannot submit: No captured image/result or services not ready');
      return;
    }

    // Ensure we have a valid userId
    String? userId = _userId;
    if (userId == null) {
      // Try to read the current FirebaseAuth user first
      final existingId = _firebaseService.getCurrentUserId();
      if (existingId != null) {
        userId = existingId;
        setState(() {
          _userId = userId;
        });
      } else {
        // Fallback: attempt anonymous sign-in now
        userId = await _firebaseService.signInAnonymously();
        if (userId != null) {
          setState(() {
            _userId = userId;
          });
        } else {
          print('Cannot submit: failed to obtain userId even after sign-in attempt');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Submit failed: could not sign in to Firebase')),
          );
          return;
        }
      }
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Save classification result to Firestore (only metadata, no image)
      await _firebaseService.saveClassificationResult(_lastResult!, userId, imageSource: _lastImageSource ?? 'Unknown');
      print('Result saved to Firestore');
      
      await _loadAnalytics();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Classification saved to cloud!')),
      );
    } catch (e) {
      print('Submit error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submit failed: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  
  @override
  void dispose() {
    _cameraService.dispose();
    _classifierService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full screen camera preview
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/rice_bg.jpeg'),
                fit: BoxFit.cover,
              ),
            ),
            child: _buildCameraPreview(),
          ),
          // Top header overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Text(
                    'Rice Classifier',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Bottom controls overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Classification results (if available)
                  if (_lastResult != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Result: ${_lastResult!.className}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'Accuracy: ${(_lastResult!.confidence * 100).toStringAsFixed(2)}%',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            'Time: ${_formatDateTime(_lastResult!.timestamp)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Capture/Submit/Gallery buttons
                  _buildCaptureButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraInitFailed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.white),
              const SizedBox(height: 16),
              const Text(
                'Camera unavailable',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                _cameraError ?? 'Unknown camera error',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _retryCameraInit,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isCameraInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Initializing Camera...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Please ensure Camera permission is granted',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_capturedImagePath != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(_capturedImagePath!),
            fit: BoxFit.cover,
          ),
          // Show full-screen processing overlay only while we don't yet have a result
          if (_isProcessing && _lastResult == null)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Processing...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    // Safe live camera preview (avoid null controller / preview size)
    final controller = _cameraService.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: Text(
          'Camera preview not available',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return SizedBox.expand(
      child: CameraPreview(controller),
    );
  }

  Widget _buildResultsPanel() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_lastResult == null) ...[
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.camera_alt_outlined,
                  size: 48,
                  color: Colors.grey,
                ),
                SizedBox(height: 8),
                Text(
                  'No classification yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Capture an image to start',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ] else ...[
            const Text(
              'Classification Result',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            _buildResultRow('Class:', _lastResult!.className),
            const SizedBox(height: 8),
            _buildResultRow('Accuracy:', '${(_lastResult!.confidence * 100).toStringAsFixed(2)}%'),
            const SizedBox(height: 8),
            _buildResultRow('Time:', _formatDateTime(_lastResult!.timestamp)),
            const SizedBox(height: 16),
            const Text(
              'Analytics',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            _buildResultRow('Total:', '$_totalClassifications images'),
            const SizedBox(height: 8),
            _buildResultRow(
              'Avg Acc.:',
              _totalClassifications > 0
                  ? '${(_averageConfidence * 100).toStringAsFixed(2)}%'
                  : '-',
            ),
            const SizedBox(height: 12),
            const Text(
              'Class legend',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            _buildClassLegend(),
          ],
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClassLegend() {
    if (_classCounts.isEmpty) {
      return const Text(
        'No captured data yet',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      );
    }

    final List<Color> colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.brown,
    ];

    final entries = _classCounts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < entries.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors[i % colors.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${entries[i].key}: ${entries[i].value}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCaptureButtons() {
    if (_capturedImagePath != null) {
      // Show Submit and Retake buttons when an image is captured/selected
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _submitOnly,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.cloud_upload, size: 24),
                label: Text(
                  _isProcessing ? 'Processing...' : 'Submit',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 6,
                  shadowColor: Colors.green.withOpacity(0.4),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : () {
                  setState(() {
                    _capturedImagePath = null;
                    _lastResult = null;
                  });
                },
                icon: const Icon(Icons.refresh, size: 24),
                label: const Text(
                  'Retake',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 6,
                  shadowColor: Colors.orange.withOpacity(0.4),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Show Capture and Gallery buttons when no image is selected yet
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          // Regular capture and gallery buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_isCameraInitialized && _cameraService.controller != null && !_isProcessing)
                      ? _captureOnly
                      : null,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.camera_alt, size: 24),
                  label: Text(
                    _isProcessing ? 'Capturing...' : 'Camera',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 6,
                    shadowColor: Colors.green.withOpacity(0.4),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _pickFromGallery,
                  icon: const Icon(Icons.photo_library, size: 24),
                  label: const Text(
                    'Gallery',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 6,
                    shadowColor: Colors.blue.withOpacity(0.4),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:' '${dateTime.minute.toString().padLeft(2, '0')}:' '${dateTime.second.toString().padLeft(2, '0')}';
  }
}
