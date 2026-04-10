// ════════════════════════════════════════════
// main.dart  –  AQuality App Entry Point
// Login lives in lib/login_page.dart
// Analytics lives in lib/analytics_page.dart
// ════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'login_page.dart';
import 'analytics_page.dart';
import 'dart:async';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'profile_page.dart';
import 'notification_service.dart';
import 'pond_manage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService().init(); // ← add this
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
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
        home: const LoginPage(),
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
  const SensorReading({
    required this.value,
    required this.unit,
    required this.status,
  });
}

class PondProfile {
  final String id;
  String name;
  String fishType;
  String pondSize;

  final List<double> turbidityHistory;
  final List<double> temperatureHistory;
  final List<double> phHistory;
  final List<double> waterLevelHistory;

  double turbidity;
  double temperature;
  double ph;
  double waterLevel;
  DateTime lastUpdated;

  PondProfile({
    required this.id,
    required this.name,
    this.fishType = 'Unknown',
    this.pondSize = 'Unknown',
    required this.turbidity,
    required this.temperature,
    required this.ph,
    required this.waterLevel,
    DateTime? lastUpdated,
    List<double>? turbidityHistory,
    List<double>? temperatureHistory,
    List<double>? phHistory,
    List<double>? waterLevelHistory,
  }) : lastUpdated = lastUpdated ?? DateTime.now(),
       turbidityHistory = turbidityHistory ?? [],
       temperatureHistory = temperatureHistory ?? [],
       phHistory = phHistory ?? [],
       waterLevelHistory = waterLevelHistory ?? [];

  PondProfile copyWith({
    String? id,
    String? name,
    double? turbidity,
    double? temperature,
    double? ph,
    double? waterLevel,
    DateTime? lastUpdated,
    List<double>? turbidityHistory,
    List<double>? temperatureHistory,
    List<double>? phHistory,
    List<double>? waterLevelHistory,
  }) {
    return PondProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      turbidity: turbidity ?? this.turbidity,
      temperature: temperature ?? this.temperature,
      ph: ph ?? this.ph,
      waterLevel: waterLevel ?? this.waterLevel,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      turbidityHistory:
          turbidityHistory ?? List<double>.from(this.turbidityHistory),
      temperatureHistory:
          temperatureHistory ?? List<double>.from(this.temperatureHistory),
      phHistory: phHistory ?? List<double>.from(this.phHistory),
      waterLevelHistory:
          waterLevelHistory ?? List<double>.from(this.waterLevelHistory),
    );
  }
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
    required this.name,
    required this.reading,
    required this.icon,
    required this.accentColor,
    required this.idealRange,
    required this.minAbsolute,
    required this.maxAbsolute,
    required this.minIdeal,
    required this.maxIdeal,
    required this.description,
  });

  double get normalizedValue =>
      ((reading.value - minAbsolute) / (maxAbsolute - minAbsolute)).clamp(
        0.0,
        1.0,
      );
}

// ─────────────────────────────────────────────
// State – Simulated IoT
// ─────────────────────────────────────────────

class AquaMonitorState extends ChangeNotifier {
  final _rng = Random();
  Timer? _pollTimer;
  Timer? _simTimer;
  final List<PondProfile> _ponds = [];
  int _selectedPondIndex = 0;
  bool _isLive = false;

