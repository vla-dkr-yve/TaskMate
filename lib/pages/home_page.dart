import 'package:flutter/material.dart';
import 'package:flutter_application_1/bar%20graph/bar_graph.dart';
import 'package:flutter_application_1/models/task.dart';
import 'package:flutter_application_1/pages/calendar_page.dart';
import 'package:flutter_application_1/pages/settings_page.dart';
import 'package:flutter_application_1/services/database_service.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/streak_widget.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseService _databaseService = DatabaseService.instance;

  int currentPage = 0;
  Key _streakKey = UniqueKey();

  List<double> weeklySummary = [0, 0, 0, 0, 0, 0, 0];
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
        weeklySummary: weeklySummary,
        streakKey: _streakKey,
        todayTasksWOTime: todayTasksWOTime,
        todayTasksWTime: todayTasksWTime,
        tasksByHour: tasksByHour,
      ),
      const CalendarPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('TaskMate',
                style: TextStyle(
                  color: AppTheme.text(context),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                )),
          ],
        ),
        backgroundColor: AppTheme.bg(context),
      ),
      backgroundColor: AppTheme.bg(context),
      body: pages[currentPage],
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(top: BorderSide(color: AppTheme.divider(context), width: 0.5)),
      ),
      child: BottomNavigationBar(
        currentIndex: currentPage,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppTheme.text(context),
        unselectedItemColor: AppTheme.textSec(context),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        onTap: (value) async {
          setState(() => currentPage = value);
          if (value == 0) {
            await getPercentage();
            await getTasks();
            setState(() => _streakKey = UniqueKey());
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'Calendar'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }

  Future<void> getPercentage() async {
    final one = await _databaseService.getDonePercentage(DateTime.now());
    setState(() => weeklySummary = one);
  }

  Future<void> getTasks() async {
    final tasks = await _databaseService.GetTasksForSelectedDay(
        DateTime.now(), DateTime.now().weekday);
    setState(() => todayTasks = tasks);
    await getTasksTime();
    groupTasksByHour();
  }

  Future<void> getTasksTime() async {
    final List<Task> tasksWTime = [];
    final List<Task> tasksWOTime = [];
    for (var e in todayTasks) {
      if (e.startTime == null) tasksWOTime.add(e); else tasksWTime.add(e);
    }
    setState(() { todayTasksWOTime = tasksWOTime; todayTasksWTime = tasksWTime; });
  }

  void groupTasksByHour() {
    tasksByHour.clear();
    for (var task in todayTasksWTime) {
      if (task.startTime == null) continue;
      final hour = int.parse(task.startTime!.split(':')[0]);
      tasksByHour.putIfAbsent(hour, () => []).add(task);
    }
  }
}

// Home content

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
    if (showAllHours) return List.generate(24, (i) => i);
    return widget.tasksByHour.keys.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final visibleHours = getVisibleHours();
    final today = DateFormat('EEEE, d MMMM').format(DateTime.now());

    return ListView(
      children: [
        // Header date
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Text(
            today,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSec(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        // Bar chart
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            height: 200,
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(
                      Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: MyBarGraph(weeklySummary: widget.weeklySummary),
          ),
        ),

        // Streak
        const SizedBox(height: 12),
        StreakWidget(key: widget.streakKey),

        // All-day tasks
        if (widget.todayTasksWOTime.isNotEmpty) ...[
          _SectionHeader(label: 'All day', context: context),
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.todayTasksWOTime.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shrinkWrap: true,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final task = widget.todayTasksWOTime[index];
              final isArchived = task.deletedAt != null;
              final accent = AppTheme.taskAccent(isDone: task.isDone, isArchived: isArchived);
              final bg = AppTheme.taskBg(context, isDone: task.isDone, isArchived: isArchived);

              return Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border(left: BorderSide(color: accent, width: 4)),
                ),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isArchived ? AppTheme.textSec(context) : AppTheme.text(context),
                          decoration: isArchived ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    if (task.description != null && task.description!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(task.description!,
                          style: TextStyle(fontSize: 13, color: AppTheme.textSec(context)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              );
            },
          ),
        ],

        // Scheduled tasks
        _SectionHeader(
          label: 'Scheduled',
          context: context,
          trailing: TextButton(
            onPressed: () => setState(() => showAllHours = !showAllHours),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
            ),
            child: Text(
              showAllHours ? 'Collapse' : 'Expand',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSec(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),

        if (widget.todayTasksWTime.isEmpty && !showAllHours)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Text('No scheduled tasks today.',
                style: TextStyle(fontSize: 14, color: AppTheme.textSec(context))),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: ListView.builder(
              itemCount: visibleHours.length,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemBuilder: (context, index) {
                final hour = visibleHours[index];
                final tasks = widget.tasksByHour[hour] ?? [];

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time + line
                      SizedBox(
                        width: 56,
                        child: Column(
                          children: [
                            Text('${hour.toString().padLeft(2, '0')}:00',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSec(context),
                                )),
                            const SizedBox(height: 6),
                            Expanded(
                              child: Center(
                                child: Container(
                                  width: 1,
                                  color: AppTheme.divider(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Tasks
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: tasks.isEmpty
                              ? SizedBox(height: showAllHours ? 36 : 0)
                              : Column(
                                  children: tasks.map((task) {
                                    final isArchived = task.deletedAt != null;
                                    final accent = AppTheme.taskAccent(isDone: task.isDone, isArchived: isArchived);
                                    final bg = AppTheme.taskBg(context, isDone: task.isDone, isArchived: isArchived);
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: bg,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border(left: BorderSide(color: accent, width: 3)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(task.title,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: isArchived
                                                    ? AppTheme.textSec(context)
                                                    : AppTheme.text(context),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                          if (task.endTime != null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              '${task.startTime} – ${task.endTime}',
                                              style: TextStyle(fontSize: 11, color: AppTheme.textSec(context)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final BuildContext context;
  final Widget? trailing;

  const _SectionHeader({required this.label, required this.context, this.trailing});

  @override
  Widget build(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSec(context),
                letterSpacing: 0.5,
              )),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
