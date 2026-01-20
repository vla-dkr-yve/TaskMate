import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime today = DateTime.now();
  void _onDaySelected(DateTime day, DateTime focusedDay){
    setState(() {
      today = day;
    });
  }
  
  @override
  Widget build(BuildContext context) {


    return Column(
      children: [
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
    );
  }
}