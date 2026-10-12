import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'monthly_usage_service.dart';

class UsageNotificationService {
  UsageNotificationService._();

  static final UsageNotificationService instance = UsageNotificationService._();

  static const _lastMessageKey = 'last_usage_notification_message';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(initSettings);

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<String?> checkAndNotify() async {
    await initialize();

    final summary = await MonthlyUsageService.instance.loadSummary();
    if (summary == null || !summary.hasEnoughData) {
      return null;
    }

    final message = summary.comparisonMessage;
    final prefs = await SharedPreferences.getInstance();
    final lastMessage = prefs.getString(_lastMessageKey);

    if (lastMessage == message) {
      return message;
    }

    await prefs.setString(_lastMessageKey, message);
    await _showNotification(message, summary);
    return message;
  }

  Future<void> _showNotification(
    String message,
    MonthlyUsageSummary summary,
  ) async {
    const androidDetails = AndroidNotificationDetails(
      'monthly_usage_channel',
      'Monthly Usage Alerts',
      channelDescription: 'Compares this month and last month electricity usage',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const details = NotificationDetails(android: androidDetails);

    final title = summary.percentChange == null
        ? 'Monthly Usage Update'
        : summary.percentChange! > 0
            ? 'Usage Higher Than Last Month'
            : summary.percentChange! < 0
                ? 'Usage Lower Than Last Month'
                : 'Monthly Usage Stable';

    await _notifications.show(
      summary.currentMonth.monthKey.hashCode,
      title,
      message,
      details,
    );

    if (kDebugMode) {
      debugPrint('Usage notification: $message');
    }
  }
}
