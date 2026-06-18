import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/services/notification_service.dart';
import 'package:flutter_application_1/services/task_dialog_service.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/models/dayOfWeek.dart';
import 'package:flutter_application_1/models/task.dart';
import 'package:flutter_application_1/services/database_service.dart';
import 'package:table_calendar/table_calendar.dart';

class AppState {
  static String? slogan;
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final DatabaseService _databaseService = DatabaseService.instance;
  final NotificationService _notificationService = NotificationService.instance;

  Map<DateTime, double> _productivityScores = {};
  List<Task> _chosenDayTasks = [];

  String? _title;
  String? _description;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  DateTime? _taskDate;

  bool showDateError = false;
  bool showTitleError = false;

  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _dateController = TextEditingController();

  List<DayOfWeek> _allDaysOfWeek = [];
  List<DayOfWeek> _selectedDaysOfWeek = [];
  final TextEditingController _daysOfWeekController = TextEditingController();

  String _slogan = "";

  @override
  void initState() {
    super.initState();
    _loadDays();
    _GetInitTasks(_selectedDate);
    getSlogan();
    _loadMonthScores(_selectedDate);
  }

  Future<void> _loadDays() async {
    final days = await _databaseService.getDayOfWeeks();
    setState(() => _allDaysOfWeek = days);
  }

  Color? _getProductivityColor(DateTime day) {
    final score = _productivityScores[DateTime(day.year, day.month, day.day)];
    if (score == null || score <= 0) return null;
    if (score >= 80) return AppTheme.statusDone;
    if (score >= 50) return Colors.orange;
    return AppTheme.statusUndone;
  }

  Future<void> _loadMonthScores(DateTime month) async {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final Map<DateTime, double> scores = {};
    for (int d = 1; d <= daysInMonth; d++) {
      final day = DateTime(month.year, month.month, d);
      final score = await _databaseService.getDonePercentageForSelectedDay(day);
      scores[day] = score;
    }
    setState(() => _productivityScores = scores);
  }

  Future<void> _GetInitTasks(DateTime chosenDay) async {
    final tasks = await _databaseService.GetTasksForSelectedDay(chosenDay, chosenDay.weekday);
    setState(() => _chosenDayTasks = tasks);
  }

  void _onDaySelected(DateTime day, DateTime focusedDay) {
    setState(() {
      _selectedDate = day;
      _GetInitTasks(_selectedDate);
    });
  }