  AquaMonitorState() {
    _ponds.add(
      PondProfile(
        id: 'pond-1',
        name: 'Main Pond',
        turbidity: 2.3,
        temperature: 22.5,
        ph: 7.2,
        waterLevel: 120.0,
      ),
    );
    _fetchLatestReading(); // fetch immediately on start
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchLatestReading(),
    );
    _startSimulation(); // simulation runs until live data arrives
  }

  bool get isLive => _isLive;

  Future<void> _fetchLatestReading() async {
    try {
      final doc = await FirebaseFirestore.instance
          .doc('stations/station1/readings/latest')
          .get();

      if (!doc.exists || doc.data() == null) return;

      final data = doc.data()!;
      final pond = _ponds[0];

      pond.temperature =
          (data['temperature'] as num?)?.toDouble() ?? pond.temperature;

      pond.ph = (data['ph'] as num?)?.toDouble() ?? pond.ph;

      if (!_isLive) {
        _isLive = true;
        _simTimer?.cancel(); // stop simulation once real data arrives
        _simTimer = null;
      }

      _pushHistory(pond);
      pond.lastUpdated = DateTime.now();
      notifyListeners();

      NotificationService().checkAndNotify(
        turbidity: pond.turbidity,
        temperature: pond.temperature,
        ph: pond.ph,
        waterLevel: pond.waterLevel,
      );
    } catch (e) {
      debugPrint('Firestore fetch error: $e');
    }
  }

  void _startSimulation() {
    if (_simTimer != null) return;
    _simTimer = Timer.periodic(const Duration(seconds: 5), (_) => _simulate());
  }

  PondProfile get _selectedPond => _ponds[_selectedPondIndex];
  List<PondProfile> get ponds => List.unmodifiable(_ponds);
  int get selectedPondIndex => _selectedPondIndex;
  PondProfile get selectedPond => _selectedPond;
  DateTime get lastUpdated => _selectedPond.lastUpdated;
  String get selectedPondName => _selectedPond.name;

  SensorReading get turbidity => SensorReading(
    value: _selectedPond.turbidity,
    unit: 'NTU',
    status: _selectedPond.turbidity < 5
        ? 'Optimal'
        : _selectedPond.turbidity < 10
        ? 'Warning'
        : 'Critical',
  );

  SensorReading get temperature => SensorReading(
    value: _selectedPond.temperature,
    unit: '°C',
    status: _selectedPond.temperature >= 20 && _selectedPond.temperature <= 25
        ? 'Optimal'
        : _selectedPond.temperature >= 15 && _selectedPond.temperature <= 30
        ? 'Warning'
        : 'Critical',
  );

  SensorReading get ph => SensorReading(
    value: _selectedPond.ph,
    unit: 'pH',
    status: _selectedPond.ph >= 6.5 && _selectedPond.ph <= 8.5
        ? 'Optimal'
        : _selectedPond.ph >= 6.0 && _selectedPond.ph <= 9.0
        ? 'Warning'
        : 'Critical',
  );

  SensorReading get waterLevel => SensorReading(
    value: _selectedPond.waterLevel,
    unit: 'cm',
    status: _selectedPond.waterLevel >= 50 && _selectedPond.waterLevel <= 150
        ? 'Optimal'
        : _selectedPond.waterLevel >= 20 && _selectedPond.waterLevel <= 180
        ? 'Warning'
        : 'Critical',
  );

  List<double> get turbidityHistory => _selectedPond.turbidityHistory;
  List<double> get temperatureHistory => _selectedPond.temperatureHistory;
  List<double> get phHistory => _selectedPond.phHistory;
  List<double> get waterLevelHistory => _selectedPond.waterLevelHistory;

  bool get allOptimal =>
      turbidity.status == 'Optimal' &&
      temperature.status == 'Optimal' &&
      ph.status == 'Optimal' &&
      waterLevel.status == 'Optimal';

  void _simulate() {
    for (final pond in _ponds) _simulatePond(pond);
    notifyListeners();
    NotificationService().checkAndNotify(
      turbidity: _selectedPond.turbidity,
      temperature: _selectedPond.temperature,
      ph: _selectedPond.ph,
      waterLevel: _selectedPond.waterLevel,
    );
  }

  void refresh() {
    if (_isLive) {
      _fetchLatestReading(); // force a fresh Firestore fetch
      return;
    }
    _selectedPond.turbidity =
        (_selectedPond.turbidity + (_rng.nextDouble() - 0.5) * 1.2).clamp(
          0.5,
          15.0,
        );
    _selectedPond.temperature =
        (_selectedPond.temperature + (_rng.nextDouble() - 0.5) * 1.0).clamp(
          15.0,
          32.0,
        );
    _selectedPond.ph = (_selectedPond.ph + (_rng.nextDouble() - 0.5) * 0.4)
        .clamp(5.5, 9.5);
    _selectedPond.waterLevel =
        (_selectedPond.waterLevel + (_rng.nextDouble() - 0.5) * 8.0).clamp(
          0.0,
          200.0,
        );
    _roundPond(_selectedPond);
    _pushHistory(_selectedPond);
    _selectedPond.lastUpdated = DateTime.now();
    notifyListeners();
  }

  void selectPond(int index) {
    if (index < 0 || index >= _ponds.length || index == _selectedPondIndex)
      return;
    _selectedPondIndex = index;
    notifyListeners();
  }

  void addPond(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _ponds.add(
      PondProfile(
        id: 'pond-${DateTime.now().millisecondsSinceEpoch}',
        name: trimmed,
        turbidity: 2.0 + _rng.nextDouble() * 2.0,
        temperature: 21.0 + _rng.nextDouble() * 3.0,
        ph: 6.8 + _rng.nextDouble() * 0.8,
        waterLevel: 95.0 + _rng.nextDouble() * 40.0,
      ),
    );
    _roundPond(_ponds.last);
    _selectedPondIndex = _ponds.length - 1;
    notifyListeners();
  }

  void renameSelectedPond(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _selectedPond.name = trimmed;
    notifyListeners();
  }

  void _simulatePond(PondProfile pond) {
    pond.turbidity = (pond.turbidity + (_rng.nextDouble() - 0.5) * 0.4).clamp(
      0.5,
      15.0,
    );
    pond.temperature = (pond.temperature + (_rng.nextDouble() - 0.5) * 0.3)
        .clamp(15.0, 32.0);
    pond.ph = (pond.ph + (_rng.nextDouble() - 0.5) * 0.1).clamp(5.5, 9.5);
    pond.waterLevel = (pond.waterLevel + (_rng.nextDouble() - 0.5) * 3.0).clamp(
      0.0,
      200.0,
    );
    _roundPond(pond);
    _pushHistory(pond);
    pond.lastUpdated = DateTime.now();
  }

  void _roundPond(PondProfile pond) {
    pond.turbidity = double.parse(pond.turbidity.toStringAsFixed(1));
    pond.temperature = double.parse(pond.temperature.toStringAsFixed(1));
    pond.ph = double.parse(pond.ph.toStringAsFixed(2));
    pond.waterLevel = double.parse(pond.waterLevel.toStringAsFixed(1));
  }

  void _pushHistory(PondProfile pond) {
    pond.turbidityHistory.add(pond.turbidity);
    pond.temperatureHistory.add(pond.temperature);
    pond.phHistory.add(pond.ph);
    pond.waterLevelHistory.add(pond.waterLevel);
    if (pond.turbidityHistory.length > 24) pond.turbidityHistory.removeAt(0);
    if (pond.temperatureHistory.length > 24)
      pond.temperatureHistory.removeAt(0);
    if (pond.phHistory.length > 24) pond.phHistory.removeAt(0);
    if (pond.waterLevelHistory.length > 24) pond.waterLevelHistory.removeAt(0);
  }

  void addPondFull(String name, String fishType, String size) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _ponds.add(
      PondProfile(
        id: 'pond-${DateTime.now().millisecondsSinceEpoch}',
        name: trimmed,
        fishType: fishType,
        pondSize: size,
        turbidity: 2 + _rng.nextDouble() * 2,
        temperature: 22 + _rng.nextDouble() * 3,
        ph: 7 + _rng.nextDouble(),
        waterLevel: 100 + _rng.nextDouble() * 30,
      ),
    );
    _selectedPondIndex = _ponds.length - 1;
    notifyListeners();
  }

  void deletePond(int index) {
    if (_ponds.length <= 1) return;
    _ponds.removeAt(index);
    _selectedPondIndex = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _simTimer?.cancel();
    super.dispose();
  }
}

