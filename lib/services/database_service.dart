import 'package:flutter/material.dart';
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
  final String _tasksDeletedAtColumnName = "deletedAt";

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

  final String _tasksExecutionTableName = "tasksExecution";
  final String _tasksExecutionIdColumnName = "id";
  final String _tasksExecutionTaskIdColumnName = "taskId";
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
            $_tasksDeletedAtColumnName String DEFAULT NULL
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
            FOREIGN KEY ($_tasksOccuranceTaskIdColumnName)
              REFERENCES $_tasksTableName($_tasksIdColumnName)
          )
        ''');

          //tasksExecution keeps track of "done tasks".
         db.execute('''
          CREATE TABLE $_tasksExecutionTableName (
            $_tasksExecutionIdColumnName INTEGER PRIMARY KEY,
            $_tasksExecutionTaskIdColumnName INTEGER,
            $_tasksExecutionDateColumnName TEXT NOT NULL,
            FOREIGN KEY ($_tasksExecutionTaskIdColumnName)
              REFERENCES $_tasksTableName($_tasksIdColumnName)
          )
        ''');
            },
    );
    return database;
  }

  //Handles creating the whole task
  void createTask(
    String title,String? description, 
    TimeOfDay startTime, TimeOfDay endTime, List<DateTime>? TaskDate, List<int>? DayOfWeekIds) async {
    final db = await database;
    int taskId = await addTask(db, title, description);
    addTaskOccurence(db,taskId, startTime, endTime, TaskDate, DayOfWeekIds);
  }

  //Part of createTask func
  //Creates tasks as instance in "tasks" table
  Future<int> addTask(Database db,String title,String? description) async {
    int taskId = await db.insert(
      _tasksTableName, 
        {
          _tasksTitleColumnName: title,
          _tasksDescriptionColumnName: description,
        }
      );

    return taskId;
  }

  //Part of createTask func
  //Adds task occurance to "tasksOccurance" table, maping the data and separating them into multiple instances (day/date) 
  void addTaskOccurence(
    Database db, int taskId, TimeOfDay startTime, 
    TimeOfDay endTime, List<DateTime>? TaskDate, List<int>? DayOfWeekIds
    ) async
    {

    String startTimeRes =
    '${startTime.hour.toString().padLeft(2, '0')}:'
    '${startTime.minute.toString().padLeft(2, '0')}';

    String endTimeRes =
    '${endTime.hour.toString().padLeft(2, '0')}:'
    '${endTime.minute.toString().padLeft(2, '0')}';

    if (TaskDate != null) {
      while (TaskDate.isNotEmpty == true) {
        insertTaskOccurenceWithDate(db, taskId, startTimeRes, endTimeRes, TaskDate.last);
        TaskDate.removeLast();
      }
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
  void insertTaskOccurenceWithDate(Database db, int taskId, String startTimeRes, 
    String endTimeRes, DateTime singleTaskDate) async{
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
  void insertTaskOccurenceWithWeekId(Database db, int taskId, String startTimeRes, 
  String endTimeRes, int weekId) async{
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

  Future<List<Task>> GetTasksForSelectedDay() async{
    final db = await database;
    final data = await db.query(_tasksTableName);
    //final data = await db.query(_tasksOccuranceTableName, where: '_tasksOccuranceTaskDateColumnName = ')
    List<Task> tasksForDay = data.map((e) => Task(id: e["id"] as int, title: e["title"] as String, description: e["description"] as String, deletedAt: e["deletedAt"] as String?)).toList();
    return tasksForDay;
  }
}