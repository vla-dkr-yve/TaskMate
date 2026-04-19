import 'package:flutter_application_1/bar%20graph/individual_bar.dart';

class BarData {
  final double sunAmount;
  final double monAmount;
  final double tueAmount;
  final double wenAmount;
  final double thurAmount;
  final double friAmount;
  final double satAmount;

  BarData({
    required this.sunAmount,
    required this.monAmount,
    required this.tueAmount,
    required this.wenAmount,
    required this.thurAmount,
    required this.friAmount,
    required this.satAmount,
  });


  List<IndividualBar> barData = [];

  void initializeBarData() {
    barData = [

        IndividualBar(x: 0, y: monAmount),

        IndividualBar(x: 1, y: tueAmount),

        IndividualBar(x: 2, y: wenAmount),

        IndividualBar(x: 3, y: thurAmount),

        IndividualBar(x: 4, y: friAmount),

        IndividualBar(x: 5, y: satAmount),

        IndividualBar(x: 6, y: sunAmount),
    ];
  }
}