//Think about adding google calendar API support
//Add icon

import 'package:flutter/material.dart';
import 'package:flutter_application_1/bar%20graph/bar_graph.dart';
import 'package:flutter_application_1/models/task.dart';
import 'package:flutter_application_1/pages/calendar_page.dart';
import 'package:flutter_application_1/pages/settings_page.dart';
import 'package:flutter_application_1/services/database_service.dart';
import 'package:flutter_application_1/services/task_dialog_service.dart';
import 'package:flutter_application_1/widgets/streak_widget.dart';
import 'package:intl/intl.dart';
import 'package:auto_size_text/auto_size_text.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseService _databaseService = DatabaseService.instance;

  int currentPage = 0;

  // Key lets us force StreakWidget to reload when user returns to home tab
  Key _streakKey = UniqueKey();

  List<double> weekleSummary = [0, 0, 0, 0, 0, 0, 0];

  List<Task> todayTasks = [];
  List<Task> todayTasksWOTime = [];
  List<Task> todayTasksWTime = [];
  Map<int, List<Task>> tasksByHour = {};

  @override
  void initState() {
    super.initState();
    getPercentage();
    getTasks();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePageContent(
        databaseService: _databaseService,
        weeklySummary: weekleSummary,
        streakKey: _streakKey,
        todayTasksWOTime: todayTasksWOTime,
        todayTasksWTime: todayTasksWTime,
        tasksByHour: tasksByHour,
      ),
      const CalendarPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      appBar: topBar(),
      backgroundColor: Colors.grey[300],
      body: pages[currentPage],
      bottomNavigationBar: bottomNavBar(),
    );
  }

  AppBar topBar() {
    return AppBar(
      title: const Text(
        'TaskMate',
        style: TextStyle(
          color: Colors.black,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      backgroundColor: Colors.grey[300],
    );
  }

  BottomNavigationBar bottomNavBar() {
    return BottomNavigationBar(
      currentIndex: currentPage,
      onTap: (value) async {
        setState(() {
          currentPage = value;
        });

        if (value == 0) {
          await getPercentage();
          await getTasks();
          // Refresh streak when returning to home
          setState(() => _streakKey = UniqueKey());
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_month_outlined),
          label: 'Calendar',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          label: 'Settings',
        ),
      ],
    );
  }

  Future<void> getPercentage() async {
    List<double> one =
        await _databaseService.getDonePercentage(DateTime.now());

    setState(() {
      weekleSummary = one;
    });
  }

  Future<void> getTasks() async {
    final tasks = await _databaseService.GetTasksForSelectedDay(
        DateTime.now(), DateTime.now().weekday);

    setState(() {
      todayTasks = tasks;
    });
    await getTasksTime();
    groupTasksByHour();
  }

  Future<void> getTasksTime() async {
    final List<Task> tasksWTime = [];
    final List<Task> tasksWOTime = [];

    for (var e in todayTasks) {
      if (e.startTime == null) {
        tasksWOTime.add(e);
      } else {
        tasksWTime.add(e);
      }
    }
    setState(() {
      todayTasksWOTime = tasksWOTime;
      todayTasksWTime = tasksWTime;
    });
  }

  void groupTasksByHour() {
    tasksByHour.clear();

    for (var task in todayTasksWTime) {
      if (task.startTime == null) continue;
      final hour = int.parse(task.startTime!.split(':')[0]);
      if (!tasksByHour.containsKey(hour)) {
        tasksByHour[hour] = [];
      }
      tasksByHour[hour]!.add(task);
    }
  }
}

class HomePageContent extends StatefulWidget {
  const HomePageContent({
    super.key,
    required this.databaseService,
    required this.weeklySummary,
    required this.streakKey,
    required this.todayTasksWTime,
    required this.todayTasksWOTime,
    required this.tasksByHour,
  });