// ─────────────────────────────────────────────
// REPLACE THIS SECTION IN YOUR main.dart
// Add this import at the top of main.dart:
//   import 'profile_page.dart';
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
        children: const [
          DashboardPage(),
          AnalyticsPage(),
          PondManagePage(),
          ProfilePage(), // ← new tab
        ],
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _navItem(0, Icons.water_drop_outlined, Icons.water_drop, 'Dashboard'),
          _navItem(1, Icons.bar_chart_outlined, Icons.bar_chart, 'Analytics'),
          _navItem(2, Icons.water_outlined, Icons.water, 'Pond'),
          _navItem(
            3,
            Icons.person_outline,
            Icons.person_rounded,
            'Profile',
          ), // ← new
        ],
      ),
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
            color: s
                ? const Color(0xFF00D4FF).withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                s ? activeIcon : icon,
                color: s
                    ? const Color(0xFF00D4FF)
                    : Colors.white.withOpacity(0.35),
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: s ? FontWeight.w600 : FontWeight.w400,
                  color: s
                      ? const Color(0xFF00D4FF)
                      : Colors.white.withOpacity(0.35),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
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
    return '$h:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AquaMonitorState>();
    final sensors = [
      _SensorConfig(
        name: 'Turbidity',
        reading: state.turbidity,
        icon: Icons.water,
        accentColor: const Color(0xFF00D4FF),
        idealRange: '< 5 NTU',
        minAbsolute: 0,
        maxAbsolute: 15,
        minIdeal: 0,
        maxIdeal: 5,
        description:
            'Measures water clarity. Lower values indicate clearer water. High turbidity can indicate contamination or suspended particles.',
      ),
      _SensorConfig(
        name: 'Temperature',
        reading: state.temperature,
        icon: Icons.thermostat_outlined,
        accentColor: const Color(0xFFFF6B6B),
        idealRange: '20 – 25°C',
        minAbsolute: 0,
        maxAbsolute: 40,
        minIdeal: 20,
        maxIdeal: 25,
        description:
            'Water temperature affects dissolved oxygen and aquatic life. The ideal range sustains healthy biological activity.',
      ),
      _SensorConfig(
        name: 'pH Level',
        reading: state.ph,
        icon: Icons.science_outlined,
        accentColor: const Color(0xFF7ED321),
        idealRange: '6.5 – 8.5',
        minAbsolute: 0,
        maxAbsolute: 14,
        minIdeal: 6.5,
        maxIdeal: 8.5,
        description:
            'Indicates acidity or alkalinity. Neutral water is pH 7. Safe drinking water falls within 6.5–8.5 for most uses.',
      ),
      // NEW
      _SensorConfig(
        name: 'Water Level',
        reading: state.waterLevel,
        icon: Icons.water_outlined,
        accentColor: const Color(0xFF7B61FF),
        idealRange: '50 – 150 cm',
        minAbsolute: 0,
        maxAbsolute: 200,
        minIdeal: 50,
        maxIdeal: 150,
        description:
            'Measures the depth of water in the reservoir in centimetres. Below 50 cm risks depletion; above 150 cm risks overflow.',
      ),
    ];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(context, state)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: _StatusBanner(allOptimal: state.allOptimal),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Live Readings',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                Row(
                  children: [
                    _SimBadge(),
                    const SizedBox(width: 8),
                    _RefreshBtn(onTap: state.refresh),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ReadingCard(config: sensors[i]),
              ),
              childCount: sensors.length,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: const Text(
              'Learn More',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              InfoCard(config: sensors[0]),
              const SizedBox(height: 12),
              InfoCard(config: sensors[2]),
              const SizedBox(height: 12),
              InfoCard(config: sensors[3]), // NEW
              const SizedBox(height: 16),
              Center(
                child: Text(
                  '${state.isLive ? "Live data" : "Simulated"} · last ${_fmt(state.lastUpdated)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.25),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, AquaMonitorState state) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 20,
        20,
        24,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00D4FF), Color(0xFF0080FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D4FF).withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.water_drop,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AQuality',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Water Quality Monitor',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.45),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Consumer<AquaMonitorState>(
                builder: (_, state, __) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: state.isLive
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: state.isLive
                          ? Colors.green.withOpacity(0.25)
                          : Colors.orange.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        state.isLive ? Icons.sensors : Icons.developer_board,
                        size: 12,
                        color: state.isLive ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        state.isLive ? 'Live' : 'Simulated',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: state.isLive ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _PondSelectorCard(state: state),
        ],
      ),
    );
  }
}

