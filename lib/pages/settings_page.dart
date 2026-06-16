import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/notification_settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  
  // Keys used across the app to read settings
  static const String keyNotificationMode = NotificationSettings.keyNotificationMode;
  static const String keyMinutesBefore = NotificationSettings.keyMinutesBefore;

  // 'per_hour' = current behaviour, 'per_task' = individual notifications
  String _notificationMode = 'per_hour';

  // Only relevant when mode == 'per_task'
  int _minutesBefore = 15;
  bool _isCustomMinutes = false;
  final TextEditingController _customMinutesController = TextEditingController();

  bool _isSaving = false;
  bool _savedOnce = false;

  final List<int> _presetMinutes = [5, 10, 15, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _customMinutesController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(keyNotificationMode) ?? 'per_hour';
    final minutes = prefs.getInt(keyMinutesBefore) ?? 15;
    final isCustom = !_presetMinutes.contains(minutes);

    setState(() {
      _notificationMode = mode;
      _minutesBefore = minutes;
      _isCustomMinutes = isCustom;
      if (isCustom) {
        _customMinutesController.text = minutes.toString();
      }
    });
  }

  Future<void> _saveSettings() async {
    // Validate custom input
    if (_notificationMode == 'per_task' && _isCustomMinutes) {
      final parsed = int.tryParse(_customMinutesController.text.trim());
      if (parsed == null || parsed <= 0 || parsed > 1440) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid number of minutes (1–1440).'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      _minutesBefore = parsed;
    }

    setState(() => _isSaving = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyNotificationMode, _notificationMode);
    if (_notificationMode == 'per_task') {
      await prefs.setInt(keyMinutesBefore, _minutesBefore);
    }

    await NotificationService.instance.loadTasksAndScheduleNotifications();

    setState(() {
      _isSaving = false;
      _savedOnce = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Notification mode ─────────────────────────────────────────
          _buildSectionLabel('NOTIFICATION MODE'),
          _buildCard(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _notificationMode,
                items: const [
                  DropdownMenuItem(
                    value: 'per_hour',
                    child: Text('One notification per hour'),
                  ),
                  DropdownMenuItem(
                    value: 'per_task',
                    child: Text('One notification per task'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _notificationMode = value;
                    _savedOnce = false;
                  });
                },
              ),
            ),
          ),

          // ── Per-task timing ────────────────────────────────────────────
          if (_notificationMode == 'per_task') ...[
            const SizedBox(height: 24),
            _buildSectionLabel('NOTIFY ME BEFORE THE TASK'),
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _isCustomMinutes
                          ? 'custom'
                          : _minutesBefore.toString(),
                      items: [
                        ..._presetMinutes.map(
                          (m) => DropdownMenuItem(
                            value: m.toString(),
                            child: Text('$m minutes before'),
                          ),
                        ),
                        const DropdownMenuItem(
                          value: 'custom',
                          child: Text('Custom…'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _savedOnce = false;
                          if (value == 'custom') {
                            _isCustomMinutes = true;
                            _customMinutesController.clear();
                          } else {
                            _isCustomMinutes = false;
                            _minutesBefore = int.parse(value);
                          }
                        });
                      },
                    ),
                  ),

                  // Custom minutes text field
                  if (_isCustomMinutes) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customMinutesController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Minutes before task',
                        hintText: 'e.g. 20',
                        suffixText: 'min',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          // ── Save button ────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save settings',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
