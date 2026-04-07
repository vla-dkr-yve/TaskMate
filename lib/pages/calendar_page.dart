import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/models/dayOfWeek.dart';
import 'package:flutter_application_1/models/task.dart';
import 'package:flutter_application_1/services/database_service.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {

  final DatabaseService _databaseService = DatabaseService.instance;


  //List<Task> _chosenDayTasks = new List.empty();
  List<Task> _chosenDayTasks = [];

  String? _title = null;
  String? _description = null;

  TimeOfDay? _startTime = null;
  TimeOfDay? _endTime = null;

  DateTime? _taskDate = null;
  //List<int>? _dayOfWeekId = [];

  bool showDateError = false;
  bool showTitleError = false;

  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();

  DateTime _selectedDate = DateTime.now();

  final TextEditingController _dateController = TextEditingController();

  List<DayOfWeek> _allDaysOfWeek = [];
  List<DayOfWeek> _selectedDaysOfWeek = [];

  final TextEditingController _daysOfWeekController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDays();
    _GetInitTasks(_selectedDate);
  }

  Future<void> _loadDays() async {
    final days = await _databaseService.getDayOfWeeks();
    setState(() {
      _allDaysOfWeek = days;
    });
  }

  Future<void> _GetInitTasks(DateTime chosenDay) async {
    final tasks = await _databaseService.GetTasksForSelectedDay(chosenDay, chosenDay.weekday + 1);
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
    if (_startTime == null || _endTime == null) return true;

    final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
    final endMinutes = _endTime!.hour * 60 + _endTime!.minute;

    return endMinutes > startMinutes;
  }

  Future<void> _selectDate() async{
    DateTime? _picked = await showDatePicker(
      context: context, 
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
              Text("It’s okay to move at your own pace")
              ]
          ),

          //Calendar
          Container(
            child: TableCalendar(
              headerStyle: HeaderStyle(
                formatButtonVisible: false, titleCentered: true
              ),
              availableGestures: AvailableGestures.all,
              selectedDayPredicate: (day)=>isSameDay(day, _selectedDate),
              focusedDay: _selectedDate, 
              firstDay: DateTime.utc(2020,01,01), 
              lastDay: DateTime.utc(2035,01,01),
              onDaySelected: _onDaySelected,
              )
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
                        //color: const Color.fromARGB(255, 198, 201, 203),
                        //color: _chosenDayTasks[index].isDone == false ? Color.fromARGB(255, 243, 141, 141) : Color.fromARGB(255, 180, 249, 176),
                        color: _chosenDayTasks[index].deletedAt != null ? const Color.fromARGB(255, 198, 201, 203) : _chosenDayTasks[index].isDone == false ? Color.fromARGB(255, 243, 141, 141) : Color.fromARGB(255, 180, 249, 176),
                        borderRadius: BorderRadius.circular(15),
                        ),
                        child: TextButton(
                          child: Column(
                            //mainAxisAlignment: MainAxisAlignment.center,
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
                          onPressed: () => {
                            _displaySelectedTask(index),
                            },
                          onLongPress: () => {
                            _displayTaskOccuranceDeleteDialoge(index, _selectedDate!),
                          },
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
            content: Column(
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
                          //ADD HERE THE CODE FOR PROCESSING "createTask"
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
                          }
                          else{

                              final List<int> selectedDaysOfWeekIds = _selectedDaysOfWeek.map((e) => (e.id + 1)).toList();
                              await _databaseService.createTask(_title!, _description, _startTime, _endTime, _taskDate, selectedDaysOfWeekIds);
                              _GetInitTasks(_selectedDate);

                              Navigator.of(context).pop();
                          }
                          //New twick
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
          );
    },
          );
      }).then((value) {
                showTitleError = false;
               showDateError = false;
                _startTime = null;
                _endTime  = null;
                _taskDate = null;
                _description = null;
                //_dayOfWeekId = [];
                _title = null;
                _selectedDaysOfWeek = [];
                _dateController.text = "";
                _daysOfWeekController.text = "";
  }
      );
  }

  Future<dynamic> _displaySelectedTask(int index){
    bool isChanged = false; 
    return showDialog(
      context: context, 
      builder: (BuildContext builder) {return StatefulBuilder(builder: (context, StateSetter setState) {
        return AlertDialog(
          backgroundColor: Colors.white,
            title: Text(
              _chosenDayTasks[index].title, 
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 36
              ), 
              ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Description: " + (_chosenDayTasks[index].description == null ? "NA" : _chosenDayTasks[index].description!),
                  style: TextStyle(
                    fontSize: 24
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  "Start time: " + (_chosenDayTasks[index].startTime != null ? _chosenDayTasks[index].startTime! : "NA"),
                  style: TextStyle(
                    fontSize: 24
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  "End time: " + (_chosenDayTasks[index].endTime != null ? _chosenDayTasks[index].startTime! : "NA"),
                  style: TextStyle(
                    fontSize: 24
                  ),
                ),

                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "Is done?",
                      style: TextStyle(
                        fontSize: 24
                        ),
                      ),
                    Checkbox(
                    value: _chosenDayTasks[index].isDone, 
                    onChanged: (bool? value) => {
                      isChanged = !isChanged,
                      setState(() {
                      _chosenDayTasks[index].isDone = !_chosenDayTasks[index].isDone;
                      }
                    ),
                  },
                ),
                ]
                  
                )
                
                ],
            ),
        );
      }
        );
      }
      ).then((value) {
        if (isChanged) {
          setState(() {
            _databaseService.SaveCompletionState(_chosenDayTasks[index].occuranceId, _selectedDate);
          });
        }
      });
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
              _chosenDayTasks[index].deletedAt == null ? "Do you want to archive the instance? It will leave in history but will not occure any more" : "Do you want to delete instance it will be completely removed!", 
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
                      onPressed: Navigator.of(context).pop,
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
                          _chosenDayTasks[index].deletedAt == null ? deleteTaskOccurance(_chosenDayTasks[index].occuranceId) : deleteTaskCompletely(_chosenDayTasks[index].occuranceId);
                          _GetInitTasks(chosenDay);
                          Navigator.of(context).pop();
                        },
                ),
                ]
                  
                )
                
            );
      }
        );
      }
      ).then((value) {
        setState(() {
          _databaseService.SaveCompletionState(_chosenDayTasks[index].occuranceId, _selectedDate);
        });
      });
  }
  
    Future<VoidCallback?> deleteTaskOccurance(int occuranceId) async{

      await _databaseService.DeleteTaskOccurance(occuranceId, _selectedDate);
    }
    
    Future<VoidCallback?> deleteTaskCompletely(int occuranceId) async{
        await _databaseService.deleteTaskCompletely(occuranceId);
      }

}