class _PondSelectorCard extends StatelessWidget {
  final AquaMonitorState state;
  const _PondSelectorCard({required this.state});

  Future<void> _showPondDialog(
    BuildContext context, {
    required String title,
    required String initialValue,
    required String actionLabel,
    required ValueChanged<String> onSubmit,
  }) async {
    final controller = TextEditingController(text: initialValue);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0E1628),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter pond name',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFF00D4FF)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              onSubmit(value);
              Navigator.of(dialogContext).pop();
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1628),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4FF).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.filter_alt_outlined,
                  color: Color(0xFF00D4FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Measured Pond',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Readings shown below belong to ${state.selectedPondName}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            value: state.selectedPondIndex,
            dropdownColor: const Color(0xFF152039),
            iconEnabledColor: Colors.white,
            decoration: InputDecoration(
              labelText: 'Current pond',
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.65)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.03),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
              ),
            ),
            items: [
              for (var i = 0; i < state.ponds.length; i++)
                DropdownMenuItem<int>(
                  value: i,
                  child: Text(
                    state.ponds[i].name,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) state.selectPond(value);
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
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
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.memory, size: 10, color: Colors.orange),
          SizedBox(width: 4),
          Text(
            'SIM',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.orange,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
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
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.refresh_rounded,
              size: 14,
              color: Colors.white.withOpacity(0.55),
            ),
            const SizedBox(width: 5),
            Text(
              'Refresh',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.55),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final bool allOptimal;
  const _StatusBanner({required this.allOptimal});
  @override
  Widget build(BuildContext context) {
    final color = allOptimal
        ? const Color(0xFF00FF88)
        : const Color(0xFFFFB800);
    final icon = allOptimal
        ? Icons.check_circle_rounded
        : Icons.warning_amber_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.10), color.withOpacity(0.04)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                allOptimal ? 'All Systems Optimal' : 'Attention Required',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                allOptimal
                    ? 'All parameters within safe range'
                    : 'One or more parameters need review',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color, blurRadius: 6, spreadRadius: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReadingCard extends StatelessWidget {
  final _SensorConfig config;
  const ReadingCard({super.key, required this.config});

  Color _sc(String s) {
    switch (s) {
      case 'Optimal':
        return const Color(0xFF00FF88);
      case 'Warning':
        return const Color(0xFFFFB800);
      default:
        return const Color(0xFFFF4444);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sc = _sc(config.reading.status);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1628),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: config.accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      config.icon,
                      color: config.accentColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        'Ideal: ${config.idealRange}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.35),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              _StatusChip(status: config.reading.status, color: sc),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                config.reading.value.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  color: config.accentColor,
                  letterSpacing: -1.5,
                  height: 1.0,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 5, left: 5),
                child: Text(
                  config.reading.unit,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _RangeBar(config: config),
          const SizedBox(height: 10),
          Text(
            'Auto-updates every 30s',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.28),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusChip({required this.status, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
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
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: CustomPaint(
              painter: _RangeBarPainter(
                iS: iS,
                iE: iE,
                v: config.normalizedValue,
                c: config.accentColor,
              ),
              size: const Size(double.infinity, 6),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${config.minAbsolute.toInt()}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.25),
              ),
            ),
            Text(
              'Ideal range',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
            Text(
              '${config.maxAbsolute.toInt()}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.25),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RangeBarPainter extends CustomPainter {
  final double iS, iE, v;
  final Color c;
  const _RangeBarPainter({
    required this.iS,
    required this.iE,
    required this.v,
    required this.c,
  });
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, s.width, s.height),
      Paint()..color = Colors.white.withOpacity(0.07),
    );
    canvas.drawRect(
      Rect.fromLTWH(iS * s.width, 0, (iE - iS) * s.width, s.height),
      Paint()..color = c.withOpacity(0.18),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, v * s.width, s.height),
      Paint()
        ..shader = LinearGradient(
          colors: [c.withOpacity(0.6), c],
        ).createShader(Rect.fromLTWH(0, 0, v * s.width, s.height)),
    );
  }

  @override
  bool shouldRepaint(_RangeBarPainter o) => v != o.v;
}

class InfoCard extends StatelessWidget {
  final _SensorConfig config;
  const InfoCard({super.key, required this.config});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1628),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: config.accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(config.icon, color: config.accentColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About ${config.name}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  config.description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Colors.white.withOpacity(0.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
