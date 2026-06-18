import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/execution.dart';
import 'package:flutter_application_1/models/sub_task.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/models/dayOfWeek.dart';
import 'package:flutter_application_1/models/task.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite/sqlite_api.dart';

class DatabaseService {

  static Database? _db;
  static final DatabaseService instance = DatabaseService._constructor();

  final String _tasksTableName = "tasks";
  final String _tasksIdColumnName = "id";
  final String _tasksTitleColumnName = "title";
  final String _tasksDescriptionColumnName = "description";
  final String _tasksCreatedAtDateColumnName = "createdAtDate";

  final String _daysOfWeekTableName = "daysOfWeek";
  final String _daysOfWeekIdColumnName = "id";
  final String _daysOfWeekTitleColumnName = "title";

  final String _tasksOccuranceTableName = "tasksOccurance";
  final String _tasksOccuranceIdColumnName = "id";
  final String _tasksOccuranceTaskIdColumnName = "taskId";
  final String _tasksOccuranceStartTimeColumnName = "startTime";
  final String _tasksOccuranceEndTimeColumnName = "endTime";
  final String _tasksOccuranceTaskDateColumnName = "taskDate";
  final String _tasksOccuranceDayOfWeekIdColumnName = "dayOfWeekId";
  final String _tasksOccuranceDeletedAtColumnName = "deletedAt";

  final String _tasksExecutionTableName = "tasksExecution";
  final String _tasksExecutionIdColumnName = "id";
  final String _tasksExecutionTaskOccuranceIdColumnName = "taskOccuranceId";
  final String _tasksExecutionDateColumnName = "executionDate";

  // Sub-tasks
  final String _subTasksTableName = "subTasks";
  final String _subTasksIdColumnName = "id";
  final String _subTasksTaskIdColumnName = "taskId";
  final String _subTasksTitleColumnName = "title";

  // Sub-task executions
  final String _subTaskExecutionTableName = "subTaskExecution";
  final String _subTaskExecutionIdColumnName = "id";
  final String _subTaskExecutionSubTaskIdColumnName = "subTaskId";
  final String _subTaskExecutionOccuranceIdColumnName = "occuranceId";
  final String _subTaskExecutionDateColumnName = "executionDate";

  DatabaseService._constructor();

  Future<Database> get database async {
    if(_db != null) return _db!;
    _db = await getDatabase();
    return _db!;
  }

