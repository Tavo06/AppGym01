import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/goal_model.dart';
import '../providers/progress_provider.dart';

/// Metas de la semana. Escucha a [ProgressProvider] con un `Consumer`: al
/// guardar un entrenamiento, `agregarSesion()` llama a `notifyListeners()` y
/// esta tarjeta se reconstruye con el nuevo avance.
class WeeklyGoalsCard extends StatelessWidget {
  const WeeklyGoalsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ProgressProvider>(
      builder: (context, progress, _) {
        final goals = progress.weeklyGoals;
        final reached = progress.goalsReached;
        final palette = context.palette;

        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 8, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Metas semanales',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$reached de ${goals.length} metas cumplidas '
                            'esta semana',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Editar metas',
                      icon: const Icon(Icons.tune_rounded),
                      onPressed: () => _editGoals(context, progress),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final goal in goals)
                  Padding(
                    padding: const EdgeInsets.only(right: 10, top: 10),
                    child: _GoalRow(goal: goal),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editGoals(
    BuildContext context,
    ProgressProvider progress,
  ) async {
    final result = await showDialog<({double volume, int sets, int workouts})>(
      context: context,
      builder: (_) => _EditGoalsDialog(
        volume: progress.volumeGoal,
        sets: progress.setsGoal,
        workouts: progress.workoutsGoal,
      ),
    );
    if (result == null) return;
    await progress.updateGoals(
      volume: result.volume,
      sets: result.sets,
      workouts: result.workouts,
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal});

  final WeeklyGoal goal;

  String _format(double value) => goal.unit == 'kg'
      ? Formatters.formatVolume(value)
      : Formatters.formatNumber(value);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final Color color;
    final IconData icon;
    if (goal.status == GoalStatus.reached) {
      color = AppColors.success;
      icon = Icons.check_circle_rounded;
    } else if (goal.status == GoalStatus.onTrack) {
      color = AppColors.amber;
      icon = Icons.trending_up_rounded;
    } else {
      color = AppColors.error;
      icon = Icons.pending_outlined;
    }
    final detail = goal.isReached
        ? '${_format(goal.current)} de ${_format(goal.target)} · '
              '${goal.percent} %'
        : '${_format(goal.current)} de ${_format(goal.target)} · '
              'faltan ${_format(goal.remaining)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                goal.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
            ),
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              goal.statusLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: goal.ratio,
            minHeight: 8,
            color: color,
            backgroundColor: palette.surfaceMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          detail,
          style: TextStyle(fontSize: 12, color: palette.textSecondary),
        ),
      ],
    );
  }
}

class _EditGoalsDialog extends StatefulWidget {
  const _EditGoalsDialog({
    required this.volume,
    required this.sets,
    required this.workouts,
  });

  final double volume;
  final int sets;
  final int workouts;

  @override
  State<_EditGoalsDialog> createState() => _EditGoalsDialogState();
}

class _EditGoalsDialogState extends State<_EditGoalsDialog> {
  late final TextEditingController _volume = TextEditingController(
    text: Formatters.formatWeight(widget.volume).replaceAll('.', ''),
  );
  late final TextEditingController _sets = TextEditingController(
    text: '${widget.sets}',
  );
  late final TextEditingController _workouts = TextEditingController(
    text: '${widget.workouts}',
  );
  String? _error;

  @override
  void dispose() {
    _volume.dispose();
    _sets.dispose();
    _workouts.dispose();
    super.dispose();
  }

  void _save() {
    final volume = double.tryParse(
      _volume.text.trim().replaceAll('.', '').replaceAll(',', '.'),
    );
    final sets = int.tryParse(_sets.text.trim());
    final workouts = int.tryParse(_workouts.text.trim());
    if (volume == null || volume <= 0 || sets == null || sets <= 0) {
      setState(() => _error = 'Las metas deben ser mayores que cero.');
      return;
    }
    if (workouts == null || workouts <= 0 || workouts > 14) {
      setState(() => _error = 'Elige entre 1 y 14 entrenamientos.');
      return;
    }
    Navigator.of(context).pop((volume: volume, sets: sets, workouts: workouts));
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool decimal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            RegExp(decimal ? r'[0-9.,]' : r'[0-9]'),
          ),
        ],
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Metas semanales'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(_volume, 'Volumen (kg)', Icons.scale_rounded, decimal: true),
            _field(_sets, 'Series', Icons.format_list_numbered_rounded),
            _field(_workouts, 'Entrenamientos', Icons.fitness_center_rounded),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar metas')),
      ],
    );
  }
}
