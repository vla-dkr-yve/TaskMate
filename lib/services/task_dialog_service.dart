import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/sub_task.dart';
import '../services/database_service.dart';

class TaskDialog {
  static Future<void> show({
    required BuildContext context,
    required Task task,
    required DateTime selectedDate,
    required Function(bool isChanged) onChanged,
  }) async {
    final bool originalState = task.isDone;
    final db = DatabaseService.instance;

    // Resolve taskId once, before opening the dialog
    final int taskId = await db.getTaskIdFromOccuranceId(task.occuranceId);

    // Load sub-tasks for this occurance + date
    List<SubTask> subTasks = await db.getSubTasksForOccurance(task.occuranceId, selectedDate);

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {

            // ── Add sub-task inline ───────────────────────────────────────────
            final TextEditingController _newSubTaskController = TextEditingController();

            Future<void> addSubTask() async {
              final title = _newSubTaskController.text.trim();
              if (title.isEmpty) return;
              await db.createSubTask(taskId, title);
              final updated = await db.getSubTasksForOccurance(task.occuranceId, selectedDate);
              setState(() {
                subTasks = updated;
                _newSubTaskController.clear();
              });
            }

            Future<void> toggleSubTask(SubTask subTask) async {
              await db.toggleSubTaskExecution(subTask.id, task.occuranceId, selectedDate);
              final updated = await db.getSubTasksForOccurance(task.occuranceId, selectedDate);
              setState(() => subTasks = updated);
            }

            Future<void> removeSubTask(SubTask subTask) async {
              await db.deleteSubTask(subTask.id);
              final updated = await db.getSubTasksForOccurance(task.occuranceId, selectedDate);
              setState(() => subTasks = updated);
            }

            // ─────────────────────────────────────────────────────────────────

            return AlertDialog(
              backgroundColor: Colors.white,
              title: Text(
                task.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 36),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Existing fields ───────────────────────────────────────
                    Text(
                      "Description: ${task.description ?? "NA"}",
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(height: 10),

                    Text(
                      "Start time: ${task.startTime ?? "NA"}",
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(height: 10),

                    Text(
                      "End time: ${task.endTime ?? "NA"}",
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          "Is done?",
                          style: TextStyle(fontSize: 24),
                        ),
                        Checkbox(
                          value: task.isDone,
                          onChanged: (value) {
                            setState(() {
                              task.isDone = value!;
                            });
                          },
                        ),
                      ],
                    ),

                    // ── Sub-tasks section ─────────────────────────────────────
                    const Divider(height: 24),

                    const Text(
                      "Sub-tasks",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    if (subTasks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          "No sub-tasks yet.",
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ),

                    // Sub-task list
                    ...subTasks.map((subTask) => Row(
                      children: [
                        Checkbox(
                          value: subTask.isDone,
                          onChanged: (_) => toggleSubTask(subTask),
                        ),
                        Expanded(
                          child: Text(
                            subTask.title,
                            style: TextStyle(
                              fontSize: 18,
                              decoration: subTask.isDone
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              color: subTask.isDone ? Colors.grey : Colors.black,
                            ),
                          ),
                        ),
                        // Delete sub-task button
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                          onPressed: () => removeSubTask(subTask),
                          tooltip: "Remove sub-task",
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    )),

                    // Add sub-task input row
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newSubTaskController,
                            style: const TextStyle(fontSize: 16),
                            decoration: const InputDecoration(
                              hintText: "Add sub-task…",
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onSubmitted: (_) => addSubTask(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: addSubTask,
                          tooltip: "Add",
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close"),
                ),
              ],
            );
          },
        );
      },
    );

    onChanged(task.isDone != originalState);
  }
}
