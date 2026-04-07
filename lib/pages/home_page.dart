import 'package:flutter/material.dart';
import 'package:flutter_application_1/bar%20graph/bar_graph.dart';
import 'package:flutter_application_1/pages/calendar_page.dart';
import 'package:flutter_application_1/services/database_service.dart';

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

  @override
  void initState() {
    super.initState();
    getPercentage();
  }

  @override
  Widget build(BuildContext context){
      final pages = [
      HomePageContent(weekleSummary: weekleSummary),
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
}

class HomePageContent extends StatelessWidget {
  const HomePageContent({
    super.key,
    required this.weekleSummary,
  });

  final List<double> weekleSummary;

  @override
  Widget build(BuildContext context) {
    return Align(
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

    );
  }
}