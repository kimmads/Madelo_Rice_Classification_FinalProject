import 'package:flutter/material.dart';
import 'rice_classifier_service.dart';

class RiceVariety {
  final String name;
  final String description;
  final String imagePath;

  const RiceVariety({
    required this.name,
    required this.description,
    required this.imagePath,
  });
}

final List<RiceVariety> riceVarieties = [
  const RiceVariety(
    name: 'Arborio Rice',
    description: 'Italian short-grain rice used for risotto. High starch content gives creamy texture.',
    imagePath: 'assets/Rice class/Arborio-Rice.jpg',
  ),
  const RiceVariety(
    name: 'Basmati Rice',
    description: 'Long-grain aromatic rice from India. Fragrant, fluffy, and non-sticky when cooked.',
    imagePath: 'assets/Rice class/Basmati.webp',
  ),
  const RiceVariety(
    name: 'Black Rice',
    description: 'Nutrient-rich black rice with nutty flavor and chewy texture; rich in antioxidants.',
    imagePath: 'assets/Rice class/Black.webp',
  ),
  const RiceVariety(
    name: 'Brown Rice',
    description: 'Whole grain rice with nutty flavor and chewy texture. Higher in fiber and nutrients.',
    imagePath: 'assets/Rice class/Brown rice.webp',
  ),
  const RiceVariety(
    name: 'Dinorado Rice',
    description: 'Filipino premium long-grain rice known for its fragrant aroma and fluffy texture.',
    imagePath: 'assets/Rice class/Dinorado.webp',
  ),
  const RiceVariety(
    name: 'Jasmin Rice',
    description: 'Thai fragrant long-grain rice. Soft, slightly sticky, and floral aroma.',
    imagePath: 'assets/Rice class/Jasmin.png',
  ),
  const RiceVariety(
    name: 'Malagkit Rice',
    description: 'Filipino glutinous rice variety. Sticky when cooked, used in traditional sweets.',
    imagePath: 'assets/Rice class/malagkit.jpg',
  ),
  const RiceVariety(
    name: 'Milagrosa Rice',
    description: 'Filipino fragrant rice variety. Soft texture and mild aroma when cooked.',
    imagePath: 'assets/Rice class/milagrosa.jpg',
  ),
  const RiceVariety(
    name: 'Red Rice',
    description: 'Nutrient-rich red rice with earthy flavor and high antioxidant content.',
    imagePath: 'assets/Rice class/Red Rice.jpg',
  ),
  const RiceVariety(
    name: 'Wild Rice',
    description: 'Aquatic grass seed with chewy texture and nutty flavor. High in protein.',
    imagePath: 'assets/Rice class/wild rice.jpg',
  ),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RiceClassifierService _classifierService = RiceClassifierService();
  List<String> _labels = [];
  bool _modelLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadModelAndLabels();
  }

  Future<void> _loadModelAndLabels() async {
    try {
      await _classifierService.loadModel();
      setState(() {
        _labels = [
          'Arborio Rice',
          'Basmati Rice',
          'Black Rice',
          'Brown Rice',
          'Dinorado Rice',
          'Jasmin Rice',
          'Malagkit Rice',
          'Milagrosa Rice',
          'Red Rice',
          'Wild Rice'
        ]; // All 10 classes from model
        _modelLoaded = true;
      });
    } catch (e) {
      print('Failed to load model: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rice Varieties'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: riceVarieties.length,
        itemBuilder: (context, index) {
          final variety = riceVarieties[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.asset(
                    variety.imagePath,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, st) {
                      return Container(
                        height: 160,
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.image, size: 48, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        variety.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        variety.description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
