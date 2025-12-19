import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  CameraController? get controller => _controller;

  Future<void> initializeCamera() async {
    const timeout = Duration(seconds: 10);
    await _initializeCameraInternal().timeout(timeout, onTimeout: () {
      throw Exception('Camera initialization timed out after ${timeout.inSeconds}s');
    });
  }

  Future<void> _initializeCameraInternal() async {
    // Request camera permission
    var cameraPermission = await Permission.camera.request();
    if (!cameraPermission.isGranted) {
      throw Exception('Camera permission denied. Please enable Camera permission in Settings.');
    }

    // Get available cameras
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      throw Exception('No cameras available on this device.');
    }

    // Initialize camera controller (use back camera by default)
    _controller = CameraController(
      _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      ),
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize();
    _isInitialized = true;
    print('Camera initialized successfully');
  }

  Future<String?> captureImage() async {
    if (!_isInitialized || _controller == null) {
      print('Camera not initialized');
      return null;
    }

    try {
      XFile picture = await _controller!.takePicture();
      return picture.path;
    } catch (e) {
      print('Failed to capture image: $e');
      return null;
    }
  }

  void dispose() {
    _controller?.dispose();
    _isInitialized = false;
  }
}
