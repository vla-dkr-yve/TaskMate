import 'package:flutter_application_1/models/task.dart';
import 'package:flutter_application_1/services/database_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService{
  
    static NotificationService? _ns;
    static final NotificationService instance = NotificationService._constructor();

    NotificationService._constructor() {}

    final DatabaseService _databaseService = DatabaseService.instance;

    final notificationsPlugin = FlutterLocalNotificationsPlugin();

    bool _isInitialized = false;

    bool get isInitialized => _isInitialized;

    // initialize
    Future<void> initNotification() async {
      if (isInitialized) {
        return;
      }

      //android init setting

      const initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');

      //ios init setting
      const initSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestCriticalPermission: true,
      );

      const initSetting = InitializationSettings(
        android: initSettingsAndroid,
        iOS: initSettingsIOS
      );


      await notificationsPlugin.initialize(settings: initSetting);

       await notificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  await notificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestExactAlarmsPermission();

      _isInitialized = true;
    }

    //Notification details
    NotificationDetails notificationDetails(){
      return const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_channel_id', 
          'Daily Notifications',
          channelDescription: 'Daily Notification Channel',
          importance: Importance.max,
          priority: Priority.high
          ),
        iOS: DarwinNotificationDetails()
      );
    }

    Future<void> ShowNotification({int id = 0,
      String? title, 
      String? body,
      }) async{
      return notificationsPlugin.show(
        id: id, 
        title: title, 
        body: body, 
        notificationDetails: notificationDetails());
    }

  Future<void> LoadTasksAndScheduleNotifications() async{

    List<Task> tasks = await _databaseService.GetTasksWithTimeForSelectedDay(DateTime.now(), DateTime.now().weekday) ; 

    final now = DateTime.now();

    tasks = tasks.where((task) {
      if (task.startTime == null) return false;

      final parts = task.startTime!.split(":");
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final taskTime = DateTime(
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      return taskTime.isAfter(now);
      }).toList();

      Map<int, List<Task>> tasksByHour = {};

      tasksByHour.clear();

      for (var task in tasks) {
        if (task.startTime == null) continue;

        final hour = int.parse(task.startTime!.split(":")[0]);

        if (!tasksByHour.containsKey(hour)) {
          tasksByHour[hour] = [];
        } 

        tasksByHour[hour]!.add(task);
      }

      for (var x in tasksByHour.values) {
        scheduleNotification(x);
      }

      return;
  }

  Future<void> scheduleNotification(List<Task> tasks) async {

    final hour = int.parse(tasks[0].startTime!.split(":")[0]);

    final now = tz.TZDateTime.now(tz.local);

    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      0
      );
    
    if (!scheduledDate.isAfter(now)) return;

    String message_text = CreateMessageText(tasks);

    await notificationsPlugin.zonedSchedule(
      id: hour,
      title: 'You have ${tasks.length} upcomming activitie(s)',
      body: message_text,
      scheduledDate: scheduledDate,
      notificationDetails:  notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle
    );
  }

  String CreateMessageText(List<Task> tasks) {
  if (tasks.length == 1) {
    final t = tasks[0];
    return "${t.title}: ${t.startTime} - ${t.endTime}";
  }
    return tasks.map((t) => t.title).join(", ");
  }

  Future<void> scheduleNotificationForOneTask(Task task) async{
    if (task.startTime == null) return;

    final hour = int.parse(task.startTime!.split(":")[0]);

    final tasksForHour = await _databaseService.GetTasksForHour(hour);

    // cancel existing notification for that hour
    await notificationsPlugin.cancel(id:hour);

    // reschedule that hour
    await scheduleNotification(tasksForHour);
  }
}