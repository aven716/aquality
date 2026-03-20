import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

// ════════════════════════════════════════════
// NOTIFICATION SERVICE
// ════════════════════════════════════════════

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Track last notified status to avoid spamming
  final Map<String, String> _lastStatus = {};

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {},
    );

    // Request permission on Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  // ── Show a notification ───────────────────────────────────
  Future<void> _show({
    required int id,
    required String title,
    required String body,
    required Color color,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'aquality_alerts',
      'Water Quality Alerts',
      channelDescription: 'Alerts for critical water quality readings',
      importance: Importance.high,
      priority: Priority.high,
      color: color,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  // ── Check all sensor values ───────────────────────────────
  Future<void> checkAndNotify({
    required double turbidity,
    required double temperature,
    required double ph,
    required double waterLevel,
  }) async {
    await _checkTurbidity(turbidity);
    await _checkTemperature(temperature);
    await _checkPh(ph);
    await _checkWaterLevel(waterLevel);
  }

  // ── Turbidity ─────────────────────────────────────────────
  Future<void> _checkTurbidity(double value) async {
    final status = value >= 10
        ? 'Critical'
        : value >= 5
        ? 'Warning'
        : 'Optimal';

    if (_lastStatus['turbidity'] == status) return;
    _lastStatus['turbidity'] = status;

    if (status == 'Critical') {
      await _show(
        id: 1,
        title: '🚨 Turbidity Critical',
        body:
            'Turbidity is ${value.toStringAsFixed(1)} NTU — dangerously high! Immediate action required.',
        color: const Color(0xFFFF4444),
      );
    } else if (status == 'Warning') {
      await _show(
        id: 1,
        title: '⚠️ Turbidity Warning',
        body:
            'Turbidity is ${value.toStringAsFixed(1)} NTU — above ideal range.',
        color: const Color(0xFFFFB800),
      );
    }
  }

  // ── Temperature ───────────────────────────────────────────
  Future<void> _checkTemperature(double value) async {
    final status = (value < 15 || value > 30)
        ? 'Critical'
        : (value < 20 || value > 25)
        ? 'Warning'
        : 'Optimal';

    if (_lastStatus['temperature'] == status) return;
    _lastStatus['temperature'] = status;

    if (status == 'Critical') {
      await _show(
        id: 2,
        title: '🚨 Temperature Critical',
        body:
            'Temperature is ${value.toStringAsFixed(1)}°C — outside safe range!',
        color: const Color(0xFFFF4444),
      );
    } else if (status == 'Warning') {
      await _show(
        id: 2,
        title: '⚠️ Temperature Warning',
        body:
            'Temperature is ${value.toStringAsFixed(1)}°C — outside ideal range.',
        color: const Color(0xFFFFB800),
      );
    }
  }

  // ── pH ────────────────────────────────────────────────────
  Future<void> _checkPh(double value) async {
    final status = (value < 6.0 || value > 9.0)
        ? 'Critical'
        : (value < 6.5 || value > 8.5)
        ? 'Warning'
        : 'Optimal';

    if (_lastStatus['ph'] == status) return;
    _lastStatus['ph'] = status;

    if (status == 'Critical') {
      await _show(
        id: 3,
        title: '🚨 pH Level Critical',
        body: 'pH is ${value.toStringAsFixed(2)} — dangerously out of range!',
        color: const Color(0xFFFF4444),
      );
    } else if (status == 'Warning') {
      await _show(
        id: 3,
        title: '⚠️ pH Level Warning',
        body: 'pH is ${value.toStringAsFixed(2)} — outside ideal range.',
        color: const Color(0xFFFFB800),
      );
    }
  }

  // ── Water Level ───────────────────────────────────────────
  Future<void> _checkWaterLevel(double value) async {
    final status = (value < 20 || value > 180)
        ? 'Critical'
        : (value < 50 || value > 150)
        ? 'Warning'
        : 'Optimal';

    if (_lastStatus['waterLevel'] == status) return;
    _lastStatus['waterLevel'] = status;

    if (status == 'Critical') {
      await _show(
        id: 4,
        title: '🚨 Water Level Critical',
        body:
            'Water level is ${value.toStringAsFixed(1)} cm — ${value < 20 ? 'dangerously low' : 'overflow risk'}!',
        color: const Color(0xFFFF4444),
      );
    } else if (status == 'Warning') {
      await _show(
        id: 4,
        title: '⚠️ Water Level Warning',
        body:
            'Water level is ${value.toStringAsFixed(1)} cm — outside ideal range.',
        color: const Color(0xFFFFB800),
      );
    }
  }

  // ── Reset (call on logout) ────────────────────────────────
  void reset() => _lastStatus.clear();
}
