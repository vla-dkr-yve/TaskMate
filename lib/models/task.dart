class Task {
  final int occuranceId;
  final String title;
  final String? description;
  final String? deletedAt;
  final String? startTime, endTime;
  bool isDone;

  Task({
    required this.occuranceId,
    required this.title,
    this.description,
    this.deletedAt,
    this.startTime,
    this.endTime,
    required this.isDone
  });
}