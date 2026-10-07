import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../providers/nutrition_provider.dart';
import 'app_feedback.dart';

/// Agua de hoy frente a la meta diaria, con botones para sumar cantidades
/// rápidas, otra cantidad o deshacer. Escucha a [NutritionProvider] con un
/// `Consumer`, así que se puede colocar en cualquier pantalla.
class WaterTrackerCard extends StatelessWidget {
  const WaterTrackerCard({super.key});

  static const Color color = AppColors.teal;

  Future<void> _add(BuildContext context, int ml) async {
    try {
      await context.read<NutritionProvider>().addWater(ml);
    } catch (_) {
      if (!context.mounted) return;
      showAppMessage(context, 'No se pudo guardar el agua.');
    }
  }

  Future<void> _addCustom(BuildContext context) async {
    final ml = await showDialog<int>(
      context: context,
      builder: (_) => const _WaterAmountDialog(
        title: 'Agregar agua',
        label: 'Cantidad (ml)',
        submitLabel: 'Agregar',
        max: AppConstants.maxWaterGoalMl,
      ),
    );
    if (ml == null || !context.mounted) return;
    await _add(context, ml);
  }

  Future<void> _editGoal(BuildContext context, int current) async {
    final nutrition = context.read<NutritionProvider>();
    final ml = await showDialog<int>(
      context: context,
      builder: (_) => _WaterAmountDialog(
        title: 'Meta diaria de agua',
        label: 'Meta (ml)',
        submitLabel: 'Guardar meta',
        initial: current,
        max: AppConstants.maxWaterGoalMl,
      ),
    );
    if (ml == null) return;
    await nutrition.updateWaterGoal(ml);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NutritionProvider>(
      builder: (context, nutrition, _) {
        final palette = context.palette;
        final water = nutrition.today.waterMl;
        final goal = nutrition.waterGoal;
        final reached = water >= goal;
        final undo = AppConstants.waterPresets.first;

        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 8, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.water_drop_rounded, color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Agua de hoy',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: palette.textPrimary,
                            ),
                          ),
                          Text(
                            'Meta diaria: ${Formatters.formatWater(goal)}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cambiar meta',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _editGoal(context, goal),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          // Flexible: en pantallas estrechas la cantidad se
                          // recorta antes que desbordar junto al aviso.
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: Formatters.formatWater(water),
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: palette.textPrimary,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '  / ${Formatters.formatWater(goal)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: palette.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (reached)
                            const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 18,
                                  color: AppColors.success,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Meta cumplida',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: NutritionProvider.progress(
                            water.toDouble(),
                            goal.toDouble(),
                          ),
                          minHeight: 10,
                          color: reached ? AppColors.success : color,
                          backgroundColor: palette.surfaceMuted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Tamaño compacto: el tema da ancho mínimo infinito
                          // a los botones y aquí van varios en fila.
                          for (final ml in AppConstants.waterPresets)
                            FilledButton.tonalIcon(
                              onPressed: () => _add(context, ml),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 44),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: Text(Formatters.formatWater(ml)),
                            ),
                          OutlinedButton(
                            onPressed: () => _addCustom(context),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 44),
                            ),
                            child: const Text('Otra cantidad'),
                          ),
                          IconButton(
                            tooltip: 'Quitar ${Formatters.formatWater(undo)}',
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: water <= 0
                                ? null
                                : () => _add(context, -undo),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Pide una cantidad de agua en ml (entre 1 y [max]).
class _WaterAmountDialog extends StatefulWidget {
  const _WaterAmountDialog({
    required this.title,
    required this.label,
    required this.submitLabel,
    required this.max,
    this.initial,
  });

  final String title;
  final String label;
  final String submitLabel;
  final int max;
  final int? initial;

  @override
  State<_WaterAmountDialog> createState() => _WaterAmountDialogState();
}

class _WaterAmountDialogState extends State<_WaterAmountDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial == null ? '' : '${widget.initial}',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final ml = int.tryParse(_controller.text.trim());
    if (ml == null || ml <= 0 || ml > widget.max) {
      setState(
        () => _error =
            'Ingresa entre 1 y ${Formatters.formatNumber(widget.max)} ml.',
      );
      return;
    }
    Navigator.of(context).pop(ml);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: widget.label,
              prefixIcon: const Icon(Icons.water_drop_outlined),
              suffixText: 'ml',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: Text(widget.submitLabel)),
      ],
    );
  }
}
