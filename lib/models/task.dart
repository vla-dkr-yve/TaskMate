class Task {
  final int id;
  final String title, description;
  final String? deletedAt;
  //final String startTime, endTime;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.deletedAt,
    //required this.startTime,
    //required this.endTime,
  });
}