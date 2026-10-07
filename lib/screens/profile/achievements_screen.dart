import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/achievement_catalog.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/achievement_model.dart';
import '../../providers/achievement_provider.dart';
import '../../providers/nutrition_provider.dart';
import '../../providers/progress_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../widgets/achievement_widgets.dart';
import '../../widgets/error_state.dart';
import '../../widgets/progress_card.dart';
import '../../widgets/responsive.dart';

/// Mis logros (`/profile/logros`): conseguidos y pendientes, por categoría,
/// con el avance de cada uno.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  @override
  void initState() {
    super.initState();
    // Carga todas las fuentes para que el avance de cada logro esté al día.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final progress = context.read<ProgressProvider>();
      if (!progress.hasData && !progress.loading) progress.refresh();
      final schedule = context.read<ScheduleProvider>();
      if (!schedule.loaded && !schedule.loading) schedule.load();
      context.read<NutritionProvider>().ensureLoaded();
      context.read<AchievementProvider>().ensureLoaded();
    });
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<ProgressProvider>().refresh(),
      context.read<ScheduleProvider>().load(),
      context.read<NutritionProvider>().load(),
      context.read<AchievementProvider>().load(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final achievements = context.watch<AchievementProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Mis logros')),
      body: !achievements.loaded && achievements.error != null
          ? ErrorState(message: achievements.error!, onRetry: achievements.load)
          : RefreshIndicator(
              onRefresh: _refresh,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= Breakpoints.rail
                      ? 2
                      : 1;
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      MaxWidth(
                        maxWidth: Breakpoints.content,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Summary(achievements: achievements),
                            for (final category
                                in AchievementCategory.values) ...[
                              const SizedBox(height: 18),
                              SectionHeader(title: category.label),
                              _Grid(
                                columns: columns,
                                children: [
                                  for (final definition
                                      in AchievementCatalog.ofCategory(
                                        category,
                                      ))
                                    AchievementTile(
                                      definition: definition,
                                      stats: achievements.stats,
                                      unlockedAt: achievements.unlockedAt(
                                        definition.id,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.achievements});

  final AchievementProvider achievements;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final unlocked = achievements.unlockedCount;
    final total = achievements.total;
    final byTier = {
      for (final tier in AchievementTier.values)
        tier: achievements.unlockedDefinitions
            .where((d) => d.tier == tier)
            .length,
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  size: 34,
                  color: AppColors.amber,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$unlocked de $total logros',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: palette.textPrimary,
                        ),
                      ),
                      Text(
                        'Entrena, planifica y registra tu alimentación '
                        'para desbloquear más.',
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : unlocked / total,
                minHeight: 10,
                color: AppColors.amber,
                backgroundColor: palette.surfaceMuted,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                for (final tier in AchievementTier.values)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 12,
                        color: AchievementColors.of(tier),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${tier.label}: ${byTier[tier]}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Rejilla simple de [columns] columnas con filas de altura propia.
class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (columns <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var row = 0; row < children.length; row += columns) ...[
          if (row > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var col = 0; col < columns; col++) ...[
                  if (col > 0) const SizedBox(width: 10),
                  Expanded(
                    child: row + col < children.length
                        ? children[row + col]
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
