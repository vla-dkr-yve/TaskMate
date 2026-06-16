import 'package:flutter_application_1/models/task.dart';
import 'package:flutter_application_1/services/database_service.dart';
import 'package:flutter_application_1/pages/settings_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../constants/notification_settings.dart';

class NotificationService {
  static NotificationService? _ns;
  static final NotificationService instance = NotificationService._constructor();

  NotificationService._constructor();

  final DatabaseService _databaseService = DatabaseService.instance;

  final notificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> initNotification() async {
    if (_isInitialized) return;

    const initSettingsAndroid =
        AndroidInitializationSettings('ic_notification');

    const initSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestCriticalPermission: true,
    );

    const initSetting = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingsIOS,
    );

    await notificationsPlugin.initialize(settings: initSetting);

    await notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();

    _isInitialized = true;
  }

  // ── Notification details ──────────────────────────────────────────────────

  NotificationDetails notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_channel_id',
        'Daily Notifications',
        channelDescription: 'Daily Notification Channel',
        importance: Importance.max,
        priority: Priority.high,
        icon: 'ic_notification'
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  // ── Immediate (show-now) notification ────────────────────────────────────

  Future<void> showNotification({
    int id = 0,
    String? title,
    String? body,
  }) async {
    return notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails(),
    );
  }

  // ── Read user settings ────────────────────────────────────────────────────

  Future<String> _getNotificationMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(NotificationSettings.keyNotificationMode) ?? 'per_hour';
  }

  Future<int> _getMinutesBefore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(NotificationSettings.keyMinutesBefore) ?? 15;
  }

  // ── Load & schedule all of today's notifications ──────────────────────────

  Future<void> loadTasksAndScheduleNotifications() async {
    await notificationsPlugin.cancelAll();
    
    final mode = await _getNotificationMode();
    print('Notification mode: $mode');

    List<Task> tasks = await _databaseService.GetTasksWithTimeForSelectedDay(
      DateTime.now(),
      DateTime.now().weekday,
    );

    print('Tasks fetched: ${tasks.length}');
print('Tasks: ${tasks.map((t) => "${t.title} ${t.startTime}").toList()}');

    final now = DateTime.now();

    // Keep only future tasks
    tasks = tasks.where((task) {
      if (task.startTime == null) return false;
      final parts = task.startTime!.split(':');
      final taskTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      return taskTime.isAfter(now);
    }).toList();

    if (mode == 'per_hour') {
      await _schedulePerHour(tasks);
    } else {
      final minutesBefore = await _getMinutesBefore();
      await _schedulePerTask(tasks, minutesBefore);
    }
  }

  // ── Per-hour mode (original behaviour) ───────────────────────────────────

  Future<void> _schedulePerHour(List<Task> tasks) async {
    final Map<int, List<Task>> tasksByHour = {};

    for (var task in tasks) {
      if (task.startTime == null) continue;
      final hour = int.parse(task.startTime!.split(':')[0]);
      tasksByHour.putIfAbsent(hour, () => []).add(task);
    }

    for (final entry in tasksByHour.entries) {
      await _scheduleHourlyNotification(entry.value);
    }
  }

  Future<void> _scheduleHourlyNotification(List<Task> tasks) async {
    final hour = int.parse(tasks[0].startTime!.split(':')[0]);

    final now = tz.TZDateTime.now(tz.local);
    final scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      0,
    );

    if (!scheduledDate.isAfter(now)) return;

    print('Scheduling notification for: ${tasks.length} size at $scheduledDate');

    final messageText = _createMessageText(tasks);

    await notificationsPlugin.zonedSchedule(
      id: hour,
      title: 'You have ${tasks.length} upcoming activitie(s)',
      body: messageText,
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // ── Per-task mode (one notification per task, offset by minutesBefore) ───

  Future<void> _schedulePerTask(List<Task> tasks, int minutesBefore) async {
    for (final task in tasks) {
      await _scheduleTaskNotification(task, minutesBefore);
    }
  }

  Future<void> _scheduleTaskNotification(Task task, int minutesBefore) async {
    if (task.startTime == null) return;

    final parts = task.startTime!.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final now = tz.TZDateTime.now(tz.local);

    // Fire at (startTime - minutesBefore)
    final taskDateTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    final scheduledDate =
        taskDateTime.subtract(Duration(minutes: minutesBefore));

    if (!scheduledDate.isAfter(now)) return;

    print('Scheduling notification for: ${task.title} at $scheduledDate');
    // Use a unique ID per task so notifications don't overwrite each other.
    // Encode hour*60+minute to keep it stable across rescheduling.

    await notificationsPlugin.zonedSchedule(
      id: task.occuranceId,
      title: 'Upcoming: ${task.title}',
      body: minutesBefore == 1
          ? 'Starting in 1 minute  •  ${task.startTime}${task.endTime != null ? ' – ${task.endTime}' : ''}'
          : 'Starting in $minutesBefore minutes  •  ${task.startTime}${task.endTime != null ? ' – ${task.endTime}' : ''}',
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // ── Reschedule a single task (called after add / edit / delete) ───────────

  Future<void> scheduleNotificationForOneTask(Task task) async {

  final mode = await _getNotificationMode();
  print('Notification mode: $mode');

  if (mode == 'per_hour') {
    final hour = int.parse(task.startTime!.split(':')[0]);
    await notificationsPlugin.cancel(id: hour);
    final tasksForHour = await _databaseService.GetTasksForHour(hour);
    await _scheduleHourlyNotification(tasksForHour);
  } else {
    await notificationsPlugin.cancel(id: task.occuranceId);

    if (task.deletedAt != null || task.isDone) return;

    final minutesBefore = await _getMinutesBefore();
    await _scheduleTaskNotification(task, minutesBefore);
  }
}

Future<void> removeScheduledNotificationForOneTask(Task task) async {
    await notificationsPlugin.cancel(id: task.occuranceId);
}

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _createMessageText(List<Task> tasks) {
    if (tasks.length == 1) {
      final t = tasks[0];
      return '${t.title}: ${t.startTime} - ${t.endTime}';
    }
    return tasks.map((t) => t.title).join(', ');
  }
}
