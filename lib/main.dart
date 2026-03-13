// ════════════════════════════════════════════
// main.dart  –  AQuality App Entry Point
// Login lives in lib/login_page.dart
// ════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'login_page.dart';
import 'dart:async';
import 'dart:math';
import 'package:intl/intl.dart';

import 'package:fl_chart/fl_chart.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const MyApp());
}

// ─────────────────────────────────────────────
// App Root
// ─────────────────────────────────────────────

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AquaMonitorState(),
      child: MaterialApp(
        title: 'AQuality',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF00D4FF),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const LoginPage(), // ← starts at login
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────

class SensorReading {
  final double value;
  final String unit;
  final String status;
  const SensorReading({required this.value, required this.unit, required this.status});
}

class _SensorConfig {
  final String name;
  final SensorReading reading;
  final IconData icon;
  final Color accentColor;
  final String idealRange;
  final double minAbsolute, maxAbsolute, minIdeal, maxIdeal;
  final String description;

  const _SensorConfig({
    required this.name, required this.reading, required this.icon,
    required this.accentColor, required this.idealRange,
    required this.minAbsolute, required this.maxAbsolute,
    required this.minIdeal, required this.maxIdeal, required this.description,
  });

  double get normalizedValue =>
      ((reading.value - minAbsolute) / (maxAbsolute - minAbsolute)).clamp(0.0, 1.0);
}

// ─────────────────────────────────────────────
// State – Simulated IoT
// ─────────────────────────────────────────────

class AquaMonitorState extends ChangeNotifier {
  final _rng = Random();
  Timer? _timer;
  DateTime lastUpdated = DateTime.now();

  List<double> turbidityHistory = [];
  List<double> temperatureHistory = [];
  List<double> phHistory = [];

  double _turbidity = 2.3, _temperature = 22.5, _ph = 7.2;

  SensorReading get turbidity => SensorReading(
      value: _turbidity, unit: 'NTU',
      status: _turbidity < 5 ? 'Optimal' : _turbidity < 10 ? 'Warning' : 'Critical');

  SensorReading get temperature => SensorReading(
      value: _temperature, unit: '°C',
      status: _temperature >= 20 && _temperature <= 25 ? 'Optimal'
          : _temperature >= 15 && _temperature <= 30 ? 'Warning' : 'Critical');

  SensorReading get ph => SensorReading(
      value: _ph, unit: 'pH',
      status: _ph >= 6.5 && _ph <= 8.5 ? 'Optimal'
          : _ph >= 6.0 && _ph <= 9.0 ? 'Warning' : 'Critical');

  bool get allOptimal =>
      turbidity.status == 'Optimal' &&
          temperature.status == 'Optimal' &&
          ph.status == 'Optimal';

  AquaMonitorState() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _simulate());
  }

  void _simulate() {
    _turbidity   = (_turbidity   + (_rng.nextDouble() - 0.5) * 0.4).clamp(0.5, 15.0);
    _temperature = (_temperature + (_rng.nextDouble() - 0.5) * 0.3).clamp(15.0, 32.0);
    _ph          = (_ph          + (_rng.nextDouble() - 0.5) * 0.1).clamp(5.5, 9.5);

    _round();

    turbidityHistory.add(_turbidity);
    temperatureHistory.add(_temperature);
    phHistory.add(_ph);

    if (turbidityHistory.length > 24) turbidityHistory.removeAt(0);
    if (temperatureHistory.length > 24) temperatureHistory.removeAt(0);
    if (phHistory.length > 24) phHistory.removeAt(0);

    lastUpdated = DateTime.now();
    notifyListeners();
  }

  void refresh() {
    _turbidity   = (_turbidity   + (_rng.nextDouble() - 0.5) * 1.2).clamp(0.5, 15.0);
    _temperature = (_temperature + (_rng.nextDouble() - 0.5) * 1.0).clamp(15.0, 32.0);
    _ph          = (_ph          + (_rng.nextDouble() - 0.5) * 0.4).clamp(5.5, 9.5);
    _round(); lastUpdated = DateTime.now(); notifyListeners();
  }

  void _round() {
    _turbidity   = double.parse(_turbidity.toStringAsFixed(1));
    _temperature = double.parse(_temperature.toStringAsFixed(1));
    _ph          = double.parse(_ph.toStringAsFixed(2));
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
}

// ─────────────────────────────────────────────
// App Shell
// ─────────────────────────────────────────────

