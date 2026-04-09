//Recheck tasks for previous days, whether they display correctly: 07.04.2026 - 4 tasks: 2 done, 2 not
//Finish the first page FINALLY!!!!!!
//Add notifications
//Think about adding google calendar API support
//Make end time obligatory if start is entered

import 'package:flutter/material.dart';
import 'package:flutter_application_1/bar%20graph/bar_graph.dart';
import 'package:flutter_application_1/models/task.dart';
import 'package:flutter_application_1/pages/calendar_page.dart';
import 'package:flutter_application_1/services/database_service.dart';
import 'package:intl/intl.dart';
import 'package:auto_size_text/auto_size_text.dart';

class HomePage extends StatefulWidget{
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>{

  final DatabaseService _databaseService = DatabaseService.instance;

  late final List<Widget> pages;

  int currentPage = 0;

  List<double> weekleSummary = [0,0,0,0,0,0,0];

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
  Widget build(BuildContext context){
      final pages = [
      HomePageContent(weekleSummary: weekleSummary, todayTasksWOTime: todayTasksWOTime, todayTasksWTime: todayTasksWTime, tasksByHour: tasksByHour),
      const CalendarPage(),
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
      title: Text(
        'TaskMate',
        style: TextStyle(
          color: Colors.black,
          fontSize:24,
          fontWeight: FontWeight.bold,
          )
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
        }
      },

      items: const [BottomNavigationBarItem(
        icon: 
          Icon(
            Icons.home,
            ),
        label: "Home",
        ),
      BottomNavigationBarItem(
        icon: 
          Icon(
            Icons.calendar_month_outlined,
            ),
        label: "Calendar"
        )
      ]
    );
  }
  
  Future<void> getPercentage() async{
    List<double> one = await _databaseService.getDonePercentage(DateTime.now());

    setState(() {
    weekleSummary = one;
    },
    );
  }
  
  Future<void> getTasks() async{
    final tasks = await _databaseService.GetTasksForSelectedDay(DateTime.now(), DateTime.now().weekday + 1);

    setState(() {
      todayTasks = tasks;
    });
    await getTasksTime();
    groupTasksByHour();
  }
  
  Future<void> getTasksTime() async{
    final List<Task> tasksWTime = [];
    final List<Task> tasksWOTime = [];

    for (var e in todayTasks) {
      if (e.startTime == null) {
        tasksWOTime.add(e);
      }
      else{
        tasksWTime.add(e);
      }
    }
    setState(() {
      todayTasksWOTime = tasksWOTime;
      todayTasksWTime  = tasksWTime;
    });
  }

  void groupTasksByHour() {
  tasksByHour.clear();

  for (var task in todayTasksWTime) {
    if (task.startTime == null) continue;

    final hour = int.parse(task.startTime!.split(":")[0]);

    if (!tasksByHour.containsKey(hour)) {
      tasksByHour[hour] = [];
    }

    tasksByHour[hour]!.add(task);
  }
}
}

class HomePageContent extends StatelessWidget {
  const HomePageContent({
    super.key,
    required this.weekleSummary,
    required this.todayTasksWTime,
    required this.todayTasksWOTime,
    required this.tasksByHour
  });

  final List<double> weekleSummary;
  final List<Task> todayTasksWOTime;
  final List<Task> todayTasksWTime;
  final Map<int, List<Task>> tasksByHour;
  
  

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Container(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 60),
            child: SizedBox(
              height: 200,
              child: MyBarGraph(
                weeklySummary: weekleSummary,
              ),
              ),
          ),
        
        ),
      ),
      Column(
            children: [
              SizedBox(height: 25),
              Text(
                "Tasks for today: ", 
                style: TextStyle(
                  fontSize: 20,
                  ),
                ),
              ListView.separated(
                physics: NeverScrollableScrollPhysics(),
                itemCount: todayTasksWOTime.length,
                padding: EdgeInsets.all(15),
                shrinkWrap: true,
                separatorBuilder: (context,index) => SizedBox(height: 25), 
                itemBuilder: (context, index) {
                  return Opacity(
                    opacity: 1,
                    child: Container(
                      padding: EdgeInsets.all(10),
                      height: 90,
                      decoration: BoxDecoration(
                        //color: const Color.fromARGB(255, 198, 201, 203),
                        //color: _chosenDayTasks[index].isDone == false ? Color.fromARGB(255, 243, 141, 141) : Color.fromARGB(255, 180, 249, 176),
                        color: todayTasksWOTime[index].deletedAt != null ? const Color.fromARGB(255, 198, 201, 203) : todayTasksWOTime[index].isDone == false ? Color.fromARGB(255, 243, 141, 141) : Color.fromARGB(255, 180, 249, 176),
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
                                  todayTasksWOTime[index].title,
                                  style: TextStyle(
                                    fontSize: 24
                                  ),
                                ),
                              ),
                              Expanded(
                                child: AutoSizeText(
                          
                                  maxLines: 1,
                                  minFontSize: 16,
                                  todayTasksWOTime[index].description == null ? "" : todayTasksWOTime[index].description!,
                                  style: TextStyle(
                                    fontSize: 20
                                  ),
                                ),
                              ),
                              
                              ],
                            
                          ),
                          onPressed: () => {
                            //_displaySelectedTask(index),
                            },
                          onLongPress: () => {
                            //_displayTaskOccuranceDeleteDialoge(index, _selectedDate!),
                          },
                        ),
                      ),
                  );
                  },
                ),
                ListView.builder(
  itemCount: 24,
  physics: NeverScrollableScrollPhysics(),
  shrinkWrap: true,
  itemBuilder: (context, hour) {
    final tasks = tasksByHour[hour] ?? [];

    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TIME COLUMN
          
          SizedBox(
            width: 70,
            child: Column(
              children: [
                Text(
                  "${hour.toString().padLeft(2, '0')}:00",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 4),
                Container(
                  height: tasks.isEmpty ? 100 : tasks.length * 110,
                  width: 2,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),

          // TASKS COLUMN
          Expanded(
            child: Column(
              children: tasks.isEmpty
                  ? [
                      // empty hour placeholder
                      Container(
                        height: 100,
                        alignment: Alignment.centerLeft,
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Divider(
                          color: Colors.grey[300],
                          thickness: 1,
                        ),
                      ),
                    ]
                  : tasks.map((task) {
                      return Container(
                        height: 100,
                        margin: EdgeInsets.only(bottom: 10, right: 10, top: 10),
                        padding: EdgeInsets.all(12),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: task.deletedAt != null
                              ? Colors.grey[300]
                              : task.isDone
                                  ? Colors.green[200]
                                  : Colors.red[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            SizedBox(height: 10),

                            if (task.description != null)
                              Text(
                                task.description!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 14),
                              ),
                          ],
                        ),
                        ),
                      );
                    }).toList(),
            ),
          ),
        ],
      ),
    );
  },
)
            ],
          ),
      ]
    );
  }

  
}