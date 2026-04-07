import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/execution.dart';
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
  //final String _tasksOccuranceTaskIsDone = "isDone";

  final String _tasksExecutionTableName = "tasksExecution";
  final String _tasksExecutionIdColumnName = "id";
  final String _tasksExecutionTaskOccuranceIdColumnName = "taskOccuranceId";
  final String _tasksExecutionDateColumnName = "executionDate";

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
      version: 2,
      onCreate: (db, version) {
        //tasks - Basic table that keeps track of all existing tasks, not carring about date when they occur.
         db.execute('''
          CREATE TABLE $_tasksTableName (
            $_tasksIdColumnName INTEGER PRIMARY KEY,
            $_tasksTitleColumnName TEXT(50) NOT NULL,
            $_tasksDescriptionColumnName TEXT(300),
            $_tasksCreatedAtDateColumnName String NOT NULL 
          )
        ''');

        //Just keeps day of weeks
         db.execute('''
          CREATE TABLE $_daysOfWeekTableName (
            $_daysOfWeekIdColumnName INTEGER PRIMARY KEY,
            $_daysOfWeekTitleColumnName TEXT(50) NOT NULL
          )
        ''');

         db.execute('''
          INSERT INTO $_daysOfWeekTableName ($_daysOfWeekTitleColumnName)
          VALUES 
            ('Sunday'),
            ('Monday'),
            ('Tuesday'),
            ('Wednesday'),
            ('Thursday'),
            ('Friday'),
            ('Saturday')
        ''');

          //tasksOccurance keeps track of all tasks in the following form:
          //1 tasksOccurance instance per day/day_of_week 
          //they cannot mix: 1 instance of tasksOccurance may have either one date assigned to it or one day of week, 
          //if needed both, or more than 1 day of week assigned than multiple instances are creater, each with its own date/day
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

          //tasksExecution keeps track of "done tasks".
         db.execute('''
          CREATE TABLE $_tasksExecutionTableName (
            $_tasksExecutionIdColumnName INTEGER PRIMARY KEY,
            $_tasksExecutionTaskOccuranceIdColumnName INTEGER,
            $_tasksExecutionDateColumnName TEXT NOT NULL,
            FOREIGN KEY ($_tasksExecutionTaskOccuranceIdColumnName)
              REFERENCES $_tasksOccuranceTableName($_tasksOccuranceIdColumnName)
          )
        ''');
            },
    );
    return database;
  }

  //Handles creating the whole task
  Future<void> createTask(
    String title,String? description, 
    TimeOfDay? startTime, TimeOfDay? endTime, DateTime? TaskDate, List<int>? DayOfWeekIds) async{
    final db = await database;
    int taskId = await addTask(db, title, description);
    await addTaskOccurence(db,taskId, startTime, endTime, TaskDate, DayOfWeekIds);
  }

  //Part of createTask func
  //Creates tasks as instance in "tasks" table
  Future<int> addTask(Database db,String title,String? description) async {
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

  //Part of createTask func
  //Adds task occurance to "tasksOccurance" table, maping the data and separating them into multiple instances (day/date) 
  Future<void> addTaskOccurence(
    Database db, int taskId, TimeOfDay? startTime, 
    TimeOfDay? endTime, DateTime? TaskDate, List<int>? DayOfWeekIds
    ) async
    {
    
    String? startTimeRes = null;
    String? endTimeRes = null;

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

  //Part of addTaskOccurence func. 
  //Adds data by date
  void insertTaskOccurenceWithDate(Database db, int taskId, String? startTimeRes, 
    String? endTimeRes, String singleTaskDate) async{
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

  //Part of addTaskOccurence func. 
  //Adds data by WeekId
  void insertTaskOccurenceWithWeekId(Database db, int taskId, String? startTimeRes, 
  String? endTimeRes, int weekId) async{
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

  //Returns 
  Future<List<DayOfWeek>> getDayOfWeeks() async{
    final db = await database;
    final data = await db.query(_daysOfWeekTableName);

    List<DayOfWeek> dayOfWeek = data.map((e) => DayOfWeek(id: e["id"] as int, title: e["title"] as String)).toList();
    return dayOfWeek;
  }

  Future<List<Task>> GetTasksForSelectedDay(DateTime chosenDay, int weekDayId) async{
    final db = await database;

    final formattedDate = DateFormat('yyyy-MM-dd').format(chosenDay);

//      final data = await db.rawQuery('''
//    SELECT 
//    t.$_tasksTitleColumnName, t.$_tasksDescriptionColumnName, 
//    o.$_tasksOccuranceStartTimeColumnName, o.$_tasksOccuranceEndTimeColumnName
//    FROM $_tasksOccuranceTableName o
//    LEFT JOIN $_tasksTableName t
//      ON o.$_tasksOccuranceTaskIdColumnName = t.$_tasksIdColumnName
//    WHERE o.$_tasksOccuranceTaskDateColumnName = ?
//  ''', [formattedDate]);

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
     ON e.$_tasksExecutionTaskOccuranceIdColumnName = o.$_tasksOccuranceIdColumnName  AND e.$_tasksExecutionDateColumnName = ?
   WHERE ((o.$_tasksOccuranceTaskDateColumnName = ? OR o.$_tasksOccuranceDayOfWeekIdColumnName = ? ) AND (o.$_tasksOccuranceDeletedAtColumnName >= ? OR o.$_tasksOccuranceDeletedAtColumnName IS NULL)) AND t.$_tasksCreatedAtDateColumnName <= ?
 ''', [formattedDate,formattedDate, weekDayId, formattedDate, formattedDate]);

    print(chosenDay);
    print("\n");
    print([DateFormat('yyyy-MM-dd').format(chosenDay)]);
    print(data);

    //final data = await db.query(_tasksOccuranceTableName, where: '_tasksOccuranceTaskDateColumnName = ')
    List<Task> tasksForDay = data.map((e) => Task(
      occuranceId: e["id"] as int,
      title: e["title"] as String, 
      description: e["description"] as String?, 
      deletedAt: e["deletedAt"] as String?, 
      startTime: e["startTime"] as String?, 
      endTime: e["endTime"] as String?,
      doneAt: (e["$_tasksExecutionDateColumnName"] != null ? e["$_tasksExecutionDateColumnName"] : null) as String?,
      isDone: e["executionDate"] == null ? false : true)).toList();
    //List<int> ids = data.map(data.)
    return tasksForDay;
  }

  Future<void> SaveCompletionState(int id, DateTime day) async{

    final db = await database;
    final formattedDate = DateFormat('yyyy-MM-dd').format(day);


    final occurances = await db.rawQuery('''

      SELECT * 
      FROM $_tasksExecutionTableName
      WHERE $_tasksExecutionTaskOccuranceIdColumnName = ? AND $_tasksExecutionDateColumnName = ?

''', [id, formattedDate]);

    List<Execution> occurancesForm = occurances.map((e) => Execution(id: e["id"] as int, occuranceId: e["taskOccuranceId"] as int, executionDate: e["executionDate"] as String)).toList();

    if (occurancesForm.isEmpty) {
      CreateNewExecution(id, formattedDate,db);
    }
    else{
      DeleteExecutionInstance(occurancesForm[0].id, db);
    }

  }
  
  Future<void> CreateNewExecution(int id, String day, Database db) async{
    await db.rawInsert('''
    INSERT INTO 
    $_tasksExecutionTableName($_tasksExecutionTaskOccuranceIdColumnName, $_tasksExecutionDateColumnName) 
    VALUES (?, ?)
    ''', 
    [id, day]);
  }
  
  Future<void> DeleteExecutionInstance(int instanceId, Database db) async{
    await db.rawDelete('''
    DELETE FROM $_tasksExecutionTableName WHERE $_tasksExecutionIdColumnName = ?
  ''', [instanceId]);
  }

  Future<void> DeleteTaskOccurance(int occuranceId, DateTime day) async {

    final db = await database;
    final formattedDate = DateFormat('yyyy-MM-dd').format(day);

    await db.rawUpdate('''
    UPDATE $_tasksOccuranceTableName SET $_tasksOccuranceDeletedAtColumnName = ? WHERE $_tasksOccuranceIdColumnName = ?
  ''', [formattedDate,occuranceId]);
  }

  Future<void> deleteTaskCompletely(int occuranceId) async {

    final db = await database;
    //final formattedDate = DateFormat('yyyy-MM-dd').format(day);

    await db.rawDelete('''
    DELETE FROM $_tasksOccuranceTableName
    WHERE $_tasksOccuranceIdColumnName = ?
''', [occuranceId]);
  }

  Future<List<double>> getDonePercentage(DateTime chosenDay) async {
  List<double> res = List.filled(7, 0);

  final startOfWeek =
      chosenDay.subtract(Duration(days: chosenDay.weekday));

  for (int i = 0; i < 7; i++) {
    final day = startOfWeek.add(Duration(days: i));

    res[i] = await getDonePercentageForSelectedDay(day);
  }

  return res;
}

  Future<double> getDonePercentageForSelectedDay(chosenDay) async{

    final db = await database;

    double res = 0;

    final formattedDate = DateFormat('yyyy-MM-dd').format(chosenDay);

    final done = await db.rawQuery('''
   SELECT COUNT(e.$_tasksExecutionTaskOccuranceIdColumnName) AS total
   FROM $_tasksOccuranceTableName o
   LEFT JOIN $_tasksExecutionTableName e
    ON o.$_tasksOccuranceIdColumnName = e.$_tasksExecutionTaskOccuranceIdColumnName
   WHERE o.$_tasksOccuranceTaskDateColumnName = ? OR o.$_tasksOccuranceDayOfWeekIdColumnName = ? ''', [formattedDate, chosenDay.weekday + 1]);

    int doneForm = done.first["total"] as int;

    final all = await db.rawQuery('''
   SELECT COUNT(o.$_tasksOccuranceIdColumnName) AS total
   FROM $_tasksOccuranceTableName o
   WHERE o.$_tasksOccuranceTaskDateColumnName = ? OR o.$_tasksOccuranceDayOfWeekIdColumnName = ? ''', [formattedDate, chosenDay.weekday + 1]);

    int allForm = all.first["total"] as int;

    if (allForm != 0) {
      res = ((doneForm/allForm) * 100).roundToDouble();
      
      print(res);
    }
  

    return res;
  }
}