import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pbl6_smart_ac/services/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Analysis window for AI insights
enum AnalysisWindow { day, week, month }

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  // Selected analysis window (default: 30 days)
  AnalysisWindow _selectedWindow = AnalysisWindow.month;

  bool _isLoadingAIAnalysis = false;
  String _aiAnalysis = '';
  String _aiRecommendations = '';
  // Heatmap data
  bool _loadingHeatmap = false;
  final List<_DaySeries> _heatmapRows = [];
  int _maxSamplesPerDay = 0;

  @override
  void initState() {
    super.initState();
    // Tự động load AI analysis khi vào trang
    _loadAIAnalysis();
    _loadHeatmapData();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Air Quality Analysis',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Heatmap Section
                  SizedBox(
                    height: 450, // Fixed height cho heatmap
                    child: _buildHeatmapSection(),
                  ),
                  const SizedBox(height: 16),

                  // AI Analysis Section (adaptive height)
                  _buildAIAnalysisSection(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapSection() {
    return Container(
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
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.grid_view,
                      color: Color(0xFF2196F3),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '30-Day Air Quality Heatmap',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Legend moved below title
                _buildLegend(),
              ],
            ),
          ),

          // Heatmap Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _loadingHeatmap
                  ? const Center(child: CircularProgressIndicator())
                  : _buildHeatmapGridReal(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: const [
        _LegendDot('Good', Color(0xFF22C55E)),
        _LegendDot('Moderate', Color(0xFFFACC15)),
        _LegendDot('Sensitive', Color(0xFFF59E0B)),
        _LegendDot('Unhealthy', Color(0xFFEF4444)),
        _LegendDot('Very Unhealthy', Color(0xFF8B5CF6)),
        _LegendDot('Hazardous', Color(0xFF7F1D1D)),
      ],
    );
  }

  Widget _buildHeatmapGridReal() {
    if (_heatmapRows.isEmpty) {
      return Center(
        child: Text(
          'No IAQ data in the last 30 days',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    const double minCellSize = 12;
    const double cellGap = 2.0;
    const double dayLabelWidth = 64.0;

    return LayoutBuilder(builder: (context, constraints) {
      final double availableWidth = constraints.maxWidth - dayLabelWidth - 8;
      final int columns = _maxSamplesPerDay > 0 ? _maxSamplesPerDay : 1;
      final double naturalWidth = columns * (minCellSize + cellGap) + cellGap;
      final bool needScroll = naturalWidth > availableWidth;
      final double cellW = needScroll
          ? minCellSize
          : (availableWidth - (columns + 1) * cellGap) / columns;
      final double contentWidth = needScroll ? naturalWidth : availableWidth;
      final double cellH = minCellSize; // square cells

      return Column(
        children: [
          // Header index row (scrolls horizontally as a whole grid)
          Row(
            children: [
              const SizedBox(width: dayLabelWidth),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: needScroll
                      ? const BouncingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    width: contentWidth,
                    child: Row(
                      children: List.generate(columns, (i) {
                        return SizedBox(
                          width: cellW + cellGap,
                          child: (i % 10 == 0)
                              ? Center(
                                  child: Text('${i + 1}',
                                      style: const TextStyle(
                                          fontSize: 8, color: Colors.grey)))
                              : const SizedBox.shrink(),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Body: one vertical scroller that contains both fixed left labels
          // and a single horizontally scrollable grid for all days together.
          Expanded(
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fixed Y-axis labels column
                  SizedBox(
                    width: dayLabelWidth,
                    child: Column(
                      children: _heatmapRows.map((row) {
                        final label =
                            '${_two(row.day.month)}/${_two(row.day.day)}';
                        return SizedBox(
                          height: cellH + cellGap, // approximates row height
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(label,
                                style: const TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w600)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  // Whole grid scrolls horizontally in one gesture
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: needScroll
                          ? const BouncingScrollPhysics()
                          : const NeverScrollableScrollPhysics(),
                      child: SizedBox(
                        width: contentWidth,
                        child: Column(
                          children: _heatmapRows.map((row) {
                            final label =
                                '${_two(row.day.month)}/${_two(row.day.day)}';
                            return Row(
                              children: [
                                ...row.values.map((v) => GestureDetector(
                                      onTap: () =>
                                          _showIAQDetails(context, label, v),
                                      child: Container(
                                        width: cellW,
                                        height: cellH,
                                        margin:
                                            const EdgeInsets.all(cellGap / 2),
                                        decoration: BoxDecoration(
                                          color: _aqiColor(v),
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                    )),
                                if (row.values.length < columns)
                                  SizedBox(
                                    width: (columns - row.values.length) *
                                        (cellW + cellGap),
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
            ),
          ),
        ],
      );
    });
  }

  // Show IAQ details in modal for mobile
  void _showIAQDetails(BuildContext context, String dateLabel, double iaq) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Air Quality Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date: $dateLabel',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _aqiColor(iaq),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('IAQ: ${iaq.toStringAsFixed(0)}'),
                ],
              ),
              SizedBox(height: 8),
              Text(
                _getAQIDescription(iaq),
                style: TextStyle(
                  color: _aqiColor(iaq),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _getAQIDescription(double aqi) {
    if (aqi <= 50) return 'Good (0-50)';
    if (aqi <= 100) return 'Moderate (51-100)';
    if (aqi <= 150) return 'Unhealthy for Sensitive Groups (101-150)';
    if (aqi <= 200) return 'Unhealthy (151-200)';
    if (aqi <= 300) return 'Very Unhealthy (201-300)';
    return 'Hazardous (301-500)';
  }

  Widget _buildAIAnalysisSection() {
    return Container(
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
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.psychology,
                      color: Color(0xFF9C27B0),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    // Auto-resize title to avoid vertical wrapping on small widths
                    Expanded(
                      child: FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: const Text(
                          'AI Analysis',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _loadAIAnalysis,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh Analysis',
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: _openAISettingsDialog,
                      icon: const Icon(Icons.settings),
                      tooltip: 'AI Settings',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Move selector below title for better responsiveness
                _FancySegmentedControl(
                  value: _selectedWindow,
                  onChanged: (w) {
                    setState(() => _selectedWindow = w);
                    _loadAIAnalysis();
                  },
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: _isLoadingAIAnalysis
                ? _buildLoadingState()
                : _buildAnalysisContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Analyzing air quality data...',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAISettingsDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('deepseek_api_key') ?? '';
    final baseUrl = prefs.getString('deepseek_base_url') ??
        'https://router.huggingface.co/v1';
    final model =
        prefs.getString('deepseek_model') ?? 'deepseek-ai/DeepSeek-V3.1:novita';

    final apiKeyCtrl = TextEditingController(text: apiKey);
    final baseUrlCtrl = TextEditingController(text: baseUrl);
    final modelCtrl = TextEditingController(text: model);

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('AI Settings (DeepSeek)'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: apiKeyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'API Key',
                    hintText: 'hf_... or sk_...',
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: baseUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'https://router.huggingface.co/v1',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: modelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Model',
                    hintText: 'deepseek-ai/DeepSeek-V3.1:novita',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await AIService.saveRuntimeConfig(
                  apiKey: apiKeyCtrl.text.trim(),
                  baseUrl: baseUrlCtrl.text.trim(),
                  model: modelCtrl.text.trim(),
                );
                if (mounted) Navigator.of(ctx).pop();
                // Re-run analysis after saving
                _loadAIAnalysis();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnalysisContent() {
    if (_aiAnalysis.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.psychology_outlined,
              size: 40,
              color: Color(0xFF9C27B0),
            ),
            SizedBox(height: 12),
            Text(
              'AI Analysis Ready',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Click refresh to get insights',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF666666),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Analysis Section
          const Text(
            'Analysis',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 6),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 96),
                child: Text(
                  _aiAnalysis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF333333),
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Recommendations Section
          const Text(
            'Recommendations',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 6),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 96),
                child: Text(
                  _aiRecommendations,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF333333),
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  } // Helper Methods

  Color _aqiColor(double aqi) {
    // EPA AQI ranges
    if (aqi <= 50) return const Color(0xFF22C55E); // Good - green
    if (aqi <= 100) return const Color(0xFFFACC15); // Moderate - yellow
    if (aqi <= 150) return const Color(0xFFF59E0B); // Sensitive - orange
    if (aqi <= 200) return const Color(0xFFEF4444); // Unhealthy - red
    if (aqi <= 300) return const Color(0xFF8B5CF6); // Very Unhealthy - purple
    return const Color(0xFF7F1D1D); // Hazardous - maroon
  }

  Future<void> _loadHeatmapData() async {
    if (_loadingHeatmap) return;
    setState(() => _loadingHeatmap = true);
    try {
      final now = DateTime.now();
      // Load PREVIOUS month (ví dụ hiện tại là 11 -> lấy 10)
      int targetYear = now.year;
      int targetMonth = now.month - 1;
      if (targetMonth == 0) {
        targetMonth = 12;
        targetYear -= 1;
      }
      final monthStart = DateTime(targetYear, targetMonth, 1);
      final nextMonth = DateTime(targetYear, targetMonth + 1, 1);
      final snap = await FirebaseFirestore.instance
          .collection('readings')
          .orderBy('datetime', descending: true)
          .limit(5000)
          .get();

      final Map<DateTime, List<double>> grouped = {};
      for (final doc in snap.docs) {
        final data = doc.data();
        final dt = _parseDateTime(data['datetime']);
        if (dt == null) continue;
        if (dt.isBefore(monthStart))
          break; // stop when older than current month
        if (dt.isAfter(nextMonth.subtract(const Duration(milliseconds: 1)))) {
          // newer than current month (future/next month) → skip
          continue;
        }
        final iaqVal =
            data['iaq'] ?? data['IAQ'] ?? data['iaq_score'] ?? data['iaqIndex'];
        final d = _toDouble(iaqVal);
        if (d == null) continue;
        final dayKey = DateTime(dt.year, dt.month, dt.day);
        (grouped[dayKey] ??= []).add(d);
      }

      final daysInMonth = DateTime(targetYear, targetMonth + 1, 0).day;
      final days = List<DateTime>.generate(daysInMonth, (i) {
        return DateTime(targetYear, targetMonth, 1 + i);
      });

      final rows = <_DaySeries>[];
      int maxLen = 0;
      for (final d in days) {
        final vals = grouped[d] ?? [];
        if (vals.length > maxLen) maxLen = vals.length;
        rows.add(_DaySeries(day: d, values: vals));
      }

      setState(() {
        _heatmapRows
          ..clear()
          ..addAll(rows);
        _maxSamplesPerDay = maxLen;
      });
    } catch (e) {
      debugPrint('heatmap load error: $e');
    } finally {
      if (mounted) setState(() => _loadingHeatmap = false);
    }
  }

  DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) {
      var s = v.trim();
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

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  String _two(int v) => v < 10 ? '0$v' : '$v';

  // AI Analysis Methods (Placeholder for future API integration)
  Future<void> _loadAIAnalysis() async {
    setState(() => _isLoadingAIAnalysis = true);
    try {
      // Build summary based on selected analysis window
      final summary = await _buildWindowSummary(_selectedWindow);
      final monthLabel = summary['month_label']?.toString() ?? 'giai đoạn';
      final result = await AIService.analyze(
        monthLabel: monthLabel,
        summary: summary,
      );
      setState(() {
        _aiAnalysis = result.analysis;
        _aiRecommendations = result.recommendations;
      });
    } catch (e) {
      setState(() {
        _aiAnalysis = 'Không thể gọi AI: $e';
        _aiRecommendations = '';
      });
    } finally {
      if (mounted) setState(() => _isLoadingAIAnalysis = false);
    }
  }

  /// Build summary for the given analysis window by reading IAQ values
  /// from Firestore 'readings' collection. Uses 'datetime' field and IAQ keys
  /// among: iaq, IAQ, iaq_score, iaqIndex.
  Future<Map<String, dynamic>> _buildWindowSummary(AnalysisWindow w) async {
    final now = DateTime.now();
    late String label;
    DateTime from = now;
    DateTime to = now;

    int horizonDays;
    switch (w) {
      case AnalysisWindow.day:
        horizonDays = 1; // will be adjusted to the nearest day with data
        break;
      case AnalysisWindow.week:
        horizonDays = 7;
        break;
      case AnalysisWindow.month:
        horizonDays = 30;
        break;
    }

    final snap = await FirebaseFirestore.instance
        .collection('readings')
        .orderBy('datetime', descending: true)
        .limit(5000)
        .get();

    double sum = 0;
    int count = 0;
    double? gMin;
    double? gMax;
    int good = 0,
        moderate = 0,
        sensitive = 0,
        unhealthy = 0,
        veryUnhealthy = 0,
        hazardous = 0;

    if (w == AnalysisWindow.day) {
      // Find the most recent day with data and average that day
      DateTime? firstDayKey;
      for (final doc in snap.docs) {
        final data = doc.data();
        final dt = _parseDateTime(data['datetime']);
        if (dt == null) continue;
        final dayKey = DateTime(dt.year, dt.month, dt.day);
        if (firstDayKey == null) firstDayKey = dayKey;
        if (dayKey != firstDayKey) break;
        final iaqVal =
            data['iaq'] ?? data['IAQ'] ?? data['iaq_score'] ?? data['iaqIndex'];
        final d = _toDouble(iaqVal);
        if (d == null) continue;
        sum += d;
        count++;
        gMin = (gMin == null) ? d : (d < gMin ? d : gMin);
        gMax = (gMax == null) ? d : (d > gMax ? d : gMax);
        if (d <= 50) {
          good++;
        } else if (d <= 100) {
          moderate++;
        } else if (d <= 150) {
          sensitive++;
        } else if (d <= 200) {
          unhealthy++;
        } else if (d <= 300) {
          veryUnhealthy++;
        } else {
          hazardous++;
        }
        to = dt.isAfter(to) ? dt : to;
        from = dt.isBefore(from) ? dt : from;
      }
      final dayStr = firstDayKey != null
          ? '${_two(firstDayKey.day)}/${_two(firstDayKey.month)}/${firstDayKey.year}'
          : 'không có dữ liệu';
      label = '1 ngày gần nhất ($dayStr)';
    } else {
      final days = horizonDays;
      from = now.subtract(Duration(days: days));
      to = now;
      for (final doc in snap.docs) {
        final data = doc.data();
        final dt = _parseDateTime(data['datetime']);
        if (dt == null) continue;
        if (dt.isBefore(from)) break; // remaining docs are older
        if (dt.isAfter(to)) continue; // future anomaly
        final iaqVal =
            data['iaq'] ?? data['IAQ'] ?? data['iaq_score'] ?? data['iaqIndex'];
        final d = _toDouble(iaqVal);
        if (d == null) continue;
        sum += d;
        count++;
        gMin = (gMin == null) ? d : (d < gMin ? d : gMin);
        gMax = (gMax == null) ? d : (d > gMax ? d : gMax);
        if (d <= 50) {
          good++;
        } else if (d <= 100) {
          moderate++;
        } else if (d <= 150) {
          sensitive++;
        } else if (d <= 200) {
          unhealthy++;
        } else if (d <= 300) {
          veryUnhealthy++;
        } else {
          hazardous++;
        }
      }
      label =
          (w == AnalysisWindow.week) ? '7 ngày gần nhất' : '30 ngày gần nhất';
    }

    final avg =
        count == 0 ? 0.0 : double.parse((sum / count).toStringAsFixed(1));
    return {
      'month_label': label,
      'overall': {
        'avg': avg,
        'max': gMax ?? 0,
        'min': gMin ?? 0,
        'samples': count,
      },
      'histogram': {
        'good': good,
        'moderate': moderate,
        'sensitive': sensitive,
        'unhealthy': unhealthy,
        'very_unhealthy': veryUnhealthy,
        'hazardous': hazardous,
      },
    };
  }
}

class _DaySeries {
  final DateTime day;
  final List<double> values;
  _DaySeries({required this.day, required this.values});
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendDot(this.label, this.color, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 9)),
      ],
    );
  }
}

/// Compact selector for analysis window (1 day / 1 week / 1 month)
class _FancySegmentedControl extends StatelessWidget {
  final AnalysisWindow value;
  final ValueChanged<AnalysisWindow> onChanged;
  const _FancySegmentedControl({
    required this.value,
    required this.onChanged,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const items = [
      (AnalysisWindow.day, '1 ngày'),
      (AnalysisWindow.week, '1 tuần'),
      (AnalysisWindow.month, '1 tháng'),
    ];
    final primary = const Color(0xFF9C27B0);
    final radius = BorderRadius.circular(16);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F1),
        borderRadius: radius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: items.map((item) {
          final selected = item.$1 == value;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              borderRadius: radius,
              onTap: () => onChanged(item.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color:
                      selected ? primary.withOpacity(0.12) : Colors.transparent,
                  borderRadius: radius,
                  border: Border.all(
                    color: selected ? primary : const Color(0xFFD9D9D9),
                    width: selected ? 1.2 : 1,
                  ),
                ),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? primary : const Color(0xFF333333),
                  ),
                  child: Text(item.$2),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