  final DatabaseService databaseService;
  final List<double> weeklySummary;
  final Key streakKey;
  final List<Task> todayTasksWOTime;
  final List<Task> todayTasksWTime;
  final Map<int, List<Task>> tasksByHour;

  @override
  State<HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  bool showAllHours = false;

  List<int> getVisibleHours() {
    if (showAllHours) {
      return List.generate(24, (index) => index);
    } else {
      return widget.tasksByHour.keys.toList()..sort();
    }
  }

  void switchDisplayType() {
    setState(() {
      showAllHours = !showAllHours;
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleHours = getVisibleHours();

    return ListView(
      children: [
        // ── Bar chart ──────────────────────────────────────────────────────
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 60),
            child: SizedBox(
              height: 200,
              child: MyBarGraph(
                weeklySummary: widget.weeklySummary,
              ),
            ),
          ),
        ),

        // ── Streak + productivity score ────────────────────────────────────
        const SizedBox(height: 16),
        StreakWidget(key: widget.streakKey),

        // ── Task lists ────────────────────────────────────────────────────
        Column(
          children: [
            const SizedBox(height: 25),
            const Text(
              'Tasks for the whole day',
              style: TextStyle(fontSize: 20),
            ),
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.todayTasksWOTime.length,
              padding: const EdgeInsets.all(15),
              shrinkWrap: true,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: 25),
              itemBuilder: (context, index) {
                return Opacity(
                  opacity: 1,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    height: 90,
                    decoration: BoxDecoration(
                      color: widget.todayTasksWOTime[index].deletedAt != null
                          ? const Color.fromARGB(255, 198, 201, 203)
                          : widget.todayTasksWOTime[index].isDone == false
                              ? const Color.fromARGB(255, 243, 141, 141)
                              : const Color.fromARGB(255, 180, 249, 176),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: AutoSizeText(
                            maxLines: 2,
                            minFontSize: 18,
                            textAlign: TextAlign.center,
                            widget.todayTasksWOTime[index].title,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                        Expanded(
                          child: AutoSizeText(
                            maxLines: 1,
                            minFontSize: 16,
                            widget.todayTasksWOTime[index].description == null
                                ? ''
                                : widget.todayTasksWOTime[index].description!,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const Text(
              'Scheduled Tasks',
              style: TextStyle(fontSize: 20),
            ),
            TextButton(
              onPressed: switchDisplayType,
              child: Text(showAllHours ? 'Collapse' : 'Expand'),
            ),
            ListView.builder(
              itemCount: visibleHours.length,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemBuilder: (context, index) {
                final hour = visibleHours[index];
                final tasks = widget.tasksByHour[hour] ?? [];
                double taskHeight = showAllHours ? 100 : 80;

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TIME COLUMN
                      SizedBox(
                        width: 70,
                        child: Column(
                          children: [
                            Text(
                              '${hour.toString().padLeft(2, '0')}:00',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: tasks.isEmpty
                                  ? 100
                                  : tasks.length * 110,
                              width: 2,
                              color: Colors.grey[400],
                            ),
                          ],
                        ),
                      ),

                      // TASKS COLUMN
                      Expanded(
                        child: Column(
                          children: tasks.isEmpty && !showAllHours
                              ? [
                                  Container(
                                    height: taskHeight,
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    child: Divider(
                                      color: Colors.grey[300],
                                      thickness: 1,
                                    ),
                                  ),
                                ]
                              : tasks.map((task) {
                                  return Container(
                                    height: taskHeight,
                                    margin: const EdgeInsets.only(
                                        bottom: 10, right: 10, top: 10),
                                    padding: const EdgeInsets.all(12),
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: task.deletedAt != null
                                          ? Colors.grey[300]
                                          : task.isDone
                                              ? const Color.fromARGB(
                                                  255, 180, 249, 176)
                                              : Colors.red[200],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          task.title,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        if (task.description != null)
                                          Text(
                                            task.description!,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}
