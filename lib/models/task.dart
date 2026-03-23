class Task {
  final String title, description;
  final String? deletedAt;
  final String? startTime, endTime;
  bool isDone;

  Task({
    required this.title,
    required this.description,
    this.deletedAt,
    this.startTime,
    this.endTime,
    required this.isDone
  });
}