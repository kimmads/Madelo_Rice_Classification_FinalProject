import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class RiceClassificationResult {
  final String className;
  final double confidence;
  final DateTime timestamp;

  RiceClassificationResult({
    required this.className,
    required this.confidence,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'RiceClassificationResult(className: $className, confidence: ${(confidence * 100).toStringAsFixed(2)}%, timestamp: $timestamp)';
  }
}

class RiceClassifierService {
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isLoaded = false;
  
  Future<void> loadModel() async {
    try {
      // Load TFLite model
      _interpreter = await Interpreter.fromAsset('assets/model_unquant.tflite');
      
      // Load labels
      final labelsData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelsData.split('\n').where((label) => label.trim().isNotEmpty).toList();
      
      _isLoaded = true;
      print('Real TFLite model loaded successfully');
      print('Available classes: ${_labels.length}');
    } catch (e) {
      print('Error loading model: $e');
      // Fallback to mock if model loading fails
      _isLoaded = false;
      rethrow;
    }
  }

  RiceClassificationResult classifyImage(Uint8List imageBytes) {
    if (!_isLoaded || _interpreter == null) {
      throw Exception('Model not loaded');
    }
    
    try {
      // Preprocess image
      final input = _preprocessImage(imageBytes);
      
      // Prepare output tensor
      final output = List.filled(1 * _labels.length, 0.0).reshape([1, _labels.length]);
      
      // Run inference
      _interpreter!.run(input, output);
      
      // Get predictions
      final predictions = output[0];
      
      // Find the class with highest confidence
      double maxConfidence = predictions[0];
      int maxIndex = 0;
      
      for (int i = 1; i < predictions.length; i++) {
        if (predictions[i] > maxConfidence) {
          maxConfidence = predictions[i];
          maxIndex = i;
        }
      }
      
      // Get class name (remove index prefix if present)
      String className = _labels[maxIndex];
      if (className.contains(' ')) {
        className = className.split(' ').skip(1).join(' '); // Remove index prefix
      }
      
      return RiceClassificationResult(
        className: className,
        confidence: maxConfidence,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      print('Error during classification: $e');
      throw Exception('Classification failed: $e');
    }
  }
  
  List<List<List<List<double>>>> _preprocessImage(Uint8List imageBytes) {
    // Decode image
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }
    
    // Resize to model input size (assuming 224x224, adjust if needed)
    final resizedImage = img.copyResize(image, width: 224, height: 224, interpolation: img.Interpolation.linear);
    
    // Convert to normalized float array (0-1 range)
    final input = List.generate(1, (i) => 
      List.generate(224, (y) => 
        List.generate(224, (x) => 
          List.generate(3, (c) => 0.0)
        )
      )
    );
    
    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = resizedImage.getPixel(x, y);
        final red = (pixel >> 16) & 0xFF;
        final green = (pixel >> 8) & 0xFF;
        final blue = pixel & 0xFF;
        input[0][y][x][0] = red / 255.0;  // Red
        input[0][y][x][1] = green / 255.0;  // Green
        input[0][y][x][2] = blue / 255.0;  // Blue
      }
    }
    
    return input;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }
}
