import 'package:flutter_application_1/models/task.dart';
import 'package:flutter_application_1/services/database_service.dart';
import 'package:flutter_application_1/pages/settings_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../constants/notification_settings.dart';

// Pre-scheduling constant
const int _kScheduleDays = 3;

class NotificationService {
  static NotificationService? _ns;
  static final NotificationService instance = NotificationService._constructor();

  NotificationService._constructor();

  final DatabaseService _databaseService = DatabaseService.instance;

  final notificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  // Initiation

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

  // Notification platform specific details

  NotificationDetails notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_channel_id',
        'Daily Notifications',
        channelDescription: 'Daily Notification Channel',
        importance: Importance.max,
        priority: Priority.high,
        icon: 'ic_notification',
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  // Read user settings from SharedRefferences

  Future<String> _getNotificationMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(NotificationSettings.keyNotificationMode) ?? 'per_hour';
  }

  Future<int> _getMinutesBefore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(NotificationSettings.keyMinutesBefore) ?? 15;
  }

  // ID algorithm
  //
  // Notification IDs must be unique across all scheduled notifications.
  // We pack: dayOffset (0 = today, 1 = tomorrow, …) and a per-day key
  // (hour 0-23 for per_hour mode, occuranceId for per_task mode) into one int:
  //
  //   id = dayOffset * 10_000 + perDayKey
  //
  // This supports up to 9 days ahead and occuranceIds / hours up to 9999,
  // which is more than sufficient for typical usage.

  int _notifId(int dayOffset, int perDayKey) => dayOffset * 10000 + perDayKey;

  // Load & schedule notifications for the next _kScheduleDays days

  Future<void> loadTasksAndScheduleNotifications() async {
    await notificationsPlugin.cancelAll();

    final mode = await _getNotificationMode();
    final minutesBefore = mode == 'per_task' ? await _getMinutesBefore() : 0;

    print('Notification mode: $mode, scheduling $_kScheduleDays day(s) ahead');

    final now = DateTime.now();

    for (int dayOffset = 0; dayOffset < _kScheduleDays; dayOffset++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: dayOffset));

      List<Task> tasks = await _databaseService.GetTasksWithTimeForSelectedDay(
        day,
        day.weekday,
      );

      print('Day +$dayOffset (${day.toIso8601String().substring(0, 10)}): ${tasks.length} task(s) with time');

      // For today, skip tasks that are already in the past.
      if (dayOffset == 0) {
        tasks = tasks.where((task) {
          if (task.startTime == null) return false;
          final parts = task.startTime!.split(':');
          final taskTime = DateTime(
            now.year, now.month, now.day,
            int.parse(parts[0]), int.parse(parts[1]),
          );
          if (mode == 'per_hour') {
            return taskTime.isAfter(now);
          } else {
            final fireTime = taskTime.subtract(Duration(minutes: minutesBefore));
            return fireTime.isAfter(now);
          }
        }).toList();
      }

      if (mode == 'per_hour') {
        await _schedulePerHour(tasks, day, dayOffset);
      } else {
        await _schedulePerTask(tasks, minutesBefore, day, dayOffset);
      }
    }
  }

  // Per-hour mode

  Future<void> _schedulePerHour(List<Task> tasks, DateTime day, int dayOffset) async {
    final Map<int, List<Task>> tasksByHour = {};

    for (final task in tasks) {
      if (task.startTime == null) continue;
      final hour = int.parse(task.startTime!.split(':')[0]);
      tasksByHour.putIfAbsent(hour, () => []).add(task);
    }

    for (final entry in tasksByHour.entries) {
      await _scheduleHourlyNotification(entry.value, day, dayOffset);
    }
  }

  Future<void> _scheduleHourlyNotification(
      List<Task> tasks, DateTime day, int dayOffset) async {
    final hour = int.parse(tasks[0].startTime!.split(':')[0]);

    final now = tz.TZDateTime.now(tz.local);
    final scheduledDate = tz.TZDateTime(
      tz.local,
      day.year, day.month, day.day,
      hour, 0,
    );

    if (!scheduledDate.isAfter(now)) return;

    final id = _notifId(dayOffset, hour);
    final messageText = _createMessageText(tasks);

    print('Scheduling per-hour notification id=$id for $scheduledDate');

    await notificationsPlugin.zonedSchedule(
      id: id,
      title: 'You have ${tasks.length} upcoming activitie(s)',
      body: messageText,
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // Per-task mode

  Future<void> _schedulePerTask(
      List<Task> tasks, int minutesBefore, DateTime day, int dayOffset) async {
    for (final task in tasks) {
      await _scheduleTaskNotification(task, minutesBefore, day, dayOffset);
    }
  }

  Future<void> _scheduleTaskNotification(
      Task task, int minutesBefore, DateTime day, int dayOffset) async {
    if (task.startTime == null) return;

    final parts = task.startTime!.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final now = tz.TZDateTime.now(tz.local);

    final taskDateTime = tz.TZDateTime(
      tz.local,
      day.year, day.month, day.day,
      hour, minute,
    );

    final scheduledDate = taskDateTime.subtract(Duration(minutes: minutesBefore));

    if (!scheduledDate.isAfter(now)) return;

    final id = _notifId(dayOffset, task.occuranceId);

    print('Scheduling per-task notification id=$id for "${task.title}" at $scheduledDate');

    await notificationsPlugin.zonedSchedule(
      id: id,
      title: 'Upcoming: ${task.title}',
      body: minutesBefore == 1
          ? 'Starting in 1 minute  •  ${task.startTime}${task.endTime != null ? ' – ${task.endTime}' : ''}'
          : 'Starting in $minutesBefore minutes  •  ${task.startTime}${task.endTime != null ? ' – ${task.endTime}' : ''}',
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // Reschedule a single task (called after add / edit / delete)

  Future<void> scheduleNotificationForOneTask(Task task) async {
    final mode = await _getNotificationMode();
    print('Notification mode: $mode');

    final now = DateTime.now();

    if (mode == 'per_hour') {
      final hour = int.parse(task.startTime!.split(':')[0]);

      // Reschedule the affected hour-bucket for each pre-loaded day.
      for (int dayOffset = 0; dayOffset < _kScheduleDays; dayOffset++) {
        final day = DateTime(now.year, now.month, now.day).add(Duration(days: dayOffset));
        final id = _notifId(dayOffset, hour);
        await notificationsPlugin.cancel(id: id);

        final tasksForHour = await _databaseService.GetTasksForHour(hour, day);
        if (tasksForHour.isNotEmpty) {
          await _scheduleHourlyNotification(tasksForHour, day, dayOffset);
        }
      }
    } else {
      // Cancel this task's notification for every pre-loaded day.
      for (int dayOffset = 0; dayOffset < _kScheduleDays; dayOffset++) {
        final id = _notifId(dayOffset, task.occuranceId);
        await notificationsPlugin.cancel(id: id);
      }

      if (task.deletedAt != null || task.isDone) return;

      final minutesBefore = await _getMinutesBefore();

      // Re-schedule for each day this occurrence applies to.
      // For a recurring (weekday-based) task this fires on multiple days;
      // for a date-specific task it only fires on dayOffset == 0 or the
      // matching future offset. The DB query already handles the filtering.
      for (int dayOffset = 0; dayOffset < _kScheduleDays; dayOffset++) {
        final day = DateTime(now.year, now.month, now.day).add(Duration(days: dayOffset));
        await _scheduleTaskNotification(task, minutesBefore, day, dayOffset);
      }
    }
  }

  // Helpers

  String _createMessageText(List<Task> tasks) {
    if (tasks.length == 1) {
      final t = tasks[0];
      return '${t.title}: ${t.startTime} - ${t.endTime}';
    }
    return tasks.map((t) => t.title).join(', ');
  }
}
