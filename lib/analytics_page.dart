// ════════════════════════════════════════════
// analytics_page.dart  –  AQuality Analytics
// ════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import 'main.dart' show AquaMonitorState;

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  int selectedRange = 0; // 0=24h, 1=7d, 2=30d

  bool autoRefresh = false;
  Timer? refreshTimer;

  // ── Auto Refresh ──────────────────────────

  void startAutoRefresh() {
    refreshTimer?.cancel();
    refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
          (_) => setState(() {}),
    );
  }

  void stopAutoRefresh() {
    refreshTimer?.cancel();
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────

  double avg(List<double> list) =>
      list.isEmpty ? 0 : list.reduce((a, b) => a + b) / list.length;

  double min(List<double> list) =>
      list.isEmpty ? 0 : list.reduce((a, b) => a < b ? a : b);

  double max(List<double> list) =>
      list.isEmpty ? 0 : list.reduce((a, b) => a > b ? a : b);

  List<FlSpot> spots(List<double> data) =>
      List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i]));

  List<double> filterData(List<double> data) {
    if (data.isEmpty) return data;
    final length = selectedRange == 0
        ? 24
        : selectedRange == 1
        ? 24 * 7
        : 24 * 30;
    return data.length <= length ? data : data.sublist(data.length - length);
  }

  String getXAxisLabel(int index) {
    if (selectedRange == 0) {
      final now = DateTime.now().subtract(Duration(hours: 24 - index));
      return DateFormat('ha').format(now);
    }
    if (selectedRange == 1) {
      final now = DateTime.now().subtract(Duration(days: 7 - (index ~/ 24)));
      return DateFormat('EEE').format(now);
    }
    final now = DateTime.now().subtract(Duration(days: 30 - (index ~/ 24)));
    return DateFormat('EEE').format(now);
  }

  // ── Widgets ───────────────────────────────

  Widget buildChart(
    String title,
    List<double> rawData,
    Color color,
    String unit,
  ) {
    final data = filterData(rawData);
    if (data.isEmpty) {
      return _emptyAnalyticsCard(
        title,
        'No readings yet for this pond. Wait for the simulator or refresh once.',
      );
    }

    final minVal = min(data);
    final maxVal = max(data);
    double padding = (maxVal - minVal) * 0.2;
    if (padding == 0) padding = 1;

    final minY = minVal - padding;
    final maxY = maxVal + padding;
    final interval = (maxY - minY) / 4;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1628),
        borderRadius: BorderRadius.circular(16),
      ),
      height: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white)),
          const SizedBox(height: 10),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withOpacity(0.08),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    axisNameSize: 22,
                    axisNameWidget: const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text('Time',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500)),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (data.length / 6).ceilToDouble(),
                      getTitlesWidget: (value, _) {
                        final index = value.toInt();
                        if (index >= data.length) return const SizedBox();
                        return Text(getXAxisLabel(index),
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withOpacity(0.5)));
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    axisNameSize: 24,
                    axisNameWidget: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(unit,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500)),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: interval,
                      reservedSize: 40,
                      getTitlesWidget: (value, _) => Text(
                        value.toStringAsFixed(1),
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.4)),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots(data),
                    isCurved: true,
                    color: color,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCombinedChart(
      List<double> turbidity,
      List<double> temperature,
      List<double> ph,
      List<double> waterLevel, // NEW
      ) {
    final turb = filterData(turbidity);
    final temp = filterData(temperature);
    final phv  = filterData(ph);
    final wlv  = filterData(waterLevel); // NEW

    final length = [turb.length, temp.length, phv.length, wlv.length]
        .reduce((a, b) => a < b ? a : b);

    final turbSpots = List.generate(length, (i) => FlSpot(i.toDouble(), turb[i]));
    final tempSpots = List.generate(length, (i) => FlSpot(i.toDouble(), temp[i]));
    final phSpots   = List.generate(length, (i) => FlSpot(i.toDouble(), phv[i]));
    final wlSpots   = List.generate(length, (i) => FlSpot(i.toDouble(), wlv[i])); // NEW

    final allValues = [...turb, ...temp, ...phv, ...wlv]; // NEW
    if (allValues.isEmpty || length == 0) {
      return _emptyAnalyticsCard(
        'Combined Water Quality Trends',
        'No readings yet for this pond. Wait for the simulator or refresh once.',
      );
    }
    final minVal    = allValues.reduce((a, b) => a < b ? a : b);
    final maxVal    = allValues.reduce((a, b) => a > b ? a : b);
    double padding  = (maxVal - minVal) * 0.2;
    if (padding == 0) padding = 1;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1628),
        borderRadius: BorderRadius.circular(16),
      ),
      height: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Combined Water Quality Trends',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 16,
            children: const [
              _LegendDot(color: Color(0xFF00D4FF), label: 'NTU'),
              _LegendDot(color: Color(0xFFFF6B6B), label: 'Temp °C'),
              _LegendDot(color: Color(0xFF7ED321), label: 'pH'),
              _LegendDot(color: Color(0xFF7B61FF), label: 'Level cm'), // NEW
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: minVal - padding,
                maxY: maxVal + padding,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Colors.black87,
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withOpacity(0.08),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (length / 6).ceilToDouble(),
                      getTitlesWidget: (value, _) {
                        final index = value.toInt();
                        if (index >= length) return const SizedBox();
                        return Text(getXAxisLabel(index),
                            style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (maxVal - minVal) / 4,
                      reservedSize: 40,
                      getTitlesWidget: (value, _) => Text(
                        value.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(spots: turbSpots, isCurved: true, color: const Color(0xFF00D4FF), barWidth: 3, dotData: FlDotData(show: false)),
                  LineChartBarData(spots: tempSpots, isCurved: true, color: const Color(0xFFFF6B6B), barWidth: 3, dotData: FlDotData(show: false)),
                  LineChartBarData(spots: phSpots,   isCurved: true, color: const Color(0xFF7ED321), barWidth: 3, dotData: FlDotData(show: false)),
                  LineChartBarData(spots: wlSpots,   isCurved: true, color: const Color(0xFF7B61FF), barWidth: 3, dotData: FlDotData(show: false)), // NEW
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget statsCard(
      String title,
      double avgVal,
      double minVal,
      double maxVal,
      String unit,
      Color color,
      ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1628),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color, fontSize: 12)),
            const SizedBox(height: 8),
            Text('Avg: ${avgVal.toStringAsFixed(1)} $unit', style: const TextStyle(fontSize: 11)),
            Text('Min: ${minVal.toStringAsFixed(1)} $unit',  style: const TextStyle(fontSize: 11)),
            Text('Max: ${maxVal.toStringAsFixed(1)} $unit',  style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget rangeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('24H'),
            selected: selectedRange == 0,
            onSelected: (_) => setState(() => selectedRange = 0),
          ),
          const SizedBox(width: 10),
          ChoiceChip(
            label: const Text('7D'),
            selected: selectedRange == 1,
            onSelected: (_) => setState(() => selectedRange = 1),
          ),
          const SizedBox(width: 10),
          ChoiceChip(
            label: const Text('30D'),
            selected: selectedRange == 2,
            onSelected: (_) => setState(() => selectedRange = 2),
          ),
          const Spacer(),
          Row(
            children: [
              const Text('Auto', style: TextStyle(fontSize: 12)),
              Switch(
                value: autoRefresh,
                onChanged: (value) {
                  setState(() => autoRefresh = value);
                  value ? startAutoRefresh() : stopAutoRefresh();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyAnalyticsCard(String title, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1628),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.white.withOpacity(0.55)),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AquaMonitorState>();

    final turb = filterData(state.turbidityHistory);
    final temp = filterData(state.temperatureHistory);
    final ph   = filterData(state.phHistory);
    final wl   = filterData(state.waterLevelHistory); // NEW

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 20, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Analytics',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E1628),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.water_outlined,
                        size: 18,
                        color: Color(0xFF00D4FF),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Showing readings for ${state.selectedPondName}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: rangeSelector()),
        const SliverToBoxAdapter(child: SizedBox(height: 10)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                buildChart('Turbidity Trends',   turb, const Color(0xFF00D4FF), 'NTU'),
                buildChart('Temperature Trends', temp, const Color(0xFFFF6B6B), '°C'),
                buildChart('pH Level Trends',    ph,   const Color(0xFF7ED321), 'pH'),
                buildChart('Water Level Trends', wl,   const Color(0xFF7B61FF), 'cm'), // NEW
                buildCombinedChart(
                  state.turbidityHistory,
                  state.temperatureHistory,
                  state.phHistory,
                  state.waterLevelHistory, // NEW
                ),
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Statistics',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  statsCard('Turbidity',   avg(turb), min(turb), max(turb), 'NTU', const Color(0xFF00D4FF)),
                  const SizedBox(width: 10),
                  statsCard('Temperature', avg(temp), min(temp), max(temp), '°C',  const Color(0xFFFF6B6B)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  statsCard('pH Level',    avg(ph), min(ph), max(ph), '',    const Color(0xFF7ED321)),
                  const SizedBox(width: 10),
                  statsCard('Water Level', avg(wl), min(wl), max(wl), 'cm', const Color(0xFF7B61FF)), // NEW
                ]),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Legend dot helper ─────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.circle, size: 10, color: color),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ]);
  }
}
