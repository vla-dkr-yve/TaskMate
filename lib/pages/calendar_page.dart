import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/services/notification_service.dart';
import 'package:flutter_application_1/services/task_dialog_service.dart';
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

  String? _title = null;
  String? _description = null;

  TimeOfDay? _startTime = null;
  TimeOfDay? _endTime = null;

  DateTime? _taskDate = null;

  bool showDateError = false;
  bool showTitleError = false;
  bool showTimeError = false;

  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();

  DateTime _selectedDate = DateTime.now();

  final TextEditingController _dateController = TextEditingController();

  List<DayOfWeek> _allDaysOfWeek = [];
  List<DayOfWeek> _selectedDaysOfWeek = [];

  final TextEditingController _daysOfWeekController = TextEditingController();

  String _slogan = "";

  @override
  void initState(){
    super.initState();
    _loadDays();
    _GetInitTasks(_selectedDate);
    getSlogan();
    _loadMonthScores(_selectedDate);
  }

  Future<void> _loadDays() async {
    final days = await _databaseService.getDayOfWeeks();
    setState(() {
      _allDaysOfWeek = days;
    });
  }

  Color? _getProductivityColor(DateTime day) {
    final score = _productivityScores[DateTime(day.year, day.month, day.day)];
    if (score == null) return null;  // not yet loaded
    if (score <= 0) return null;      // no tasks that day → no color
    if (score >= 80) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
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
    setState(() {
      _chosenDayTasks = tasks;
    }); 
  }

  void _onDaySelected(DateTime day, DateTime focusedDay){
    setState(() {
      _selectedDate = day;
      _GetInitTasks(_selectedDate);
    });
  }
  
  String _format24Hour(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }


  Future<void> _pickTime({
    required TextEditingController controller,
    required ValueChanged<TimeOfDay> onTimePicked,
    }) async {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              alwaysUse24HourFormat: true,
            ),
            child: child!,
          );
        },
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

  Future<void> _selectDate() async{
    DateTime? _picked = await showDatePicker(
      context: context, 
      locale: const Locale('en', 'GB'),
      initialDate: _selectedDate,
      firstDate: DateTime.utc(2020,01,01), 
      lastDate: DateTime.utc(2035,01,01),
      );

      if (_picked != null) {
        setState(() {
          _selectedDate = _picked;
          _dateController.text = _picked.toString().split(" ")[0];
          _taskDate = _picked;
        });
      }
  }

  void _updateDaysField() {
  setState(() {
      _daysOfWeekController.text =
          _selectedDaysOfWeek.map((e) => e.title).join(', ');
    });
  }


  void _openDaysPicker() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Select days'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: _allDaysOfWeek.map((day) {
                  final isSelected =
                      _selectedDaysOfWeek.any((d) => d.id == day.id);

                  return CheckboxListTile(
                    title: Text(day.title),
                    value: isSelected,
                    onChanged: (checked) {
                      setDialogState(() {
                        if (checked == true) {
                          _selectedDaysOfWeek.add(day);
                        } else {
                          _selectedDaysOfWeek.removeWhere(
                            (d) => d.id == day.id,
                          );
                        }
                      });
                    },
                  );
                }).toList(),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                _updateDaysField();
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> getSlogan() async {
  if (AppState.slogan == null) {
    AppState.slogan = await getRandomLine();
  }

  // Reuse the same value
  _slogan = AppState.slogan!;
  setState(() {});
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

  @override
  Widget build(BuildContext context) {

    //main page
    return Scaffold(
      backgroundColor: Colors.transparent,
      //Button in bottom-right corner
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        onPressed: () {
          CreateTaskOnClick(context);
        },
        child: const Icon(
          Icons.add,
        ),
      ),
    
      //Center of the page (calendar, displayed tasks)
      body: ListView(
        children: [
          Column(
            children: [
              _dayOfWeeksList(),
              Text(_slogan)
              ]
          ),

          //Calendar
          Container(
  child: TableCalendar(
    headerStyle: HeaderStyle(
      formatButtonVisible: false, titleCentered: true
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
        if (color == null) return null; // use default rendering

        return Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '${day.day}',
            style: const TextStyle(color: Colors.white),
          ),
        );
      },
      // also override selected/today so they stay consistent
      selectedBuilder: (context, day, focusedDay) {
        final color = _getProductivityColor(day) ?? Colors.blue;
        return Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          alignment: Alignment.center,
          child: Text('${day.day}', style: const TextStyle(color: Colors.white)),
        );
      },
              todayBuilder: (context, day, focusedDay) {
                final color = _getProductivityColor(day) ?? Colors.blueGrey;
                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text('${day.day}', style: const TextStyle(color: Colors.white)),
                );
              },
            ),
          ),
        ),
          Column(
            children: [
              SizedBox(height: 25),
              Text(
                "Tasks", 
                style: TextStyle(
                  fontSize: 20,
                  ),
                ),
              ListView.separated(
                physics: NeverScrollableScrollPhysics(),
                itemCount: _chosenDayTasks.length,
                padding: EdgeInsets.all(15),
                shrinkWrap: true,
                separatorBuilder: (context,index) => SizedBox(height: 25), 
                itemBuilder: (context, index) {
                  return Opacity(
                    opacity: 1,
                    child: Container(
                      padding: EdgeInsets.all(10),
                      height: 145,
                      decoration: BoxDecoration(
                        color: _chosenDayTasks[index].deletedAt != null ? const Color.fromARGB(255, 198, 201, 203) : _chosenDayTasks[index].isDone == false ? Color.fromARGB(255, 243, 141, 141) : Color.fromARGB(255, 180, 249, 176),
                        borderRadius: BorderRadius.circular(15),
                        ),
                        child: GestureDetector(
                          
                          onTap: () => {
                            TaskDialog.show(
                              context: context,
                              task: _chosenDayTasks[index],
                              selectedDate: _selectedDate,
                              onChanged: (isChanged) async {
                                if (isChanged) {
                                  await _databaseService.SaveCompletionState(
                                    _chosenDayTasks[index].occuranceId,
                                    _selectedDate,
                                  );
                                  _notificationService.scheduleNotificationForOneTask(_chosenDayTasks[index]);
                                  setState(() { });
                                }
                              },
                            ),
                            },
                          onLongPress: () => {
                            _displayTaskOccuranceDeleteDialoge(index, _selectedDate!),
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: AutoSizeText(
                                  maxLines: 2,
                                  minFontSize: 18,
                                  textAlign: TextAlign.center,
                                  _chosenDayTasks[index].title,
                                  style: TextStyle(
                                    fontSize: 24
                                  ),
                                ),
                              ),
                              Expanded(
                                child: AutoSizeText(
                          
                                  maxLines: 2,
                                  minFontSize: 16,
                                  _chosenDayTasks[index].description == null ? "" : _chosenDayTasks[index].description!,
                                  style: TextStyle(
                                    fontSize: 20
                                  ),
                                ),
                              ),
                              
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Text(
                                textAlign: TextAlign.start,
                                _chosenDayTasks[index].startTime != null ? _chosenDayTasks[index].startTime! : "",
                                style: TextStyle(
                                  fontSize: 18
                                ),
                                
                              ),
                                  Text(
                                    textAlign: TextAlign.end,
                                    _chosenDayTasks[index].endTime != null ? _chosenDayTasks[index].endTime! : "",
                                    style: TextStyle(
                                      fontSize: 18
                                    ),
                                  ),
                                ],
                              )
                            ],
                            
                          ),
                        ),
                      ),
                  );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }


  //Function for displaying dialog to create task
  Future<dynamic> CreateTaskOnClick(BuildContext context) {
    
    return showDialog(
          context: context, 
          builder: (context) {
  return StatefulBuilder(
    builder: (context, dialogSetState) { return AlertDialog(
            backgroundColor: Colors.white,
            title: const Text('Add Task'),
            content: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  onChanged: (value) {
                    _title = value;
                  },
                  decoration: new InputDecoration(
                    hintText: "Title of Task*",
                    errorText: showTitleError ? "Title is required" : null,
                    border: new OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: showTitleError  ? Colors.redAccent   : Theme.of(context).dividerColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: showTitleError ? Colors.redAccent : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                  ),
                ),

                const SizedBox(height: 10),

                TextField(
                  onChanged: (value) {
                    _description = value;
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Description of Task',
                    ),
                ),

                const SizedBox(height: 10),

                TextField(
                  controller: _startTimeController,
                  readOnly: true,
                  onTap: () {
                    _pickTime(
                      controller: _startTimeController,
                      onTimePicked: (time) => _startTime = time,
                    );
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Start Time',
                    suffixIcon: Icon(Icons.access_time),
                  ),
                ),

                const SizedBox(height: 10),

                TextField(
                  controller: _endTimeController,
                  readOnly: true,
                  onTap: () {
                    _pickTime(
                      controller: _endTimeController,
                      onTimePicked: (time) => _endTime = time,
                    );
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'End Time',
                    suffixIcon: Icon(Icons.access_time),
                  ),
                ),

                const SizedBox(height: 10),

                TextField(
                  controller: _dateController,
                  readOnly: true,
                  onTap: () {
                    _selectDate();
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Date',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                ),

                const SizedBox(height: 10),

                TextField(
                  controller: _daysOfWeekController,
                  readOnly: true,
                  onTap: _openDaysPicker,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Select days of week',
                    suffixIcon: Icon(Icons.calendar_view_week),
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  "Date or day of week must be selected",
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: showDateError == false ? Colors.black : Colors.redAccent,
                  ),
                ),

                const SizedBox(height: 15),

                Material(
                      shape: Border.all(),
                      color: Colors.white,
                      child: MaterialButton(
                        onPressed: () async {
                          if (_title == null || _title!.isEmpty) {
                            dialogSetState((){
                              showTitleError = true;
                            });
                          }
                          else if (!_isEndTimeValid()) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content:Text('End time must be after start time'),)
                            );
                          }
                          else if(_taskDate == null && _selectedDaysOfWeek.isEmpty){
                            dialogSetState(() {
                              showDateError = true;
                            });
                          }else if(_taskDate != null && (_taskDate!.isBefore(DateTime(DateTime.now().year,DateTime.now().month,DateTime.now().day)))){
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('You cannot create a task in the past'),
                                ),
                              );
                          }
                          else{

                              final List<int> selectedDaysOfWeekIds = _selectedDaysOfWeek.map((e) => (e.id)).toList();
                              int taskId = await _databaseService.createTask(_title!, _description, _startTime, _endTime, _taskDate, selectedDaysOfWeekIds);

                              if (_taskDate == DateTime.now() || (selectedDaysOfWeekIds.contains(DateTime.now().weekday))) {
                                int occuranceIdToSend = await _databaseService.getOccuranceId(taskId, DateTime.now());
                                _notificationService.scheduleNotificationForOneTask(Task(occuranceId: occuranceIdToSend, title: _title!, isDone: false, startTime: _startTime.toString()));
                              }

                              _GetInitTasks(_selectedDate);

                              Navigator.of(context).pop();
                          }
                        },
                        child: const Text(
                          "Done",
                          style: TextStyle(
                            color: Colors.black,
                          ),
                        ),
                      ),
                    )
                ],
            ),
            ),
          );
    },
          );
      }).then((value) {
                showTitleError = false;
               showDateError = false;
               showTimeError = false;
                _startTime = null;
                _endTime  = null;
                _taskDate = null;
                _description = null;
                _title = null;
                _selectedDaysOfWeek = [];
                _dateController.text = "";
                _daysOfWeekController.text = "";
                _startTimeController.text = "";
                _endTimeController.text = "";
  }
      );
  }

  Widget _dayOfWeeksList() {
    return FutureBuilder(future: _databaseService.getDayOfWeeks(), builder: (context, snapshot){
        return Container();
    });
  }
  
  Future <dynamic>_displayTaskOccuranceDeleteDialoge(int index, DateTime chosenDay) async{

    return showDialog(
      context: context, 
      builder: (BuildContext builder) {return StatefulBuilder(builder: (context, StateSetter setState) {
        return AlertDialog(
          backgroundColor: Colors.white,
            title: Text(
              _chosenDayTasks[index].deletedAt == null ? "Do you want to archive the instance? It will leave in history but will not occure any more" : "Do you want to delete instance? It will be completely removed!", 
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24
              ), 
              ),
            content: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child:
                      Text(
                      "Cancel",
                      style: TextStyle(
                        fontSize: 24
                        ),
                      ),
                    ),
                    TextButton(
                    child:
                      Text(
                      _chosenDayTasks[index].deletedAt == null ? "Archive" : "Delete",
                      style: TextStyle(
                        fontSize: 24
                        ),
                      ),
                      onPressed: () {
                          //_notificationService.removeScheduledNotificationForOneTask(_chosenDayTasks[index]);
                          _chosenDayTasks[index].deletedAt == null ? deleteTaskOccurance(_chosenDayTasks[index].occuranceId) : deleteTaskCompletely(_chosenDayTasks[index].occuranceId);
                          _notificationService.scheduleNotificationForOneTask(_chosenDayTasks[index]);
                          _GetInitTasks(chosenDay);
                          Navigator.of(context).pop(true);
                        },
                        
                ),
                ]
                  
                )
                
            );
      }
        );
      }
      ).then((didAction) async {
          if (didAction != true) return;
          setState(() {});
      });
  }
  
    Future<VoidCallback?> deleteTaskOccurance(int occuranceId) async{
      await _databaseService.DeleteTaskOccurance(occuranceId, _selectedDate);
    }
    
    Future<VoidCallback?> deleteTaskCompletely(int occuranceId) async{
        await _databaseService.deleteTaskCompletely(occuranceId);
      }

}

