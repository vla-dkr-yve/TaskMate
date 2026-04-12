import 'package:flutter/material.dart';
import '../models/task.dart';

class TaskDialog {
  static Future<void> show({
    required BuildContext context,
    required Task task,
    required Function(bool isChanged) onChanged,
  }) async {
    bool isChanged = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Text(
                task.title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 36),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Description: ${task.description ?? "NA"}",
                    style: TextStyle(fontSize: 24),
                  ),
                  SizedBox(height: 10),

                  Text(
                    "Start time: ${task.startTime ?? "NA"}",
                    style: TextStyle(fontSize: 24),
                  ),
                  SizedBox(height: 10),

                  Text(
                    "End time: ${task.endTime ?? "NA"}",
                    style: TextStyle(fontSize: 24),
                  ),
                  SizedBox(height: 10),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        "Is done?",
                        style: TextStyle(fontSize: 24),
                      ),
                      Checkbox(
                        value: task.isDone,
                        onChanged: (value) {
                          isChanged = true;
                          setState(() {
                            task.isDone = value!;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Close"),
                ),
              ],
            );
          },
        );
      },
    );

    onChanged(isChanged);
  }
}