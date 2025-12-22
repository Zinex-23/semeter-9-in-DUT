import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../firebase_options.dart';
import 'report_screen.dart';
import 'scheduling_screen.dart';
import 'control_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // App state
  bool _isInitialized = false;
  String _initError = '';
  int _currentIndex = 0; // 0: Dashboard, 1: Report, 2: Scheduling, 3: Control

  // Dashboard data
  final List<Map<String, dynamic>> _recentReadings = [];
  StreamSubscription<QuerySnapshot>? _readingsSub;

  // IAQ series for last month
  final List<_TimeValue> _iaqSeries = [];
  bool _loadingIaq = false;
  // Aggregates/metrics
  int _count30d = 0;
  DateTime? _lastUpdate;

  final List<String> _pageNames = const [
    'Dashboard',
    'Report',
    'Scheduling',
    'Control'
  ];

  @override
  void initState() {
    super.initState();
    _initFirebase();
  }

  Future<void> _initFirebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      setState(() {
        _isInitialized = true;
      });
      _setupReadingsListener();
      _loadIaqLastMonth();
    } catch (e) {
      setState(() {
        _initError = 'Firebase init error: $e';
      });
    }
  }

  Future<void> _loadIaqLastMonth() async {
    if (_loadingIaq) return;
    setState(() {
      _loadingIaq = true;
    });

    try {
      // Fetch up to 500 latest docs, then filter to last 30 days in-app
      final snapshot = await FirebaseFirestore.instance
          .collection('readings')
          .orderBy('datetime', descending: true)
          .limit(500)
          .get();

      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      final List<_TimeValue> points = [];
      int count30 = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final dt = _parseDateTime(data['datetime']);
        if (dt == null) continue;
        if (dt.isBefore(thirtyDaysAgo))
          break; // since we fetched in descending order
        // Count all readings in last 30 days
        count30++;

        final iaqVal = _getValue(
          data,
          keys: const ['iaq', 'IAQ', 'iaq_score', 'iaqIndex'],
          patterns: const ['iaq'],
        );
        final d = _toDoubleSafely(iaqVal);
        if (d != null) {
          points.add(_TimeValue(dt, d));
        }
      }

      points.sort((a, b) => a.t.compareTo(b.t)); // ascending for plotting

      setState(() {
        _iaqSeries
          ..clear()
          ..addAll(points);
        _count30d = count30;
      });
    } catch (e) {
      debugPrint('load IAQ series error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingIaq = false;
        });
      }
    }
  }

  DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) {
      var s = v.trim();
      // Convert "YYYY-MM-DD  HH:mm:ss +HH:MM" to ISO-8601: replace first space with 'T' and remove space before timezone
      if (RegExp(r'^\d{4}-\d{2}-\d{2} ').hasMatch(s)) {
        final firstSpace = s.indexOf(' ');
        if (firstSpace != -1) s = s.replaceFirst(' ', 'T');
        final tzPlus = s.indexOf('+', 10);
        final tzMinus = s.indexOf('-', 10);
        final tzIdx = tzPlus >= 0 ? tzPlus : (tzMinus >= 0 ? tzMinus : -1);
        if (tzIdx > 0 && s[tzIdx - 1] == ' ') {
          s = s.substring(0, tzIdx - 1) + s.substring(tzIdx);
        }
      }
      try {
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  double? _toDoubleSafely(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  void _setupReadingsListener() {
    _readingsSub?.cancel();
    _readingsSub = FirebaseFirestore.instance
        .collection('readings')
        .orderBy('datetime', descending: true)
        .limit(5)
        .snapshots()
        .listen((snapshot) {
      final rows = snapshot.docs.map((doc) {
        final data = doc.data();

        final tempVal = _getValue(
          data,
          keys: const ['temperature_c', 'temp_c', 'temp', 'temperature'],
          // tránh match nhầm 'timestamp'
          patterns: const [],
        );
        final humVal = _getValue(
          data,
          keys: const ['humidity', 'hum', 'huminity'],
          patterns: const ['hum'],
        );
        final co2Val = _getValue(
          data,
          keys: const ['eco2', 'eCO2', 'co2', 'co2_ppm', 'eCO2_ppm'],
          patterns: const ['co2'],
        );
        final tvocVal = _getValue(
          data,
          keys: const ['tvoc', 'TVOC', 'tvoc_ppb', 'TVOC_ppb'],
          patterns: const ['tvoc'],
        );
        final iaqVal = _getValue(
          data,
          keys: const ['iaq', 'IAQ', 'iaq_score', 'iaqIndex'],
          patterns: const ['iaq'],
        );

        return <String, dynamic>{
          'timestamp': data['datetime']?.toString() ?? '—',
          'temp': _formatValue(tempVal, decimals: 2),
          'humidity': _formatValue(humVal, decimals: 1),
          'eCO2': _formatValue(co2Val, decimals: 0),
          'tvoc': _formatValue(tvocVal, decimals: 0),
          'iaq': _formatValue(iaqVal, decimals: 0),
        };
      }).toList();

      setState(() {
        _recentReadings
          ..clear()
          ..addAll(rows);
        if (snapshot.docs.isNotEmpty) {
          _lastUpdate = _parseDateTime(snapshot.docs.first.data()['datetime']);
        }
      });
    }, onError: (e) {
      debugPrint('readings stream error: $e');
    });
  }

  // Helpers to robustly read and format values from Firestore
  dynamic _getValue(Map<String, dynamic> data,
      {List<String> keys = const [], List<String> patterns = const []}) {
    // 1) Exact keys first (case-sensitive then case-insensitive)
    for (final k in keys) {
      if (data.containsKey(k) && data[k] != null) return data[k];
    }
    for (final k in keys) {
      final match = data.keys.firstWhere(
        (kk) => kk.toLowerCase() == k.toLowerCase() && data[kk] != null,
        orElse: () => '',
      );
      if (match.isNotEmpty) return data[match];
    }

    // 2) Pattern-based recursive search in nested maps/lists
    if (patterns.isNotEmpty) {
      final v = _findFirstByPatterns(
          data, patterns.map((p) => p.toLowerCase()).toList());
      if (v != null) return v;
    }
    return null;
  }

  dynamic _findFirstByPatterns(dynamic node, List<String> patterns) {
    if (node == null) return null;
    if (node is Map) {
      // direct keys
      for (final entry in node.entries) {
        final key = entry.key.toString().toLowerCase();
        if (key == 'timestamp' || key == 'datetime')
          continue; // avoid picking timestamp for temp
        if (patterns.any((p) => key.contains(p))) {
          final value = entry.value;
          if (value != null) return value;
        }
      }
      // recurse
      for (final value in node.values) {
        final found = _findFirstByPatterns(value, patterns);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final item in node) {
        final found = _findFirstByPatterns(item, patterns);
        if (found != null) return found;
      }
    }
    return null;
  }

  String _formatValue(dynamic v, {int? decimals}) {
    if (v == null) return '—';
    if (v is num) {
      if (decimals != null) return v.toStringAsFixed(decimals);
      return v.toString();
    }
    if (v is String) {
      final parsed = double.tryParse(v);
      if (parsed != null) {
        if (decimals != null) return parsed.toStringAsFixed(decimals);
        return parsed.toString();
      }
      return v;
    }
    return v.toString();
  }

  @override
  void dispose() {
    _readingsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildMainContent()),
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  // Header with title and placeholder actions
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.indigo.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: _showLogoutDialog,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout, color: Colors.white),
              ),
            ),
          ),
          const Center(
            child: Text(
              'Intelligent Office',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.settings, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_initError.isNotEmpty) {
      return Center(
        child: Text('Error: $_initError'),
      );
    }

    // Page switching for bottom navigation
    if (_currentIndex == 1) return _buildReportContent();
    if (_currentIndex == 2) return _buildSchedulingContent();
    if (_currentIndex == 3) return _buildControlContent();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1000;
                final leftTable = _buildRecentTableCard();
                final metrics = _buildSystemMetricsCard();
                final iaqCard = SizedBox(
                  height: 300,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildIAQChart(),
                    ),
                  ),
                );

                if (isWide) {
                  // Web dashboard layout:
                  // Row 1: Sensor table (flex 8) + System Metrics (flex 2)
                  // Row 2: IAQ chart full width
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: leftTable),
                          const SizedBox(width: 16),
                          Expanded(flex: 3, child: _buildSystemMetricsCard()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      iaqCard,
                    ],
                  );
                }

                // Narrow: stack everything
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    leftTable,
                    const SizedBox(height: 16),
                    metrics,
                    const SizedBox(height: 16),
                    iaqCard,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // Recent table section extracted for reuse in responsive layout
  Widget _buildRecentTableCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.sensors, color: Colors.blue),
            SizedBox(width: 8),
            Text(
              'Recent Sensor Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_recentReadings.isNotEmpty)
          Text(
            'Last update: ${_recentReadings[0]['timestamp']}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        const SizedBox(height: 12),
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTableTheme(
              data: const DataTableThemeData(
                headingRowColor: MaterialStatePropertyAll(Color(0xFFF3F4F6)),
                headingTextStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
                dataTextStyle: TextStyle(
                  color: Color(0xFF111827),
                ),
                dividerThickness: 1,
              ),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Timestamp')),
                  DataColumn(label: Text('Temp (°C)')),
                  DataColumn(label: Text('Humidity (%)')),
                  DataColumn(label: Text('eCO₂ (ppm)')),
                  DataColumn(label: Text('TVOC (ppb)')),
                  DataColumn(label: Text('IAQ')),
                ],
                rows: List<DataRow>.generate(_recentReadings.length, (i) {
                  final reading = _recentReadings[i];
                  final Color alt = i % 2 == 0
                      ? Colors.grey.withOpacity(0.03)
                      : Colors.transparent;
                  return DataRow(
                    color: MaterialStatePropertyAll(alt),
                    cells: [
                      DataCell(Text(reading['timestamp'] ?? '—')),
                      DataCell(Text(reading['temp'] ?? '—')),
                      DataCell(Text(reading['humidity'] ?? '—')),
                      DataCell(Text(reading['eCO2'] ?? '—')),
                      DataCell(Text(reading['tvoc'] ?? '—')),
                      DataCell(Text(reading['iaq'] ?? '—')),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // System Metrics card
  Widget _buildSystemMetricsCard({bool fill = false}) {
    final iaqLatest = _iaqSeries.isNotEmpty
        ? _iaqSeries.last.v
        : _toDoubleSafely(
            _recentReadings.isNotEmpty ? _recentReadings.first['iaq'] : null);
    final qualityTag = _iaqQualityTag(iaqLatest);
    final connTag = _connectionTag(_lastUpdate);
    final lastUpdateStr = _lastUpdate != null
        ? _formatDateTime(_lastUpdate!)
        : (_recentReadings.isNotEmpty ? _recentReadings[0]['timestamp'] : '—');

    final card = Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            Row(
              children: const [
                Icon(Icons.bar_chart, color: Color(0xFF2563EB), size: 22),
                SizedBox(width: 8),
                Text(
                  'System Metrics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                )
              ],
            ),
            const SizedBox(height: 12),
            _metricTile(
              icon: Icons.grid_view_rounded,
              iconColor: const Color(0xFF3B82F6),
              title: 'Total Records (30D)',
              trailing: _statusChip(_count30d > 0 ? '$_count30d' : '—',
                  background: const Color(0xFFEFF6FF),
                  textColor: const Color(0xFF1D4ED8)),
            ),
            const SizedBox(height: 12),
            _metricTile(
              icon: Icons.access_time_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'Last Update',
              trailing: _statusChip(lastUpdateStr,
                  background: const Color(0xFFECFDF5),
                  textColor: const Color(0xFF047857)),
            ),
            const SizedBox(height: 12),
            _metricTile(
              icon: Icons.insights_rounded,
              iconColor: const Color(0xFF8B5CF6),
              title: 'Data Quality',
              trailing: _statusChip(qualityTag.label,
                  background: qualityTag.color.withOpacity(0.15),
                  textColor: qualityTag.color),
            ),
            const SizedBox(height: 12),
            _metricTile(
              icon: Icons.wifi_rounded,
              iconColor: const Color(0xFF06B6D4),
              title: 'Connection',
              trailing: _statusChip(connTag.label,
                  background: connTag.color.withOpacity(0.15),
                  textColor: connTag.color),
            ),
            if (fill) const Expanded(child: SizedBox()),
          ],
        ),
      ),
    );

    if (fill) {
      return Container(
        constraints: const BoxConstraints(minHeight: 420),
        child: card,
      );
    }
    return card;
  }

  Widget _metricTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF374151),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _statusChip(String text,
      {required Color background, required Color textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    String two(int v) => v < 10 ? '0$v' : '$v';
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  _StatusTag _iaqQualityTag(double? iaq) {
    if (iaq == null) return const _StatusTag('Unknown', Color(0xFF6B7280));
    if (iaq <= 50) return const _StatusTag('Excellent', Color(0xFF10B981));
    if (iaq <= 100) return const _StatusTag('Moderate', Color(0xFFF59E0B));
    if (iaq <= 150) return const _StatusTag('Sensitive', Color(0xFFFB923C));
    if (iaq <= 200) return const _StatusTag('Unhealthy', Color(0xFFEF4444));
    if (iaq <= 300)
      return const _StatusTag('Very Unhealthy', Color(0xFF8B5CF6));
    return const _StatusTag('Hazardous', Color(0xFF7F1D1D));
  }

  _StatusTag _connectionTag(DateTime? last) {
    // Theo yêu cầu: chỉ hiển thị trạng thái Wi‑Fi và cho phép auto "Connected".
    // Không kiểm tra mạng hay độ trễ dữ liệu để tránh sai lệch trên web.
    return const _StatusTag('Connected', Color(0xFF06B6D4));
  }

  Widget _buildIAQChart() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: const [
                Icon(
                  Icons.show_chart,
                  color: Color(0xFF673AB7),
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'IAQ Monitoring',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _loadingIaq
                  ? const Center(child: CircularProgressIndicator())
                  : (_iaqSeries.isEmpty
                      ? Center(
                          child: Text(
                            'No IAQ data in the last 30 days',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            // responsive width: ensure enough horizontal space per point; allow horizontal scroll
                            const double minSpacingPerPoint = 10.0;
                            const double minWidth = 480.0; // base width
                            const double yAxisWidth = 44.0; // sticky Y width
                            final double contentWidth =
                                (_iaqSeries.length - 1) * minSpacingPerPoint +
                                    80; // inner paddings
                            final double canvasWidth =
                                contentWidth.clamp(minWidth, double.infinity);

                            final availableChartWidth =
                                (constraints.maxWidth - yAxisWidth);
                            final paintWidth = canvasWidth > availableChartWidth
                                ? canvasWidth
                                : availableChartWidth;

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Sticky Y-Axis
                                SizedBox(
                                  width: yAxisWidth,
                                  child: CustomPaint(
                                    painter: _YAxisPainter(_iaqSeries),
                                  ),
                                ),
                                // Scrollable chart area
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: paintWidth,
                                      child: CustomPaint(
                                        painter: _LineChartPainter(
                                          _iaqSeries,
                                          color: const Color(0xFF673AB7),
                                          stickyYAxis: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportContent() {
    return const ReportScreen();
  }

  Widget _buildSchedulingContent() {
    return const SchedulingScreen();
  }

  Widget _buildControlContent() {
    return const ControlScreen();
  }

  Widget _buildBottomNavigation() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.1,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_pageNames.length, (index) {
          final isSelected = _currentIndex == index;
          final icons = [
            Icons.dashboard,
            Icons.bar_chart,
            Icons.schedule,
            Icons.settings,
          ];

          return InkWell(
            onTap: () {
              setState(() {
                _currentIndex = index;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF6366F1).withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icons[index],
                    color: isSelected ? const Color(0xFF6366F1) : Colors.grey,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _pageNames[index],
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF6366F1) : Colors.grey,
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Future<void> _showLogoutDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // TODO: Implement logout logic
                Navigator.pop(context);
              },
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TimeValue {
  final DateTime t;
  final double v;
  const _TimeValue(this.t, this.v);
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter(this.points,
      {this.color = Colors.blue, this.stickyYAxis = false});

  final List<_TimeValue> points;
  final Color color;
  final bool stickyYAxis;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // Theme
    final gridColor = Colors.grey.withOpacity(0.25);
    final axisColor = Colors.grey.withOpacity(0.5);
    final labelColor = Colors.grey.shade600;

    final leftPad = stickyYAxis ? 16.0 : 40.0;
    final padding = EdgeInsets.fromLTRB(leftPad, 12, 16, 28);
    final chartRect = Rect.fromLTWH(
      padding.left,
      padding.top,
      size.width - padding.left - padding.right,
      size.height - padding.top - padding.bottom,
    );

    // Compute ranges
    final minX = points.first.t.millisecondsSinceEpoch.toDouble();
    final maxX = points.last.t.millisecondsSinceEpoch.toDouble();
    double minY = points.first.v;
    double maxY = points.first.v;
    for (final p in points) {
      if (p.v < minY) minY = p.v;
      if (p.v > maxY) maxY = p.v;
    }
    final yPadding = (maxY - minY).abs() * 0.1 + 1;
    minY -= yPadding;
    maxY += yPadding;

    // Scales
    double scaleX(double x) => maxX - minX == 0
        ? chartRect.left
        : chartRect.left + (x - minX) / (maxX - minX) * chartRect.width;
    double scaleY(double y) => maxY - minY == 0
        ? chartRect.bottom
        : chartRect.bottom - (y - minY) / (maxY - minY) * chartRect.height;

    // Grid lines and ticks
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    // Y grid and labels (5 ticks)
    const yTicks = 5;
    final yStep = (maxY - minY) / yTicks;
    for (int i = 0; i <= yTicks; i++) {
      final yVal = minY + i * yStep;
      final y = scaleY(yVal);
      canvas.drawLine(
          Offset(chartRect.left, y), Offset(chartRect.right, y), gridPaint);
      if (!stickyYAxis) {
        final tp = TextPainter(
          text: TextSpan(
            text: _formatNumber(yVal),
            style: TextStyle(fontSize: 10, color: labelColor),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
            canvas, Offset(chartRect.left - tp.width - 6, y - tp.height / 2));
      }
    }

    // X grid and labels (6 ticks)
    const xTicks = 6;
    for (int i = 0; i <= xTicks; i++) {
      final frac = i / xTicks;
      final xEpoch = minX + (maxX - minX) * frac;
      final x = scaleX(xEpoch);
      canvas.drawLine(
          Offset(x, chartRect.top), Offset(x, chartRect.bottom), gridPaint);

      final dt = DateTime.fromMillisecondsSinceEpoch(xEpoch.toInt());
      final label = _fmtDate(dt);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(fontSize: 10, color: labelColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, chartRect.bottom + 4));
    }

    // Axes (stronger line over grid)
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(chartRect.left, chartRect.bottom),
        Offset(chartRect.right, chartRect.bottom), axisPaint);
    if (!stickyYAxis) {
      canvas.drawLine(Offset(chartRect.left, chartRect.top),
          Offset(chartRect.left, chartRect.bottom), axisPaint);
    }

    // Line path
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final px = scaleX(points[i].t.millisecondsSinceEpoch.toDouble());
      final py = scaleY(points[i].v);
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }

    // Optional soft area fill
    final fillPath = Path.from(path)
      ..lineTo(scaleX(points.last.t.millisecondsSinceEpoch.toDouble()),
          chartRect.bottom)
      ..lineTo(scaleX(points.first.t.millisecondsSinceEpoch.toDouble()),
          chartRect.bottom)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withOpacity(0.18), color.withOpacity(0.02)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(chartRect);
    canvas.drawPath(fillPath, fillPaint);

    canvas.drawPath(path, linePaint);

    // Dots
    final dotPaint = Paint()..color = color.withOpacity(0.95);
    for (final p in points) {
      final dx = scaleX(p.t.millisecondsSinceEpoch.toDouble());
      final dy = scaleY(p.v);
      canvas.drawCircle(Offset(dx, dy), 2.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }

  String _fmt2(int v) => v < 10 ? '0$v' : '$v';
  String _fmtDate(DateTime dt) => '${_fmt2(dt.month)}/${_fmt2(dt.day)}';
  String _formatNumber(double v) {
    // Compact without intl: 0 decimals
    return v.toStringAsFixed(0);
  }
}

class _YAxisPainter extends CustomPainter {
  _YAxisPainter(this.points);
  final List<_TimeValue> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final gridColor = Colors.grey.withOpacity(0.25);
    final axisColor = Colors.grey.withOpacity(0.5);
    final labelColor = Colors.grey.shade600;

    const paddingTop = 12.0;
    const paddingBottom = 28.0;
    final chartRect = Rect.fromLTWH(
      0,
      paddingTop,
      size.width,
      size.height - paddingTop - paddingBottom,
    );

    // Range
    double minY = points.first.v;
    double maxY = points.first.v;
    for (final p in points) {
      if (p.v < minY) minY = p.v;
      if (p.v > maxY) maxY = p.v;
    }
    final yPadding = (maxY - minY).abs() * 0.1 + 1;
    minY -= yPadding;
    maxY += yPadding;

    double scaleY(double y) => maxY - minY == 0
        ? chartRect.bottom
        : chartRect.bottom - (y - minY) / (maxY - minY) * chartRect.height;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    // Y grid + labels
    const yTicks = 5;
    final yStep = (maxY - minY) / yTicks;
    for (int i = 0; i <= yTicks; i++) {
      final yVal = minY + i * yStep;
      final y = scaleY(yVal);
      canvas.drawLine(Offset(0, y), Offset(chartRect.width, y), gridPaint);

      final tp = TextPainter(
        text: TextSpan(
          text: vToStr(yVal),
          style: TextStyle(fontSize: 10, color: labelColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas, Offset(chartRect.width - tp.width - 6, y - tp.height / 2));
    }

    // Axis line at right edge
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(chartRect.width, chartRect.top),
        Offset(chartRect.width, chartRect.bottom), axisPaint);
  }

  String vToStr(double v) => v.toStringAsFixed(0);

  @override
  bool shouldRepaint(covariant _YAxisPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _StatusTag {
  final String label;
  final Color color;
  const _StatusTag(this.label, this.color);
}