  Future<Database> getDatabase() async {

    final databaseDirPath = await getDatabasesPath();
    final databasePath = join(databaseDirPath, "master_db.db");

    final database = await openDatabase(
      databasePath,
      version: 3,
      onCreate: (db, version) {
        db.execute('''
          CREATE TABLE $_tasksTableName (
            $_tasksIdColumnName INTEGER PRIMARY KEY,
            $_tasksTitleColumnName TEXT(50) NOT NULL,
            $_tasksDescriptionColumnName TEXT(300),
            $_tasksCreatedAtDateColumnName String NOT NULL 
          )
        ''');

        db.execute('''
          CREATE TABLE $_daysOfWeekTableName (
            $_daysOfWeekIdColumnName INTEGER PRIMARY KEY,
            $_daysOfWeekTitleColumnName TEXT(50) NOT NULL
          )
        ''');

        db.execute('''
          INSERT INTO $_daysOfWeekTableName ($_daysOfWeekTitleColumnName)
          VALUES 
            ('Monday'),
            ('Tuesday'),
            ('Wednesday'),
            ('Thursday'),
            ('Friday'),
            ('Saturday'),
            ('Sunday')
        ''');

        db.execute('''
          CREATE TABLE $_tasksOccuranceTableName (
            $_tasksOccuranceIdColumnName INTEGER PRIMARY KEY,
            $_tasksOccuranceTaskIdColumnName INTEGER,
            $_tasksOccuranceStartTimeColumnName TEXT,
            $_tasksOccuranceEndTimeColumnName TEXT,
            $_tasksOccuranceTaskDateColumnName TEXT,
            $_tasksOccuranceDayOfWeekIdColumnName INTEGER,
            $_tasksOccuranceDeletedAtColumnName String DEFAULT NULL,
            FOREIGN KEY ($_tasksOccuranceTaskIdColumnName)
              REFERENCES $_tasksTableName($_tasksIdColumnName)
          )
        ''');

        db.execute('''
          CREATE TABLE $_tasksExecutionTableName (
            $_tasksExecutionIdColumnName INTEGER PRIMARY KEY,
            $_tasksExecutionTaskOccuranceIdColumnName INTEGER,
            $_tasksExecutionDateColumnName TEXT NOT NULL,
            FOREIGN KEY ($_tasksExecutionTaskOccuranceIdColumnName)
              REFERENCES $_tasksOccuranceTableName($_tasksOccuranceIdColumnName)
          )
        ''');

        db.execute('''
          CREATE TABLE $_subTasksTableName (
            $_subTasksIdColumnName INTEGER PRIMARY KEY,
            $_subTasksTaskIdColumnName INTEGER NOT NULL,
            $_subTasksTitleColumnName TEXT(100) NOT NULL,
            FOREIGN KEY ($_subTasksTaskIdColumnName)
              REFERENCES $_tasksTableName($_tasksIdColumnName)
          )
        ''');

        db.execute('''
          CREATE TABLE $_subTaskExecutionTableName (
            $_subTaskExecutionIdColumnName INTEGER PRIMARY KEY,
            $_subTaskExecutionSubTaskIdColumnName INTEGER NOT NULL,
            $_subTaskExecutionOccuranceIdColumnName INTEGER NOT NULL,
            $_subTaskExecutionDateColumnName TEXT NOT NULL,
            FOREIGN KEY ($_subTaskExecutionSubTaskIdColumnName)
              REFERENCES $_subTasksTableName($_subTasksIdColumnName),
            FOREIGN KEY ($_subTaskExecutionOccuranceIdColumnName)
              REFERENCES $_tasksOccuranceTableName($_tasksOccuranceIdColumnName)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $_subTasksTableName (
              $_subTasksIdColumnName INTEGER PRIMARY KEY,
              $_subTasksTaskIdColumnName INTEGER NOT NULL,
              $_subTasksTitleColumnName TEXT(100) NOT NULL,
              FOREIGN KEY ($_subTasksTaskIdColumnName)
                REFERENCES $_tasksTableName($_tasksIdColumnName)
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS $_subTaskExecutionTableName (
              $_subTaskExecutionIdColumnName INTEGER PRIMARY KEY,
              $_subTaskExecutionSubTaskIdColumnName INTEGER NOT NULL,
              $_subTaskExecutionOccuranceIdColumnName INTEGER NOT NULL,
              $_subTaskExecutionDateColumnName TEXT NOT NULL,
              FOREIGN KEY ($_subTaskExecutionSubTaskIdColumnName)
                REFERENCES $_subTasksTableName($_subTasksIdColumnName),
              FOREIGN KEY ($_subTaskExecutionOccuranceIdColumnName)
                REFERENCES $_tasksOccuranceTableName($_tasksOccuranceIdColumnName)
            )
          ''');
        }
      },
    );
    return database;
  }

  Future<int> createTask(
    String title, String? description,
    TimeOfDay? startTime, TimeOfDay? endTime, DateTime? TaskDate, List<int>? DayOfWeekIds) async {
    final db = await database;
    int taskId = await addTask(db, title, description);
    await addTaskOccurence(db, taskId, startTime, endTime, TaskDate, DayOfWeekIds);
    return taskId;
  }

  Future<int> addTask(Database db, String title, String? description) async {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    int taskId = await db.insert(
      _tasksTableName,
      {
        _tasksTitleColumnName: title,
        _tasksDescriptionColumnName: description,
        _tasksCreatedAtDateColumnName: today
      }
    );
    return taskId;
  }

  Future<void> addTaskOccurence(
    Database db, int taskId, TimeOfDay? startTime,
    TimeOfDay? endTime, DateTime? TaskDate, List<int>? DayOfWeekIds) async {
    
    String? startTimeRes;
    String? endTimeRes;

    if (startTime != null) {
      startTimeRes =
        '${startTime.hour.toString().padLeft(2, '0')}:'
        '${startTime.minute.toString().padLeft(2, '0')}';
    }

    if (endTime != null) {
      endTimeRes =
        '${endTime.hour.toString().padLeft(2, '0')}:'
        '${endTime.minute.toString().padLeft(2, '0')}';
    }

    if (TaskDate != null) {
      String singleTaskDate = DateFormat('yyyy-MM-dd').format(TaskDate);
      insertTaskOccurenceWithDate(db, taskId, startTimeRes, endTimeRes, singleTaskDate);
    }

    if (DayOfWeekIds != null) {
      while (DayOfWeekIds.isNotEmpty == true) {
        insertTaskOccurenceWithWeekId(db, taskId, startTimeRes, endTimeRes, DayOfWeekIds.last);
        DayOfWeekIds.removeLast();
      }
    }
  }

  void insertTaskOccurenceWithDate(Database db, int taskId, String? startTimeRes,
    String? endTimeRes, String singleTaskDate) async {
    await db.insert(
      _tasksOccuranceTableName,
      {
        _tasksOccuranceTaskIdColumnName: taskId,
        _tasksOccuranceStartTimeColumnName: startTimeRes,
        _tasksOccuranceEndTimeColumnName: endTimeRes,
        _tasksOccuranceTaskDateColumnName: singleTaskDate
      }
    );
  }

  Future<List<DayOfWeek>> getDayOfWeeks() async{
    final db = await database;
    final data = await db.query(_daysOfWeekTableName);

    List<DayOfWeek> dayOfWeek = data.map((e) => DayOfWeek(id: e["id"] as int, title: e["title"] as String)).toList();
    return dayOfWeek;
  }

  void insertTaskOccurenceWithWeekId(Database db, int taskId, String? startTimeRes,
    String? endTimeRes, int weekId) async {
    weekId += 1;
    if (weekId == 8) weekId = 1;
    await db.insert(
      _tasksOccuranceTableName,
      {
        _tasksOccuranceTaskIdColumnName: taskId,
        _tasksOccuranceStartTimeColumnName: startTimeRes,
        _tasksOccuranceEndTimeColumnName: endTimeRes,
        _tasksOccuranceDayOfWeekIdColumnName: weekId
      }
    );
  }

  Future<int> getOccuranceId(int taskId, [DateTime? TaskDate, int? DayOfWeekId]) async {
    final db = await database;

    final occuranceIdData;
    if (TaskDate != null) {
      occuranceIdData = await db.rawQuery('''
        Select $_tasksOccuranceIdColumnName
        FROM $_tasksOccuranceTableName
        WHERE $_tasksOccuranceTaskIdColumnName = ? AND $_tasksOccuranceTaskDateColumnName = ?
      ''', [taskId, DateFormat('yyyy-MM-dd').format(TaskDate)]);
    } else {
      occuranceIdData = await db.rawQuery('''
        Select $_tasksOccuranceIdColumnName
        FROM $_tasksOccuranceTableName
        WHERE $_tasksOccuranceTaskIdColumnName = ? AND $_tasksOccuranceDayOfWeekIdColumnName = ?
      ''', [taskId, DayOfWeekId]);
    }

    return occuranceIdData.first[_tasksOccuranceIdColumnName] as int;
  }

  Future<List<Task>> GetTasksForSelectedDay(DateTime chosenDay, int weekDayId) async {
    final db = await database;

    weekDayId += 1;
    if (weekDayId == 8) weekDayId = 1;

    final formattedDate = DateFormat('yyyy-MM-dd').format(chosenDay);

    final data = await db.rawQuery('''
      SELECT 
        o.$_tasksOccuranceIdColumnName,
        t.$_tasksTitleColumnName, t.$_tasksDescriptionColumnName, 
        o.$_tasksOccuranceStartTimeColumnName, o.$_tasksOccuranceEndTimeColumnName, o.$_tasksOccuranceDeletedAtColumnName,
        e.$_tasksExecutionDateColumnName
      FROM $_tasksOccuranceTableName o
      LEFT JOIN $_tasksTableName t
        ON o.$_tasksOccuranceTaskIdColumnName = t.$_tasksIdColumnName
      LEFT JOIN $_tasksExecutionTableName e
        ON e.$_tasksExecutionTaskOccuranceIdColumnName = o.$_tasksOccuranceIdColumnName AND e.$_tasksExecutionDateColumnName = ?
      WHERE (((o.$_tasksOccuranceTaskDateColumnName = ? OR o.$_tasksOccuranceDayOfWeekIdColumnName = ? ) 
        AND (o.$_tasksOccuranceDeletedAtColumnName >= ? OR o.$_tasksOccuranceDeletedAtColumnName IS NULL)) 
        AND t.$_tasksCreatedAtDateColumnName <= ?)
      ORDER BY $_tasksOccuranceStartTimeColumnName
    ''', [formattedDate, formattedDate, weekDayId, formattedDate, formattedDate]);

    List<Task> tasksForDay = data.map((e) => Task(
      occuranceId: e["id"] as int,
      title: e["title"] as String,
      description: e["description"] as String?,
      deletedAt: e["deletedAt"] as String?,
      startTime: e["startTime"] as String?,
      endTime: e["endTime"] as String?,
      doneAt: (e["$_tasksExecutionDateColumnName"] != null ? e["$_tasksExecutionDateColumnName"] : null) as String?,
      isDone: e["executionDate"] == null ? false : true)).toList();
    return tasksForDay;
  }

  Future<List<Task>> GetTasksWithTimeForSelectedDay(DateTime chosenDay, int weekDayId) async {
    final db = await database;

    weekDayId += 1;
    if (weekDayId == 8) weekDayId = 1;

    final formattedDate = DateFormat('yyyy-MM-dd').format(chosenDay);

    final data = await db.rawQuery('''
      SELECT 
        o.$_tasksOccuranceIdColumnName,
        t.$_tasksTitleColumnName, t.$_tasksDescriptionColumnName, 
        o.$_tasksOccuranceStartTimeColumnName, o.$_tasksOccuranceEndTimeColumnName, o.$_tasksOccuranceDeletedAtColumnName,
        e.$_tasksExecutionDateColumnName
      FROM $_tasksOccuranceTableName o
      LEFT JOIN $_tasksTableName t
        ON o.$_tasksOccuranceTaskIdColumnName = t.$_tasksIdColumnName
      LEFT JOIN $_tasksExecutionTableName e
        ON e.$_tasksExecutionTaskOccuranceIdColumnName = o.$_tasksOccuranceIdColumnName AND e.$_tasksExecutionDateColumnName = ?
      WHERE (((o.$_tasksOccuranceTaskDateColumnName = ? OR o.$_tasksOccuranceDayOfWeekIdColumnName = ? ) 
        AND (o.$_tasksOccuranceDeletedAtColumnName >= ? OR o.$_tasksOccuranceDeletedAtColumnName IS NULL)) 
        AND t.$_tasksCreatedAtDateColumnName <= ?) 
        AND o.$_tasksOccuranceStartTimeColumnName IS NOT NULL
      ORDER BY $_tasksOccuranceStartTimeColumnName
    ''', [formattedDate, formattedDate, weekDayId, formattedDate, formattedDate]);

    List<Task> tasksForDay = data.map((e) => Task(
      occuranceId: e["id"] as int,
      title: e["title"] as String,
      description: e["description"] as String?,
      deletedAt: e["deletedAt"] as String?,
      startTime: e["startTime"] as String?,
      endTime: e["endTime"] as String?,
      doneAt: (e["$_tasksExecutionDateColumnName"] != null ? e["$_tasksExecutionDateColumnName"] : null) as String?,
      isDone: e["executionDate"] == null ? false : true)).toList();
    return tasksForDay;
  }

  Future<List<Task>> GetTasksForHour(int hour, DateTime day) async {
    final db = await database;

    var dayOfWeek = day.weekday + 1;
    if (dayOfWeek == 8) dayOfWeek = 1;

    final formattedDate = DateFormat('yyyy-MM-dd').format(day);
    final hourStr = hour.toString().padLeft(2, '0');

    final data = await db.rawQuery('''
      SELECT
        o.$_tasksOccuranceIdColumnName,
        t.$_tasksTitleColumnName, t.$_tasksDescriptionColumnName,
        o.$_tasksOccuranceStartTimeColumnName, o.$_tasksOccuranceEndTimeColumnName,
        o.$_tasksOccuranceDeletedAtColumnName,
        e.$_tasksExecutionDateColumnName
      FROM $_tasksOccuranceTableName o
      LEFT JOIN $_tasksTableName t
        ON o.$_tasksOccuranceTaskIdColumnName = t.$_tasksIdColumnName
      LEFT JOIN $_tasksExecutionTableName e
        ON e.$_tasksExecutionTaskOccuranceIdColumnName = o.$_tasksOccuranceIdColumnName
        AND e.$_tasksExecutionDateColumnName = ?
      WHERE (
          (o.$_tasksOccuranceTaskDateColumnName = ? OR o.$_tasksOccuranceDayOfWeekIdColumnName = ?)
          AND (o.$_tasksOccuranceDeletedAtColumnName >= ? OR o.$_tasksOccuranceDeletedAtColumnName IS NULL)
        )
        AND t.$_tasksCreatedAtDateColumnName <= ?
        AND o.$_tasksOccuranceStartTimeColumnName IS NOT NULL
        AND substr(o.$_tasksOccuranceStartTimeColumnName, 1, 2) = ?
      ORDER BY o.$_tasksOccuranceStartTimeColumnName
    ''', [formattedDate, formattedDate, dayOfWeek, formattedDate, formattedDate, hourStr]);

    return data.map((e) => Task(
      occuranceId: e["id"] as int,
      title: e["title"] as String,
      description: e["description"] as String?,
      deletedAt: e["deletedAt"] as String?,
      startTime: e["startTime"] as String?,
      endTime: e["endTime"] as String?,
      doneAt: e["$_tasksExecutionDateColumnName"] as String?,
      isDone: e["executionDate"] != null,
    )).toList();
  }

  Future<int> SaveCompletionState(int id, DateTime day) async {
    final db = await database;
    final formattedDate = DateFormat('yyyy-MM-dd').format(day);

    final occurances = await db.rawQuery('''
      SELECT * 
      FROM $_tasksExecutionTableName
      WHERE $_tasksExecutionTaskOccuranceIdColumnName = ? AND $_tasksExecutionDateColumnName = ?
    ''', [id, formattedDate]);

    List<Execution> occurancesForm = occurances.map((e) => Execution(
      id: e["id"] as int,
      occuranceId: e["taskOccuranceId"] as int,
      executionDate: e["executionDate"] as String)).toList();

    if (occurancesForm.isEmpty) {
      CreateNewExecution(id, formattedDate, db);
      return 1;
    } else {
      DeleteExecutionInstance(occurancesForm[0].id, db);
      return 0;
    }
  }

  Future<void> CreateNewExecution(int id, String day, Database db) async {
    await db.rawInsert('''
      INSERT INTO 
      $_tasksExecutionTableName($_tasksExecutionTaskOccuranceIdColumnName, $_tasksExecutionDateColumnName) 
      VALUES (?, ?)
    ''', [id, day]);
  }

  Future<void> DeleteExecutionInstance(int instanceId, Database db) async {
    await db.rawDelete('''
      DELETE FROM $_tasksExecutionTableName WHERE $_tasksExecutionIdColumnName = ?
    ''', [instanceId]);
  }

  Future<void> DeleteTaskOccurance(int occuranceId, DateTime day) async {
    final db = await database;
    final formattedDate = DateFormat('yyyy-MM-dd').format(day);

    await db.rawUpdate('''
      UPDATE $_tasksOccuranceTableName SET $_tasksOccuranceDeletedAtColumnName = ? WHERE $_tasksOccuranceIdColumnName = ?
    ''', [formattedDate, occuranceId]);
  }

  Future<void> deleteTaskCompletely(int occuranceId) async {
    final db = await database;

    await db.rawDelete('''
      DELETE FROM $_tasksOccuranceTableName
      WHERE $_tasksOccuranceIdColumnName = ?
    ''', [occuranceId]);
  }

  Future<List<double>> getDonePercentage(DateTime chosenDay) async {
    List<double> res = List.filled(7, 0);
    final startOfWeek = chosenDay.subtract(Duration(days: chosenDay.weekday - 1));

    for (int i = 0; i < 7; i++) {
      final day = startOfWeek.add(Duration(days: i));
      res[i] = await getDonePercentageForSelectedDay(day);
    }

    return res;
  }

  Future<double> getDonePercentageForSelectedDay(chosenDay) async {
    final db = await database;
    double res = 0;
    final formattedDate = DateFormat('yyyy-MM-dd').format(chosenDay);

    var dayOfWeek = chosenDay.weekday + 1;
    if (dayOfWeek == 8) dayOfWeek = 1;

    final done = await db.rawQuery('''
      SELECT COUNT(e.$_tasksExecutionTaskOccuranceIdColumnName) AS total
      FROM $_tasksOccuranceTableName o
      LEFT JOIN $_tasksExecutionTableName e
        ON o.$_tasksOccuranceIdColumnName = e.$_tasksExecutionTaskOccuranceIdColumnName
        AND e.$_tasksExecutionDateColumnName = ?
      WHERE o.$_tasksOccuranceTaskDateColumnName = ? 
        OR o.$_tasksOccuranceDayOfWeekIdColumnName = ?
    ''', [formattedDate, formattedDate, dayOfWeek]);

    int doneForm = done.first["total"] as int;

    final all = await db.rawQuery('''
      SELECT COUNT(o.$_tasksOccuranceIdColumnName) AS total
      FROM $_tasksOccuranceTableName o
      WHERE o.$_tasksOccuranceTaskDateColumnName = ? OR o.$_tasksOccuranceDayOfWeekIdColumnName = ?
    ''', [formattedDate, dayOfWeek]);

    int allForm = all.first["total"] as int;

    if (allForm != 0) {
      res = ((doneForm / allForm) * 100).roundToDouble();
    }

    return res;
  }

  // Sub-task methods

  // Looks up the parent taskId for a given occurance.
  // Needed by the dialog which only receives occuranceId.
  Future<int> getTaskIdFromOccuranceId(int occuranceId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT $_tasksOccuranceTaskIdColumnName
      FROM $_tasksOccuranceTableName
      WHERE $_tasksOccuranceIdColumnName = ?
    ''', [occuranceId]);
    return result.first[_tasksOccuranceTaskIdColumnName] as int;
  }

  // Returns all sub-tasks for a task, with isDone resolved for the given
  // occurance + date (so recurring tasks track sub-task completion per day).
  Future<List<SubTask>> getSubTasksForOccurance(int occuranceId, DateTime date) async {
    final db = await database;
    final taskId = await getTaskIdFromOccuranceId(occuranceId);
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);

    final data = await db.rawQuery('''
      SELECT 
        s.$_subTasksIdColumnName,
        s.$_subTasksTaskIdColumnName,
        s.$_subTasksTitleColumnName,
        e.$_subTaskExecutionIdColumnName AS execId
      FROM $_subTasksTableName s
      LEFT JOIN $_subTaskExecutionTableName e
        ON e.$_subTaskExecutionSubTaskIdColumnName = s.$_subTasksIdColumnName
        AND e.$_subTaskExecutionOccuranceIdColumnName = ?
        AND e.$_subTaskExecutionDateColumnName = ?
      WHERE s.$_subTasksTaskIdColumnName = ?
      ORDER BY s.$_subTasksIdColumnName
    ''', [occuranceId, formattedDate, taskId]);

    return data.map((e) => SubTask(
      id: e[_subTasksIdColumnName] as int,
      taskId: e[_subTasksTaskIdColumnName] as int,
      title: e[_subTasksTitleColumnName] as String,
      isDone: e["execId"] != null,
    )).toList();
  }

  // Toggles a sub-task's completion for a specific occurance + date.
  // Returns 1 if now done, 0 if now undone (mirrors SaveCompletionState).
  Future<int> toggleSubTaskExecution(int subTaskId, int occuranceId, DateTime date) async {
    final db = await database;
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);

    final existing = await db.rawQuery('''
      SELECT $_subTaskExecutionIdColumnName
      FROM $_subTaskExecutionTableName
      WHERE $_subTaskExecutionSubTaskIdColumnName = ?
        AND $_subTaskExecutionOccuranceIdColumnName = ?
        AND $_subTaskExecutionDateColumnName = ?
    ''', [subTaskId, occuranceId, formattedDate]);

    if (existing.isEmpty) {
      await db.rawInsert('''
        INSERT INTO $_subTaskExecutionTableName
          ($_subTaskExecutionSubTaskIdColumnName, $_subTaskExecutionOccuranceIdColumnName, $_subTaskExecutionDateColumnName)
        VALUES (?, ?, ?)
      ''', [subTaskId, occuranceId, formattedDate]);
      return 1;
    } else {
      await db.rawDelete('''
        DELETE FROM $_subTaskExecutionTableName
        WHERE $_subTaskExecutionIdColumnName = ?
      ''', [existing.first[_subTaskExecutionIdColumnName]]);
      return 0;
    }
  }

  // Adds a new sub-task definition to a task.
  Future<int> createSubTask(int taskId, String title) async {
    final db = await database;
    return await db.rawInsert('''
      INSERT INTO $_subTasksTableName ($_subTasksTaskIdColumnName, $_subTasksTitleColumnName)
      VALUES (?, ?)
    ''', [taskId, title]);
  }

  // Deletes a sub-task definition and all its execution records.
  Future<void> deleteSubTask(int subTaskId) async {
    final db = await database;
    await db.rawDelete('''
      DELETE FROM $_subTaskExecutionTableName
      WHERE $_subTaskExecutionSubTaskIdColumnName = ?
    ''', [subTaskId]);
    await db.rawDelete('''
      DELETE FROM $_subTasksTableName
      WHERE $_subTasksIdColumnName = ?
    ''', [subTaskId]);
  }

  // Cleans up all sub-tasks when a parent task is fully deleted.
  Future<void> deleteSubTasksByTaskId(int taskId) async {
    final db = await database;

    // Get all subTask ids for this task
    final subTasks = await db.rawQuery('''
      SELECT $_subTasksIdColumnName FROM $_subTasksTableName
      WHERE $_subTasksTaskIdColumnName = ?
    ''', [taskId]);

    for (final row in subTasks) {
      await deleteSubTask(row[_subTasksIdColumnName] as int);
    }
  }

  // Walks backwards from yesterday counting consecutive days where the user
  // completed at least one task. Today is excluded so the streak doesn't
  // reset mid-day if tasks aren't done yet.
  // Returns 0 if yesterday had no completions.
  Future<int> getCurrentStreak() async {
    int streak = 0;
    DateTime day = DateTime.now().subtract(const Duration(days: 1));

    for (int i = 0; i < 365; i++) {
      final pct = await getDonePercentageForSelectedDay(day);
      if (pct > 0) {
        streak++;
        day = day.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  // Average completion percentage over the last [days] days that had at least
  // one task scheduled. Days with no tasks at all are skipped so they don't
  // drag the score down unfairly.
  // Returns 0.0 if no task data exists in the window.
  Future<double> getProductivityScore({int days = 30}) async {
    double total = 0;
    int counted = 0;

    for (int i = 1; i <= days; i++) {
      final day = DateTime.now().subtract(Duration(days: i));
      final formattedDate = DateFormat('yyyy-MM-dd').format(day);
      final db = await database;

      // Check if there were any tasks that day before including it
      final taskCount = await db.rawQuery('''
        SELECT COUNT(*) AS cnt
        FROM $_tasksOccuranceTableName o
        LEFT JOIN $_tasksTableName t
          ON o.$_tasksOccuranceTaskIdColumnName = t.$_tasksIdColumnName
        WHERE (o.$_tasksOccuranceTaskDateColumnName = ?
            OR o.$_tasksOccuranceDayOfWeekIdColumnName = ?)
          AND (o.$_tasksOccuranceDeletedAtColumnName >= ?
            OR o.$_tasksOccuranceDeletedAtColumnName IS NULL)
          AND t.$_tasksCreatedAtDateColumnName <= ?
      ''', [formattedDate, day.weekday, formattedDate, formattedDate]);

      final cnt = taskCount.first["cnt"] as int;
      if (cnt == 0) continue;

      final pct = await getDonePercentageForSelectedDay(day);
      total += pct;
      counted++;
    }

    if (counted == 0) return 0.0;
    return (total / counted).roundToDouble();
  }
}
