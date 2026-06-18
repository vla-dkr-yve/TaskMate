import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/sub_task.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class TaskDialog {
  static Future<void> show({
    required BuildContext context,
    required Task task,
    required DateTime selectedDate,
    required Function(bool isChanged) onChanged,
  }) async {
    final bool originalState = task.isDone;
    final db = DatabaseService.instance;

    final int taskId = await db.getTaskIdFromOccuranceId(task.occuranceId);
    List<SubTask> subTasks = await db.getSubTasksForOccurance(task.occuranceId, selectedDate);

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final TextEditingController newSubTaskController = TextEditingController();
          final isArchived = task.deletedAt != null;
          final accent = AppTheme.taskAccent(isDone: task.isDone, isArchived: isArchived);

          Future<void> addSubTask() async {
            final title = newSubTaskController.text.trim();
            if (title.isEmpty) return;
            await db.createSubTask(taskId, title);
            final updated = await db.getSubTasksForOccurance(task.occuranceId, selectedDate);
            setState(() { subTasks = updated; newSubTaskController.clear(); });
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

          return Dialog(
            backgroundColor: AppTheme.surface(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 4,
                        height: 48,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.text(context),
                                letterSpacing: -0.3,
                                height: 1.2,
                              ),
                            ),
                            if (isArchived)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('Archived',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.statusArchived,
                                        fontWeight: FontWeight.w600)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Info rows
                  if (task.description != null && task.description!.isNotEmpty)
                    _InfoRow(
                      icon: Icons.notes_rounded,
                      value: task.description!,
                    ),
                  if (task.startTime != null)
                    _InfoRow(
                      icon: Icons.access_time_rounded,
                      value: task.endTime != null
                          ? '${task.startTime!} – ${task.endTime!}'
                          : task.startTime!,
                    ),

                  const SizedBox(height: 16),

                  // Done toggle
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface2(context),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Mark as done',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.text(context),
                            )),
                        Checkbox(
                          value: task.isDone,
                          activeColor: AppTheme.statusDone,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: isArchived
                              ? null
                              : (value) => setState(() => task.isDone = value!),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Sub-tasks
                  Row(
                    children: [
                      Text('Sub-tasks',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSec(context),
                            letterSpacing: 0.4,
                          )),
                      const Spacer(),
                      if (subTasks.isNotEmpty)
                        Text(
                          '${subTasks.where((s) => s.isDone).length}/${subTasks.length}',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSec(context)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (subTasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('No sub-tasks yet.',
                          style: TextStyle(fontSize: 14, color: AppTheme.textSec(context))),
                    ),

                  ...subTasks.map((subTask) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: Checkbox(
                            value: subTask.isDone,
                            activeColor: AppTheme.statusDone,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            onChanged: (_) => toggleSubTask(subTask),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            subTask.title,
                            style: TextStyle(
                              fontSize: 15,
                              color: subTask.isDone
                                  ? AppTheme.textSec(context)
                                  : AppTheme.text(context),
                              decoration: subTask.isDone ? TextDecoration.lineThrough : null,
                              decorationColor: AppTheme.textSec(context),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, size: 16,
                              color: AppTheme.textSec(context)),
                          onPressed: () => removeSubTask(subTask),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ],
                    ),
                  )),

                  // Add sub-task row
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: newSubTaskController,
                          style: TextStyle(fontSize: 15, color: AppTheme.text(context)),
                          decoration: InputDecoration(
                            hintText: 'Add sub-task…',
                            hintStyle: TextStyle(color: AppTheme.textSec(context), fontSize: 14),
                            isDense: true,
                            filled: true,
                            fillColor: AppTheme.surface2(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onSubmitted: (_) => addSubTask(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: addSubTask,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.text(context),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.add, size: 20, color: AppTheme.surface(context)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        backgroundColor: AppTheme.surface2(context),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Close',
                          style: TextStyle(
                            color: AppTheme.text(context),
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          )),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    onChanged(task.isDone != originalState);
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String value;

  const _InfoRow({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.textSec(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(value,
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.text(context),
                  height: 1.4,
                )),
          ),
        ],
      ),
    );
  }
}