class AquaMonitorHome extends StatefulWidget {
  const AquaMonitorHome({super.key});
  @override
  State<AquaMonitorHome> createState() => _AquaMonitorHomeState();
}

class _AquaMonitorHomeState extends State<AquaMonitorHome> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060B18),
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: const [DashboardPage(), AnalyticsPage()],
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFF0E1628),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Row(children: [
        _navItem(0, Icons.water_drop_outlined, Icons.water_drop, 'Dashboard'),
        _navItem(1, Icons.bar_chart_outlined,  Icons.bar_chart,  'Analytics'),
      ]),
    );
  }

  Widget _navItem(int index, IconData icon, IconData activeIcon, String label) {
    final s = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: s ? const Color(0xFF00D4FF).withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(s ? activeIcon : icon,
                color: s ? const Color(0xFF00D4FF) : Colors.white.withOpacity(0.35), size: 22),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(
              fontSize: 11,
              fontWeight: s ? FontWeight.w600 : FontWeight.w400,
              color: s ? const Color(0xFF00D4FF) : Colors.white.withOpacity(0.35),
              letterSpacing: 0.3,
            )),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Dashboard Page
// ─────────────────────────────────────────────

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  String _fmt(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '$h:${dt.minute.toString().padLeft(2,'0')}:${dt.second.toString().padLeft(2,'0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AquaMonitorState>();
    final sensors = [
      _SensorConfig(name: 'Turbidity',   reading: state.turbidity,    icon: Icons.water,             accentColor: const Color(0xFF00D4FF), idealRange: '< 5 NTU',  minAbsolute: 0, maxAbsolute: 15, minIdeal: 0,   maxIdeal: 5,   description: 'Measures water clarity. Lower values indicate clearer water. High turbidity can indicate contamination or suspended particles.'),
      _SensorConfig(name: 'Temperature', reading: state.temperature,  icon: Icons.thermostat_outlined, accentColor: const Color(0xFFFF6B6B), idealRange: '20 – 25°C', minAbsolute: 0, maxAbsolute: 40, minIdeal: 20,  maxIdeal: 25,  description: 'Water temperature affects dissolved oxygen and aquatic life. The ideal range sustains healthy biological activity.'),
      _SensorConfig(name: 'pH Level',    reading: state.ph,           icon: Icons.science_outlined,   accentColor: const Color(0xFF7ED321), idealRange: '6.5 – 8.5', minAbsolute: 0, maxAbsolute: 14, minIdeal: 6.5, maxIdeal: 8.5, description: 'Indicates acidity or alkalinity. Neutral water is pH 7. Safe drinking water falls within 6.5–8.5 for most uses.'),
    ];

    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: _buildHeader(context, state)),
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: _StatusBanner(allOptimal: state.allOptimal),
      )),
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Live Readings', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.3)),
          Row(children: [
            _SimBadge(),
            const SizedBox(width: 8),
            _RefreshBtn(onTap: state.refresh),
          ]),
        ]),
      )),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList(delegate: SliverChildBuilderDelegate(
              (ctx, i) => Padding(padding: const EdgeInsets.only(bottom: 12), child: ReadingCard(config: sensors[i])),
          childCount: sensors.length,
        )),
      ),
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: const Text('Learn More', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.3)),
      )),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        sliver: SliverList(delegate: SliverChildListDelegate([
          InfoCard(config: sensors[0]),
          const SizedBox(height: 12),
          InfoCard(config: sensors[2]),
          const SizedBox(height: 16),
          Center(child: Text(
            'Simulated data · updates every 5s · last ${_fmt(state.lastUpdated)}',
            style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.25)),
          )),
        ])),
      ),
    ]);
  }

  Widget _buildHeader(BuildContext context, AquaMonitorState state) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 24),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF00D4FF), Color(0xFF0080FF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: const Color(0xFF00D4FF).withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: const Icon(Icons.water_drop, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('AQuality', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
          Text('Water Quality Monitor', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.45))),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange.withOpacity(0.25))),
          child: const Row(children: [
            Icon(Icons.developer_board, size: 12, color: Colors.orange),
            SizedBox(width: 5),
            Text('Simulated', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// Shared Widgets
// ─────────────────────────────────────────────

class _SimBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange.withOpacity(0.2))),
      child: const Row(children: [
        Icon(Icons.memory, size: 10, color: Colors.orange),
        SizedBox(width: 4),
        Text('SIM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.orange, letterSpacing: 0.6)),
      ]),
    );
  }
}

