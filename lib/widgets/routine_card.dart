import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../models/routine_model.dart';
import 'custom_button.dart';

class RoutineCard extends StatelessWidget {
  const RoutineCard({
    super.key,
    required this.routine,
    required this.exerciseCount,
    this.exerciseNames = const [],
    this.onStart,
    this.onEdit,
    this.onDelete,
    this.onTap,
  });

  final WorkoutRoutine routine;
  final int exerciseCount;

  /// Nombres de los ejercicios de la rutina, en orden.
  final List<String> exerciseNames;
  final VoidCallback? onStart;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// Abre el detalle de la rutina.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final preview = exerciseNames.take(4).join(' · ');
    final extra = exerciseNames.length - 4;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: palette.primarySoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.fitness_center_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          routine.name,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: palette.textPrimary,
                          ),
                        ),
                        if (routine.description.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            routine.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Opciones',
                    onSelected: (value) {
                      if (value == 'edit') onEdit?.call();
                      if (value == 'delete') onDelete?.call();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Editar'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.error,
                          ),
                          title: Text(
                            'Eliminar',
                            style: TextStyle(color: AppColors.error),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  extra > 0 ? '$preview · +$extra más' : preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: palette.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (routine.goal.isNotEmpty)
                    _Tag(
                      icon: Icons.flag_outlined,
                      label: routine.goal,
                      color: palette.secondary,
                    ),
                  if (routine.days.length > 1)
                    _Tag(
                      icon: Icons.calendar_view_week_rounded,
                      label: '${routine.days.length} días',
                      color: palette.secondary,
                    ),
                  _Tag(
                    icon: Icons.list_alt_rounded,
                    label: exerciseCount == 1
                        ? '1 ejercicio'
                        : '$exerciseCount ejercicios',
                    color: AppColors.primary,
                  ),
                  if (routine.totalSets > 0)
                    _Tag(
                      icon: Icons.format_list_numbered_rounded,
                      label: '${routine.totalSets} series',
                      color: AppColors.violet,
                    ),
                  // Grupos musculares sin repetir (Set) de los ejercicios.
                  for (final group in routine.muscleGroups)
                    _Tag(
                      icon: Icons.accessibility_new_rounded,
                      label: group,
                      color: AppColors.teal,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              CustomButton(
                label: 'Comenzar',
                icon: Icons.play_arrow_rounded,
                onPressed: onStart,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
