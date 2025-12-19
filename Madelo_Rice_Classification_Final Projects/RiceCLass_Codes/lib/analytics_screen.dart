import 'package:flutter/material.dart';
import 'firebase_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'home_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final FirebaseService _firebaseService = FirebaseService.instance;
  Map<String, int> _classCounts = {};
  List<Map<String, dynamic>> _recentClassifications = [];
  bool _loading = true;
  String? _error;
  String _selectedFilter = 'All';
  DateTime? _startDate;
  DateTime? _endDate;
  String _sortOrder = 'Newest';
  bool _showTableView = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    const timeout = Duration(seconds: 60);
    try {
      setState(() => _error = null);
      print('Analytics: Starting data load...');
      
      await _firebaseService.initializeFirebase();
      print('Analytics: Firebase initialized');

      String? userId = _firebaseService.getCurrentUserId();
      print('Analytics: Current userId: $userId');
      
      if (userId == null) {
        userId = await _firebaseService.signInAnonymously();
        print('Analytics: Signed in anonymously: $userId');
      }
      
      if (userId == null) {
        setState(() {
          _loading = false;
          _error = 'User not signed in';
        });
        print('Analytics: userId is null, cannot load data');
        return;
      }

      print('Analytics: loading for userId $userId');
      print('Analytics: query collection: Madelo-RiceVerifier, userId filter: $userId');
      final docs = await _firebaseService.getClassificationHistory(userId)
          .timeout(timeout, onTimeout: () {
        throw Exception('Analytics loading timed out. Please check your connection and try again.');
      });

      print('Analytics: fetched ${docs.length} documents');

      final counts = <String, int>{};
      final recent = <Map<String, dynamic>>[];

      for (final doc in docs) {
        final data = doc.data();
        print('Analytics: docId=${doc.id}, raw data=$data');
        if (data == null) continue;

        final className = (data['className'] ?? '').toString();
        final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.0;
        final timestamp = data['timestamp'];
        final imageSource = (data['imageSource'] ?? 'Unknown').toString();

        if (className.isNotEmpty) {
          counts[className] = (counts[className] ?? 0) + 1;
          recent.add({
            'className': className,
            'confidence': confidence,
            'timestamp': timestamp ?? DateTime.now(),
            'imageSource': imageSource,
          });
        }
      }

      print('Analytics: classCounts = $counts, recentCount = ${recent.length}');
      setState(() {
        _classCounts = counts;
        _recentClassifications = recent.toList();
        _loading = false;
      });
    } catch (e) {
      print('Failed to load analytics: $e');
      setState(() {
        _loading = false;
        _error = e.toString();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analytics failed to load: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : () {
              print('Refresh button pressed');
              _loadData();
            },
            tooltip: 'Refresh Analytics',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _loading ? null : _showResetDialog,
            tooltip: 'Clear All Data',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error loading analytics', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDateFilter(),
                      const SizedBox(height: 24),
                      _buildClassificationHistory(),
                      const SizedBox(height: 24),
                      _buildChartsSection(),
                      const SizedBox(height: 24),
                      _buildClassificationDistribution(),
                    ],
                  ),
                ),
    );
  }

  
  Widget _buildChartsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Analytics Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showTableView = !_showTableView;
                    });
                  },
                  icon: Icon(
                    _showTableView ? Icons.pie_chart : Icons.table_chart,
                    color: Colors.green[700],
                  ),
                  tooltip: _showTableView ? 'Show Charts' : 'Show Table',
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.sort, color: Colors.green[700]),
                  onSelected: (value) {
                    setState(() {
                      _sortOrder = value;
                    });
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'Newest',
                      child: Row(
                        children: [
                          Icon(Icons.keyboard_arrow_down, size: 16),
                          SizedBox(width: 8),
                          Text('Newest First'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'Oldest',
                      child: Row(
                        children: [
                          Icon(Icons.keyboard_arrow_up, size: 16),
                          SizedBox(width: 8),
                          Text('Oldest First'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'Highest Confidence',
                      child: Row(
                        children: [
                          Icon(Icons.trending_up, size: 16),
                          SizedBox(width: 8),
                          Text('Highest Confidence'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'Lowest Confidence',
                      child: Row(
                        children: [
                          Icon(Icons.trending_down, size: 16),
                          SizedBox(width: 8),
                          Text('Lowest Confidence'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _showTableView ? _buildClassificationTable() : _buildRiceClassificationLegend(),
      ],
    );
  }

  Widget _buildRiceClassificationLegend() {
    if (_classCounts.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(Icons.grain, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'No rice varieties classified yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Start classifying to see your rice variety legend',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final colors = [
      const Color(0xFF2E7D32), // Dark green
      const Color(0xFF1976D2), // Blue
      const Color(0xFFF57C00), // Orange
      const Color(0xFF7B1FA2), // Purple
      const Color(0xFFD32F2F), // Red
      const Color(0xFF00796B), // Teal
      const Color(0xFF5D4037), // Brown
      const Color(0xFF303F9F), // Indigo
      const Color(0xFF689F38), // Light green
      const Color(0xFFC2185B), // Pink
    ];

    final entries = _classCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.grain, color: Colors.green[700], size: 24),
                const SizedBox(width: 12),
                Text(
                  'Rice Classification Legend',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                for (int i = 0; i < entries.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: colors[i % colors.length].withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colors[i % colors.length].withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
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
                        Text(
                          '${entries[i].key} (${entries[i].value})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors[i % colors.length],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Total classifications: ${_classCounts.values.reduce((a, b) => a + b)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilter() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_list, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Choose Time Period',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Select when to view your classification results',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip('All Time', Icons.all_inclusive, 'See all your classifications'),
                _buildFilterChip('Today', Icons.today, 'Just from today'),
                _buildFilterChip('This Week', Icons.date_range, 'Past 7 days'),
                _buildFilterChip('This Month', Icons.calendar_month, 'Current month'),
                _buildFilterChip('This Year', Icons.calendar_today, 'Current year'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon, String description) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      label: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = label;
          _updateDateRange();
        });
      },
      backgroundColor: Colors.grey[100],
      selectedColor: Colors.green.withOpacity(0.3),
      checkmarkColor: Colors.green,
      tooltip: description,
    );
  }

  void _updateDateRange() {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case 'Today':
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'This Week':
        _startDate = now.subtract(Duration(days: now.weekday - 1));
        _startDate = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        _endDate = _startDate!.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        break;
      case 'This Month':
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case 'This Year':
        _startDate = DateTime(now.year, 1, 1);
        _endDate = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
      case 'All Time':
      default:
        _startDate = null;
        _endDate = null;
    }
    setState(() {});
  }

  List<Map<String, dynamic>> get _filteredClassifications {
    var filtered = <Map<String, dynamic>>[];
    
    if (_startDate == null || _endDate == null) {
      filtered = List<Map<String, dynamic>>.from(_recentClassifications);
    } else {
      filtered = List<Map<String, dynamic>>.from(_recentClassifications)
          .where((item) {
            final timestamp = item['timestamp'] as DateTime;
            return timestamp.isAfter(_startDate!) && timestamp.isBefore(_endDate!);
          })
          .toList();
    }
    
    // Apply sorting
    switch (_sortOrder) {
      case 'Newest':
        filtered.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
        break;
      case 'Oldest':
        filtered.sort((a, b) => (a['timestamp'] as DateTime).compareTo(b['timestamp'] as DateTime));
        break;
      case 'Highest Confidence':
        filtered.sort((a, b) => (b['confidence'] as double).compareTo(a['confidence'] as double));
        break;
      case 'Lowest Confidence':
        filtered.sort((a, b) => (a['confidence'] as double).compareTo(b['confidence'] as double));
        break;
    }
    
    return filtered;
  }

  Widget _buildClassificationHistory() {
    final filtered = _filteredClassifications;
    
    if (filtered.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(Icons.history, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'No classifications yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Start classifying rice varieties to see your history here',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.history, color: Colors.green[700], size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Your Classification History',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[700],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${filtered.length} results',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_selectedFilter != 'All Time' && _startDate != null && _endDate != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[50],
              child: Row(
                children: [
                  Icon(Icons.date_range, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Showing: ${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          Container(
            height: 300,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final item = filtered[index];
                return _buildClassificationItem(item, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassificationItem(Map<String, dynamic> item, int index) {
    final className = item['className'] as String;
    final confidence = item['confidence'] as double;
    final timestamp = item['timestamp'] as DateTime;
    final imageSource = item['imageSource'] as String;
    
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[100]!,
            width: index < _filteredClassifications.length - 1 ? 1 : 0,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Source icon with background
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: imageSource == 'Camera' ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                imageSource == 'Camera' ? Icons.camera_alt : Icons.photo_library,
                color: imageSource == 'Camera' ? Colors.blue[700] : Colors.green[700],
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            
            // Classification details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    className,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Confidence badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: confidence > 0.8 ? Colors.green : confidence > 0.6 ? Colors.orange : Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${(confidence * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Time info
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(timestamp),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Confidence indicator bar
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: confidence > 0.8 ? Colors.green : confidence > 0.6 ? Colors.orange : Colors.red,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear All Data'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to clear all classification data? This action cannot be undone.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${_classCounts.values.reduce((a, b) => a + b)} classifications will be deleted',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetAllData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resetAllData() async {
    try {
      setState(() => _loading = true);
      
      String? userId = _firebaseService.getCurrentUserId();
      if (userId != null) {
        await _firebaseService.clearAllClassifications(userId);
        await _loadData(); // Reload data after clearing
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All classification data has been cleared'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDate = DateTime(date.year, date.month, date.day);
    
    if (itemDate == today) {
      return 'Today, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (itemDate == yesterday) {
      return 'Yesterday, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildClassificationTable() {
    final filtered = _filteredClassifications;
    
    if (filtered.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(Icons.table_chart, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'No data to display',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Start classifying to see data in table view',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.table_chart, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Classification Data Table',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[700],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${filtered.length} records',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 400,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    DataColumn(
                      label: Text(
                        'Date & Time',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Rice Class',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Confidence',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Source',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]),
                      ),
                    ),
                  ],
                  rows: filtered.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final className = item['className'] as String;
                    final confidence = item['confidence'] as double;
                    final timestamp = item['timestamp'] as DateTime;
                    final imageSource = item['imageSource'] as String;
                    
                    return DataRow(
                      color: MaterialStateProperty.all(
                        index % 2 == 0 ? Colors.grey[50] : Colors.white,
                      ),
                      onSelectChanged: (selected) {
                        if (selected == true) {
                          _showRiceSampleDialog(item);
                        }
                      },
                      cells: [
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${timestamp.day}/${timestamp.month}/${timestamp.year}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getRiceClassColor(className).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              className,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _getRiceClassColor(className),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: confidence > 0.8 ? Colors.green : confidence > 0.6 ? Colors.orange : Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${(confidence * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            children: [
                              Icon(
                                imageSource == 'Camera' ? Icons.camera_alt : Icons.photo_library,
                                size: 16,
                                color: imageSource == 'Camera' ? Colors.blue[700] : Colors.green[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                imageSource,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRiceClassColor(String className) {
    final colors = [
      const Color(0xFF2E7D32), // Dark green
      const Color(0xFF1976D2), // Blue
      const Color(0xFFF57C00), // Orange
      const Color(0xFF7B1FA2), // Purple
      const Color(0xFFD32F2F), // Red
      const Color(0xFF00796B), // Teal
      const Color(0xFF5D4037), // Brown
      const Color(0xFF303F9F), // Indigo
      const Color(0xFF689F38), // Light green
      const Color(0xFFC2185B), // Pink
    ];
    
    final index = className.hashCode % colors.length;
    return colors[index.abs()];
  }

  Widget _buildClassificationDistribution() {
    if (_classCounts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.pie_chart, color: Colors.green[700], size: 20),
            const SizedBox(width: 8),
            Text(
              'Classification Distribution',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 300,
          child: PageView.builder(
            itemCount: _classCounts.length > 3 ? 2 : 1,
            itemBuilder: (context, pageIndex) {
              return _buildDistributionChart(pageIndex);
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _classCounts.length > 3 ? 2 : 1,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.green[700],
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDistributionChart(int pageIndex) {
    final entries = _classCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final colors = [
      const Color(0xFF2E7D32), // Dark green
      const Color(0xFF1976D2), // Blue
      const Color(0xFFF57C00), // Orange
      const Color(0xFF7B1FA2), // Purple
      const Color(0xFFD32F2F), // Red
      const Color(0xFF00796B), // Teal
      const Color(0xFF5D4037), // Brown
      const Color(0xFF303F9F), // Indigo
      const Color(0xFF689F38), // Light green
      const Color(0xFFC2185B), // Pink
    ];

    if (pageIndex == 0) {
      // Pie Chart
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                'Distribution by Class',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 60,
                    sections: entries.asMap().entries.map((entry) {
                      final index = entry.key;
                      final classEntry = entry.value;
                      final value = classEntry.value;
                      final total = _classCounts.values.reduce((a, b) => a + b);
                      final percentage = (value / total * 100);
                      
                      return PieChartSectionData(
                        color: colors[index % colors.length],
                        value: value.toDouble(),
                        title: '${percentage.toStringAsFixed(1)}%',
                        radius: 50,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        badgeWidget: _Badge(
                          classEntry.key,
                          size: 40,
                          borderColor: colors[index % colors.length],
                        ),
                        badgePositionPercentageOffset: .98,
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Bar Chart
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                'Count by Rice Class',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: entries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final className = entries[group.x.toInt()].key;
                          final value = entries[group.x.toInt()].value;
                          return BarTooltipItem(
                            '$className\n$value classifications',
                            const TextStyle(color: Colors.white),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < entries.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  entries[index].key.length > 8 
                                    ? entries[index].key.substring(0, 8) + '...'
                                    : entries[index].key,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            }
                            return const Text('');
                          },
                          reservedSize: 30,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                          reservedSize: 30,
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: entries.asMap().entries.map((entry) {
                      final index = entry.key;
                      final classEntry = entry.value;
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: classEntry.value.toDouble(),
                            color: colors[index % colors.length],
                            width: 20,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showRiceSampleDialog(Map<String, dynamic> item) {
    final className = item['className'] as String;
    final confidence = item['confidence'] as double;
    final timestamp = item['timestamp'] as DateTime;
    final imageSource = item['imageSource'] as String;
    
    // Find rice variety details from home_screen data
    final riceVariety = riceVarieties.firstWhere(
      (variety) => variety.name == className,
      orElse: () => RiceVariety(
        name: className,
        description: 'No description available for this rice variety.',
        imagePath: 'assets/Rice class/default.jpg',
      ),
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with image
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Stack(
                      children: [
                        Image.asset(
                          riceVariety.imagePath,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, st) {
                            return Container(
                              height: 200,
                              width: double.infinity,
                              color: Colors.grey[300],
                              child: const Center(
                                child: Icon(Icons.grain, size: 64, color: Colors.grey),
                              ),
                            );
                          },
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${(confidence * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              imageSource == 'Camera' ? Icons.camera_alt : Icons.photo_library,
                              color: imageSource == 'Camera' ? Colors.blue[700] : Colors.green[700],
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          riceVariety.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Description
                        Text(
                          riceVariety.description,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Classification Details
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Classification Details',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildDetailRow('Date', _formatDate(timestamp)),
                              _buildDetailRow('Time', '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}'),
                              _buildDetailRow('Confidence', '${(confidence * 100).toStringAsFixed(1)}%'),
                              _buildDetailRow('Image Source', imageSource),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Action buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final double size;
  final Color borderColor;

  const _Badge(
    this.text, {
    required this.size,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Center(
        child: FittedBox(
          child: Text(
            text.length > 3 ? text.substring(0, 3) : text,
            style: TextStyle(
              color: borderColor,
              fontWeight: FontWeight.bold,
              fontSize: 8,
            ),
          ),
        ),
      ),
    );
  }
}