  String _format24Hour(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickTime({
    required TextEditingController controller,
    required ValueChanged<TimeOfDay> onTimePicked,
  }) async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time != null) {
      setState(() {
        controller.text = _format24Hour(time);
        onTimePicked(time);
      });
    }
  }

  bool _isEndTimeValid() {
    if (_startTime == null && _endTime == null) return true;
    if (_startTime != null && _endTime == null) return false;
    final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
    final endMinutes = _endTime!.hour * 60 + _endTime!.minute;
    return endMinutes > startMinutes;
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      locale: const Locale('en', 'GB'),
      initialDate: _selectedDate,
      firstDate: DateTime.utc(2020, 01, 01),
      lastDate: DateTime.utc(2035, 01, 01),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = picked.toString().split(" ")[0];
        _taskDate = picked;
      });
    }
  }

  void _updateDaysField() {
    setState(() {
      _daysOfWeekController.text = _selectedDaysOfWeek.map((e) => e.title).join(', ');
    });
  }

  void _openDaysPicker() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Repeat on days',
            style: TextStyle(color: AppTheme.text(context), fontWeight: FontWeight.w700)),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: _allDaysOfWeek.map((day) {
              final isSelected = _selectedDaysOfWeek.any((d) => d.id == day.id);
              return CheckboxListTile(
                title: Text(day.title, style: TextStyle(color: AppTheme.text(context))),
                value: isSelected,
                activeColor: AppTheme.text(context),
                checkColor: AppTheme.surface(context),
                onChanged: (checked) {
                  setDialogState(() {
                    if (checked == true) {
                      _selectedDaysOfWeek.add(day);
                    } else {
                      _selectedDaysOfWeek.removeWhere((d) => d.id == day.id);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () { _updateDaysField(); Navigator.pop(context); },
            child: Text('Done', style: TextStyle(color: AppTheme.text(context), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> getSlogan() async {
    if (AppState.slogan == null) AppState.slogan = await getRandomLine();
    setState(() => _slogan = AppState.slogan!);
  }

  Future<String> getRandomLine() async {
    final String fileContent = await rootBundle.loadString('assets/slogans.txt');
    final List<String> lines = fileContent
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final random = Random();
    return lines[random.nextInt(lines.length)];
  }

  // Swipe-to-action dismiss

  Future<bool> _confirmAction(int index) async {
    final task = _chosenDayTasks[index];
    final isArchived = task.deletedAt != null;
    final action = isArchived ? 'delete' : 'archive';
    final actionLabel = isArchived ? 'Delete' : 'Archive';
    final icon = isArchived ? Icons.delete_forever_rounded : Icons.archive_rounded;
    final color = isArchived ? AppTheme.statusUndone : AppTheme.statusArchived;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        icon: icon,
        iconColor: color,
        title: isArchived ? 'Delete task?' : 'Archive task?',
        body: isArchived
            ? 'This will permanently remove the task and all its history.'
            : 'The task will stay in history but won\'t appear going forward.',
        confirmLabel: actionLabel,
        confirmColor: color,
      ),
    );

    if (confirmed == true) {
      if (isArchived) {
        await _databaseService.deleteTaskCompletely(task.occuranceId);
      } else {
        await _databaseService.DeleteTaskOccurance(task.occuranceId, _selectedDate);
      }
      _notificationService.scheduleNotificationForOneTask(task);
      await _GetInitTasks(_selectedDate);
    }

    return false; // always un-dismiss — list reloads if action taken
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createTaskDialog(context),
        child: const Icon(Icons.add, size: 26),
      ),
      body: ListView(
        children: [
          // Slogan
          if (_slogan.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(
                '"$_slogan"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.textSec(context),
                  height: 1.4,
                ),
              ),
            ),

          // Calendar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface(context),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TableCalendar(
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    color: AppTheme.text(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                  leftChevronIcon: Icon(Icons.chevron_left, color: AppTheme.text(context)),
                  rightChevronIcon: Icon(Icons.chevron_right, color: AppTheme.text(context)),
                  headerPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: AppTheme.textSec(context), fontSize: 12, fontWeight: FontWeight.w600),
                  weekendStyle: TextStyle(color: AppTheme.textSec(context), fontSize: 12, fontWeight: FontWeight.w600),
                ),
                calendarStyle: CalendarStyle(
                  defaultTextStyle: TextStyle(color: AppTheme.text(context)),
                  weekendTextStyle: TextStyle(color: AppTheme.text(context)),
                  outsideTextStyle: TextStyle(color: AppTheme.textSec(context)),
                  todayDecoration: BoxDecoration(
                    color: AppTheme.textSec(context).withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: TextStyle(color: AppTheme.text(context), fontWeight: FontWeight.w700),
                  selectedDecoration: BoxDecoration(
                    color: AppTheme.text(context),
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: TextStyle(color: AppTheme.surface(context), fontWeight: FontWeight.w700),
                ),
                availableGestures: AvailableGestures.all,
                selectedDayPredicate: (day) => isSameDay(day, _selectedDate),
                focusedDay: _selectedDate,
                firstDay: DateTime.utc(2020, 01, 01),
                lastDay: DateTime.utc(2035, 01, 01),
                startingDayOfWeek: StartingDayOfWeek.monday,
                onDaySelected: _onDaySelected,
                onPageChanged: (focusedDay) {
                  setState(() => _selectedDate = focusedDay);
                  _loadMonthScores(focusedDay);
                },
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    final color = _getProductivityColor(day);
                    if (color == null) return null;
                    return Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: color.withOpacity(0.25), shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text('${day.day}',
                          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                    );
                  },
                  selectedBuilder: (context, day, focusedDay) {
                    final color = _getProductivityColor(day);
                    return Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.text(context),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text('${day.day}',
                          style: TextStyle(color: AppTheme.surface(context), fontWeight: FontWeight.w700)),
                    );
                  },
                  todayBuilder: (context, day, focusedDay) {
                    final color = _getProductivityColor(day);
                    return Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: color?.withOpacity(0.25) ?? AppTheme.textSec(context).withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.text(context).withOpacity(0.4), width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text('${day.day}',
                          style: TextStyle(color: color ?? AppTheme.text(context), fontWeight: FontWeight.w700)),
                    );
                  },
                ),
              ),
            ),
          ),

          // Task list
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('EEEE, d MMM').format(_selectedDate),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.text(context),
                        ),
                      ),
                      Text(
                        '${_chosenDayTasks.length} task${_chosenDayTasks.length == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSec(context)),
                      ),
                    ],
                  ),
                ),

                if (_chosenDayTasks.isEmpty)
                  _EmptyState(color: AppTheme.textSec(context))
                else
                  ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: _chosenDayTasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final task = _chosenDayTasks[index];
                      final isArchived = task.deletedAt != null;

                      return Dismissible(
                        key: ValueKey(task.occuranceId),
                        direction: DismissDirection.startToEnd,
                        confirmDismiss: (_) => _confirmAction(index),
                        background: _SwipeBackground(isArchived: isArchived),
                        child: _TaskCard(
                          task: task,
                          onTap: () => TaskDialog.show(
                            context: context,
                            task: task,
                            selectedDate: _selectedDate,
                            onChanged: (isChanged) async {
                              if (isChanged) {
                                await _databaseService.SaveCompletionState(
                                    task.occuranceId, _selectedDate);
                                _notificationService.scheduleNotificationForOneTask(task);
                                setState(() {});
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Create task dialog

  Future<void> _createTaskDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) => AlertDialog(
          backgroundColor: AppTheme.surface(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New task',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.text(context),
                    letterSpacing: -0.3,
                  )),
              const SizedBox(height: 4),
              Text('Fill in at least a title and a date or day.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSec(context))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                _FormField(
                  hintText: 'Title *',
                  hasError: showTitleError,
                  errorText: 'Title is required',
                  onChanged: (v) => _title = v,
                ),
                const SizedBox(height: 10),
                _FormField(
                  hintText: 'Description (optional)',
                  onChanged: (v) => _description = v,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _FormField(
                        controller: _startTimeController,
                        hintText: 'Start time',
                        readOnly: true,
                        suffixIcon: Icons.access_time_rounded,
                        onTap: () => _pickTime(
                          controller: _startTimeController,
                          onTimePicked: (t) => _startTime = t,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _FormField(
                        controller: _endTimeController,
                        hintText: 'End time',
                        readOnly: true,
                        suffixIcon: Icons.access_time_rounded,
                        onTap: () => _pickTime(
                          controller: _endTimeController,
                          onTimePicked: (t) => _endTime = t,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _FormField(
                  controller: _dateController,
                  hintText: 'Specific date',
                  readOnly: true,
                  suffixIcon: Icons.calendar_today_rounded,
                  hasError: showDateError,
                  onTap: _selectDate,
                ),
                const SizedBox(height: 10),
                _FormField(
                  controller: _daysOfWeekController,
                  hintText: 'Repeat on days of week',
                  readOnly: true,
                  suffixIcon: Icons.repeat_rounded,
                  hasError: showDateError,
                  onTap: _openDaysPicker,
                ),
                if (showDateError)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Select a date or at least one day of week.',
                        style: TextStyle(fontSize: 12, color: AppTheme.statusUndone)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: AppTheme.textSec(context))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.text(context),
                foregroundColor: AppTheme.surface(context),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                elevation: 0,
              ),
              onPressed: () async {
                if (_title == null || _title!.isEmpty) {
                  dialogSetState(() => showTitleError = true);
                  return;
                }
                if (!_isEndTimeValid()) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('End time must be after start time')));
                  return;
                }
                if (_taskDate == null && _selectedDaysOfWeek.isEmpty) {
                  dialogSetState(() => showDateError = true);
                  return;
                }
                if (_taskDate != null && _taskDate!.isBefore(
                    DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('You cannot create a task in the past')));
                  return;
                }

                final List<int> selectedIds = _selectedDaysOfWeek.map((e) => e.id).toList();
                int taskId = await _databaseService.createTask(
                    _title!, _description, _startTime, _endTime, _taskDate, selectedIds);

                if (_taskDate == DateTime.now() || selectedIds.contains(DateTime.now().weekday)) {
                  int occuranceId = await _databaseService.getOccuranceId(taskId, DateTime.now());
                  _notificationService.scheduleNotificationForOneTask(
                      Task(occuranceId: occuranceId, title: _title!, isDone: false, startTime: _startTime.toString()));
                }

                _GetInitTasks(_selectedDate);
                Navigator.of(context).pop();
              },
              child: const Text('Create', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    ).then((_) {
      showTitleError = false;
      showDateError = false;
      _startTime = null;
      _endTime = null;
      _taskDate = null;
      _description = null;
      _title = null;
      _selectedDaysOfWeek = [];
      _dateController.text = "";
      _daysOfWeekController.text = "";
      _startTimeController.text = "";
      _endTimeController.text = "";
    });
  }

  Future<void> deleteTaskOccurance(int occuranceId) async {
    await _databaseService.DeleteTaskOccurance(occuranceId, _selectedDate);
  }

  Future<void> deleteTaskCompletely(int occuranceId) async {
    await _databaseService.deleteTaskCompletely(occuranceId);
  }
}

// Task card

class _TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;

  const _TaskCard({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isArchived = task.deletedAt != null;
    final accent = AppTheme.taskAccent(isDone: task.isDone, isArchived: isArchived);
    final bg = AppTheme.taskBg(context, isDone: task.isDone, isArchived: isArchived);
    final textColor = AppTheme.text(context);
    final secColor = AppTheme.textSec(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: accent, width: 4)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isArchived ? secColor : textColor,
                      decoration: isArchived ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (task.description != null && task.description!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      task.description!,
                      style: TextStyle(fontSize: 13, color: secColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (task.startTime != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 13, color: secColor),
                        const SizedBox(width: 4),
                        Text(
                          task.endTime != null
                              ? '${task.startTime!} – ${task.endTime!}'
                              : task.startTime!,
                          style: TextStyle(fontSize: 12, color: secColor),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Status dot
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }
}

// Swipe background

class _SwipeBackground extends StatelessWidget {
  final bool isArchived;
  const _SwipeBackground({required this.isArchived});

  @override
  Widget build(BuildContext context) {
    final color = isArchived ? AppTheme.statusUndone : AppTheme.statusArchived;
    final icon = isArchived ? Icons.delete_forever_rounded : Icons.archive_rounded;
    final label = isArchived ? 'Delete' : 'Archive';

    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 20),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
}

// Empty state

class _EmptyState extends StatelessWidget {
  final Color color;
  const _EmptyState({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.event_available_rounded, size: 48, color: color),
          const SizedBox(height: 12),
          Text('No tasks for this day',
              style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('Tap + to add one', style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }
}

// Confirm dialog

class _ConfirmDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final String confirmLabel;
  final Color confirmColor;

  const _ConfirmDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.confirmColor,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.text(context))),
          const SizedBox(height: 8),
          Text(body,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.textSec(context), height: 1.4)),
          const SizedBox(height: 24),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel', style: TextStyle(color: AppTheme.textSec(context))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// Form field helper

class _FormField extends StatelessWidget {
  final String hintText;
  final bool readOnly;
  final bool hasError;
  final String? errorText;
  final IconData? suffixIcon;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;

  const _FormField({
    required this.hintText,
    this.readOnly = false,
    this.hasError = false,
    this.errorText,
    this.suffixIcon,
    this.controller,
    this.onChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onChanged: onChanged,
      onTap: onTap,
      style: TextStyle(color: AppTheme.text(context), fontSize: 15),
      decoration: InputDecoration(
        hintText: hintText,
        errorText: hasError ? errorText : null,
        suffixIcon: suffixIcon != null
            ? Icon(suffixIcon, size: 18, color: AppTheme.textSec(context))
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: hasError ? AppTheme.statusUndone : AppTheme.divider(context),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.text(context), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.statusUndone),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.statusUndone, width: 1.5),
        ),
      ),
    );
  }
}