class _RefreshBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _RefreshBtn({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.08))),
        child: Row(children: [
          Icon(Icons.refresh_rounded, size: 14, color: Colors.white.withOpacity(0.55)),
          const SizedBox(width: 5),
          Text('Refresh', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.55), fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final bool allOptimal;
  const _StatusBanner({required this.allOptimal});
  @override
  Widget build(BuildContext context) {
    final color = allOptimal ? const Color(0xFF00FF88) : const Color(0xFFFFB800);
    final icon  = allOptimal ? Icons.check_circle_rounded : Icons.warning_amber_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.10), color.withOpacity(0.04)], begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(allOptimal ? 'All Systems Optimal' : 'Attention Required',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white, letterSpacing: -0.2)),
          Text(allOptimal ? 'All parameters within safe range' : 'One or more parameters need review',
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
        ]),
        const Spacer(),
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color, blurRadius: 6, spreadRadius: 1)])),
      ]),
    );
  }
}

class ReadingCard extends StatelessWidget {
  final _SensorConfig config;
  const ReadingCard({super.key, required this.config});

  Color _sc(String s) {
    switch (s) { case 'Optimal': return const Color(0xFF00FF88); case 'Warning': return const Color(0xFFFFB800); default: return const Color(0xFFFF4444); }
  }

  @override
  Widget build(BuildContext context) {
    final sc = _sc(config.reading.status);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: const Color(0xFF0E1628), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.06)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: config.accentColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(config.icon, color: config.accentColor, size: 18)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(config.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white, letterSpacing: -0.2)),
              Text('Ideal: ${config.idealRange}', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.35))),
            ]),
          ]),
          _StatusChip(status: config.reading.status, color: sc),
        ]),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(config.reading.value.toStringAsFixed(1), style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: config.accentColor, letterSpacing: -1.5, height: 1.0)),
          Padding(padding: const EdgeInsets.only(bottom: 5, left: 5), child: Text(config.reading.unit, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.4)))),
        ]),
        const SizedBox(height: 14),
        _RangeBar(config: config),
        const SizedBox(height: 10),
        Text('Simulated · auto-updates every 5s', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.28))),
      ]),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status; final Color color;
  const _StatusChip({required this.status, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.25))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

class _RangeBar extends StatelessWidget {
  final _SensorConfig config;
  const _RangeBar({required this.config});
  @override
  Widget build(BuildContext context) {
    final range = config.maxAbsolute - config.minAbsolute;
    final iS = (config.minIdeal - config.minAbsolute) / range;
    final iE = (config.maxIdeal - config.minAbsolute) / range;
    return Column(children: [
      ClipRRect(borderRadius: BorderRadius.circular(4), child: SizedBox(height: 6, child: CustomPaint(painter: _RangeBarPainter(iS: iS, iE: iE, v: config.normalizedValue, c: config.accentColor), size: const Size(double.infinity, 6)))),
      const SizedBox(height: 5),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('${config.minAbsolute.toInt()}', style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.25))),
        Text('Ideal range', style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.3))),
        Text('${config.maxAbsolute.toInt()}', style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.25))),
      ]),
    ]);
  }
}

class _RangeBarPainter extends CustomPainter {
  final double iS, iE, v; final Color c;
  const _RangeBarPainter({required this.iS, required this.iE, required this.v, required this.c});
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Rect.fromLTWH(0, 0, s.width, s.height), Paint()..color = Colors.white.withOpacity(0.07));
    canvas.drawRect(Rect.fromLTWH(iS * s.width, 0, (iE - iS) * s.width, s.height), Paint()..color = c.withOpacity(0.18));
    canvas.drawRect(Rect.fromLTWH(0, 0, v * s.width, s.height), Paint()..shader = LinearGradient(colors: [c.withOpacity(0.6), c]).createShader(Rect.fromLTWH(0, 0, v * s.width, s.height)));
  }
  @override bool shouldRepaint(_RangeBarPainter o) => v != o.v;
}

