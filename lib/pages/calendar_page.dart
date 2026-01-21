import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/dayOfWeek.dart';
import 'package:flutter_application_1/services/database_service.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {

  final DatabaseService _databaseService = DatabaseService.instance;

  String? _title = null;
  String? _description = null;

  TimeOfDay? _startTime = null;
  TimeOfDay? _endTime = null;

  List<DateTime>? _taskDate = null;
  List<int>? _dayOfWeekId = null;

  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();

  DateTime? _selectedDate;
  final TextEditingController _dateController = TextEditingController();

  List<DayOfWeek> _allDaysOfWeek = [];
  List<DayOfWeek> _selectedDaysOfWeek = [];

  final TextEditingController _daysOfWeekController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDays();
  }

  Future<void> _loadDays() async {
    final days = await _databaseService.getDayOfWeeks();
    setState(() {
      _allDaysOfWeek = days ?? [];
    });
  }


  DateTime today = DateTime.now();
  void _onDaySelected(DateTime day, DateTime focusedDay){
    setState(() {
      today = day;
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
    if (_startTime == null || _endTime == null) return false;

    final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
    final endMinutes = _endTime!.hour * 60 + _endTime!.minute;

    return endMinutes > startMinutes;
  }

  Future<void> _selectDate() async{
    DateTime? _picked = await showDatePicker(
      context: context, 
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.utc(2020,01,01), 
      lastDate: DateTime.utc(2035,01,01),
      );

      if (_picked != null) {
        setState(() {
          _selectedDate = _picked;
          _dateController.text = _picked.toString().split(" ")[0];
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


    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        onPressed: () {
          showDialog(
            context: context, 
            builder: (_) => AlertDialog(
              backgroundColor: Colors.white,
              title: const Text('Add Task'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    onChanged: (value) {
                      setState(() {
                        _title = value;
                      });
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Title of Task',
                      ),
                  ),

                  const SizedBox(height: 10),

                  TextField(
                    onChanged: (value) {
                      setState(() {
                        _description = value;
                      });
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

                  const SizedBox(height: 15),

                  Material(
                        shape: Border.all(),
                        color: Colors.white,
                        child: MaterialButton(
                          onPressed: () {
                            if (!_isEndTimeValid()) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content:Text('End time must be after start time'),)
                              );
                            }
                            final List<int> selectedDaysOfWeekIds = _selectedDaysOfWeek.map((e) => e.id).toList();
                            //_databaseService.createTask(_title!, _description, _startTime!, _endTime!, _taskDate, _dayOfWeekId);
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
            )
            );
        },
        child: const Icon(
          Icons.add,
        ),
      ),
    
      body: Column(
        children: [
          _dayOfWeeksList(),
          Text("123"),
          Container(
            child: TableCalendar(
              headerStyle: HeaderStyle(
                formatButtonVisible: false, titleCentered: true
              ),
              availableGestures: AvailableGestures.all,
              selectedDayPredicate: (day)=>isSameDay(day, today),
              focusedDay: today, 
              firstDay: DateTime.utc(2020,01,01), 
              lastDay: DateTime.utc(2035,01,01),
              onDaySelected: _onDaySelected,
              )
          ),
        ],
      ),
    );
  }

  Widget _dayOfWeeksList() {
    return FutureBuilder(future: _databaseService.getDayOfWeeks(), builder: (context, snapshot){
        return Container();
    });
  }
}

