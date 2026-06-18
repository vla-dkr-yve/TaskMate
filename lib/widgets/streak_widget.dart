import 'package:flutter/material.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import '../services/database_service.dart';

// Displays current streak (days) and 30-day productivity score.
// Fully self-contained - fetches its own data on mount.
// Call StreakWidget(key: UniqueKey()) to force a refresh.
class StreakWidget extends StatefulWidget {
  const StreakWidget({super.key});

  @override
  State<StreakWidget> createState() => _StreakWidgetState();
}

class _StreakWidgetState extends State<StreakWidget> {
  final _db = DatabaseService.instance;

  int _streak = 0;
  double _score = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final streak = await _db.getCurrentStreak();
    final score = await _db.getProductivityScore();
    if (mounted) {
      setState(() {
        _streak = streak;
        _score = score;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _StatCard(
            icon: Icons.local_fire_department,
            iconColor: _streak > 0 ? Colors.deepOrange : Colors.grey,
            value: '$_streak',
            label: _streak == 1 ? 'day streak' : 'days streak',
          ),
          const SizedBox(width: 12),
          _StatCard(
            icon: Icons.bar_chart_rounded,
            iconColor: _scoreColor(_score),
            value: '${_score.toInt()}%',
            label: '30-day score',
          ),
        ],
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 75) return Colors.green[700]!;
    if (score >= 40) return Colors.orange[700]!;
    return Colors.red[400]!;
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: AppTheme.text(context),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