class InfoCard extends StatelessWidget {
  final _SensorConfig config;
  const InfoCard({super.key, required this.config});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF0E1628), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(color: config.accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(9)), child: Icon(config.icon, color: config.accentColor, size: 16)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('About ${config.name}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.1)),
          const SizedBox(height: 4),
          Text(config.description, style: TextStyle(fontSize: 12, height: 1.5, color: Colors.white.withOpacity(0.45))),
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// Analytics Page
// ─────────────────────────────────────────────

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {

  int selectedRange = 0; // 0=24h, 1=7d, 2=30d

  bool autoRefresh = false;
  Timer? refreshTimer;

  /// AUTO REFRESH
  void startAutoRefresh() {
    refreshTimer?.cancel();

    refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        setState(() {});
      },
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

  double avg(List<double> list) =>
      list.isEmpty ? 0 : list.reduce((a, b) => a + b) / list.length;

  double min(List<double> list) =>
      list.isEmpty ? 0 : list.reduce((a, b) => a < b ? a : b);

  double max(List<double> list) =>
      list.isEmpty ? 0 : list.reduce((a, b) => a > b ? a : b);

  List<FlSpot> spots(List<double> data) {
    return List.generate(
      data.length,
      (i) => FlSpot(i.toDouble(), data[i]),
    );
  }

  /// FILTER DATA BASED ON RANGE
  List<double> filterData(List<double> data) {
    if (data.isEmpty) return data;

    int length;

    if (selectedRange == 0) {
      length = 24;
    } else if (selectedRange == 1) {
      length = 24 * 7;
    } else {
      length = 24 * 30;
    }

    if (data.length <= length) return data;

    return data.sublist(data.length - length);
  }

  /// SMART X AXIS LABELS
  String getXAxisLabel(int index) {

    if (selectedRange == 0) {
      final now = DateTime.now().subtract(Duration(hours: 24 - index));
      return DateFormat('ha').format(now); // 1PM
    }

    if (selectedRange == 1) {
      final now = DateTime.now().subtract(Duration(days: 7 - (index ~/ 24)));
      return DateFormat('EEE').format(now); // Mon
    }

    final now = DateTime.now().subtract(Duration(days: 30 - (index ~/ 24)));
    return DateFormat('EEE').format(now);
  }

  Widget buildChart(
    String title,
    List<double> rawData,
    Color color,
    String unit,
  ) {

    final data = filterData(rawData);

    double minVal = min(data);
    double maxVal = max(data);

    double padding = (maxVal - minVal) * 0.2;
    if (padding == 0) padding = 1;

    double minY = minVal - padding;
    double maxY = maxVal + padding;

    double interval = (maxY - minY) / 4;

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
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white.withOpacity(0.08),
                      strokeWidth: 1,
                    );
                  },
                ),

                borderData: FlBorderData(show: false),

                titlesData: FlTitlesData(

                  /// X AXIS
                  bottomTitles: AxisTitles(
                    axisNameSize: 22,
                    axisNameWidget: const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        "Time",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (data.length / 6).ceilToDouble(),
                      getTitlesWidget: (value, meta) {

                        int index = value.toInt();

                        if (index >= data.length) {
                          return const SizedBox();
                        }

                        return Text(
                          getXAxisLabel(index),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        );
                      },
                    ),
                  ),

                  /// Y AXIS
                  leftTitles: AxisTitles(
                    axisNameSize: 24,
                    axisNameWidget: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        unit,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: interval,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.4),
                          ),
                        );
                      },
                    ),
                  ),

                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),

                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),

                lineBarsData: [
                  LineChartBarData(
                    spots: spots(data),
                    isCurved: true,
                    color: color,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget statsCard(String title, double avg, double min, double max,
      String unit, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
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
                    fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 10),
            Text("Average: ${avg.toStringAsFixed(2)} $unit"),
            Text("Min: ${min.toStringAsFixed(2)} $unit"),
            Text("Max: ${max.toStringAsFixed(2)} $unit"),
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
            label: const Text("24H"),
            selected: selectedRange == 0,
            onSelected: (_) => setState(() => selectedRange = 0),
          ),

          const SizedBox(width: 10),

          ChoiceChip(
            label: const Text("7D"),
            selected: selectedRange == 1,
            onSelected: (_) => setState(() => selectedRange = 1),
          ),

          const SizedBox(width: 10),

          ChoiceChip(
            label: const Text("30D"),
            selected: selectedRange == 2,
            onSelected: (_) => setState(() => selectedRange = 2),
          ),

          const Spacer(),

          /// AUTO REFRESH SWITCH
          Row(
            children: [
              const Text("Auto", style: TextStyle(fontSize: 12)),
              Switch(
                value: autoRefresh,
                onChanged: (value) {

                  setState(() {
                    autoRefresh = value;
                  });

                  if (value) {
                    startAutoRefresh();
                  } else {
                    stopAutoRefresh();
                  }
                },
              )
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final state = context.watch<AquaMonitorState>();

    final turb = filterData(state.turbidityHistory);
    final temp = filterData(state.temperatureHistory);
    final ph = filterData(state.phHistory);

    return CustomScrollView(
      slivers: [

        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 20, 20, 10),
            child: const Text("Analytics",
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold)),
          ),
        ),

        SliverToBoxAdapter(child: rangeSelector()),

        const SliverToBoxAdapter(child: SizedBox(height: 10)),

        SliverToBoxAdapter(
            child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [

              buildChart("Turbidity Trends", turb,
              const Color(0xFF00D4FF), "NTU"),

              buildChart("Temperature Trends", temp,
              const Color(0xFFFF6B6B), "°C"),

              buildChart("pH Level Trends", ph,
              const Color(0xFF7ED321), "pH"),

              buildCombinedChart(
                state.turbidityHistory,
                state.temperatureHistory,
                state.phHistory,
              ),

              const SizedBox(height: 10),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Statistics",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  statsCard(
                    "Turbidity",
                    avg(turb),
                    min(turb),
                    max(turb),
                    "NTU",
                    const Color(0xFF00D4FF),
                  ),
                  const SizedBox(width: 10),
                  statsCard(
                    "Temperature",
                    avg(temp),
                    min(temp),
                    max(temp),
                    "°C",
                    const Color(0xFFFF6B6B),
                  ),
                  const SizedBox(width: 10),
                  statsCard(
                    "pH Level",
                    avg(ph),
                    min(ph),
                    max(ph),
                    "",
                    const Color(0xFF7ED321),
                  ),
                ],
              ),

              const SizedBox(height: 120),
            ],
          ),
        ))
      ],
    );
  }

  Widget buildCombinedChart(
    List<double> turbidity,
    List<double> temperature,
    List<double> ph,
  ) {

    final turb = filterData(turbidity);
    final temp = filterData(temperature);
    final phv = filterData(ph);

    int length = [
      turb.length,
      temp.length,
      phv.length
    ].reduce((a, b) => a < b ? a : b);

    List<FlSpot> turbSpots =
        List.generate(length, (i) => FlSpot(i.toDouble(), turb[i]));

    List<FlSpot> tempSpots =
        List.generate(length, (i) => FlSpot(i.toDouble(), temp[i]));

    List<FlSpot> phSpots =
        List.generate(length, (i) => FlSpot(i.toDouble(), phv[i]));

    double minVal = [
      ...turb,
      ...temp,
      ...phv
    ].reduce((a, b) => a < b ? a : b);

    double maxVal = [
      ...turb,
      ...temp,
      ...phv
    ].reduce((a, b) => a > b ? a : b);

    double padding = (maxVal - minVal) * 0.2;
    if (padding == 0) padding = 1;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1628),
        borderRadius: BorderRadius.circular(16),
      ),
      height: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text(
            "Combined Water Quality Trends",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white),
          ),

          const SizedBox(height: 6),

          /// Legend
          Row(
            children: const [

              Icon(Icons.circle, size: 10, color: Color(0xFF00D4FF)),
              SizedBox(width: 4),
              Text("NTU", style: TextStyle(fontSize: 12)),

              SizedBox(width: 16),

              Icon(Icons.circle, size: 10, color: Color(0xFFFF6B6B)),
              SizedBox(width: 4),
              Text("Temp °C", style: TextStyle(fontSize: 12)),

              SizedBox(width: 16),

              Icon(Icons.circle, size: 10, color: Color(0xFF7ED321)),
              SizedBox(width: 4),
              Text("pH", style: TextStyle(fontSize: 12)),
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
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white.withOpacity(0.08),
                      strokeWidth: 1,
                    );
                  },
                ),

                borderData: FlBorderData(show: false),

                titlesData: FlTitlesData(

                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (length / 6).ceilToDouble(),
                      getTitlesWidget: (value, meta) {

                        int index = value.toInt();
                        if (index >= length) return const SizedBox();

                        return Text(
                          getXAxisLabel(index),
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),

                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (maxVal - minVal) / 4,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),

                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),

                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),

                lineBarsData: [

                  LineChartBarData(
                    spots: turbSpots,
                    isCurved: true,
                    color: const Color(0xFF00D4FF),
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                  ),

                  LineChartBarData(
                    spots: tempSpots,
                    isCurved: true,
                    color: const Color(0xFFFF6B6B),
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                  ),

                  LineChartBarData(
                    spots: phSpots,
                    isCurved: true,
                    color: const Color(0xFF7ED321),
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
}