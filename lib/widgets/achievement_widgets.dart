import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/achievement_catalog.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/achievement_model.dart';
import '../providers/achievement_provider.dart';

/// Color de cada nivel de logro.
abstract final class AchievementColors {
  static const Color bronze = Color(0xFFC07A3E);
  static const Color silver = Color(0xFF8A94A6);
  static const Color gold = AppColors.amber;

  static Color of(AchievementTier tier) => switch (tier) {
    AchievementTier.bronze => bronze,
    AchievementTier.silver => silver,
    AchievementTier.gold => gold,
  };
}

/// Icono circular del logro: con el color de su nivel si está conseguido y
/// apagado (con candado) si no.
class AchievementBadge extends StatelessWidget {
  const AchievementBadge({
    super.key,
    required this.definition,
    required this.unlocked,
    this.size = 48,
  });

  final AchievementDefinition definition;
  final bool unlocked;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = AchievementColors.of(definition.tier);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked
                  ? color.withValues(alpha: 0.16)
                  : palette.surfaceMuted,
              border: Border.all(
                color: unlocked ? color : palette.border,
                width: 2,
              ),
            ),
            child: Icon(
              definition.icon,
              size: size * 0.5,
              color: unlocked ? color : palette.textSecondary,
            ),
          ),
          if (!unlocked)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.surface,
                ),
                child: Icon(
                  Icons.lock_rounded,
                  size: size * 0.26,
                  color: palette.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Fila de un logro: insignia, título, descripción y, según el estado, la
/// fecha en que se consiguió o el avance hacia la meta.
class AchievementTile extends StatelessWidget {
  const AchievementTile({
    super.key,
    required this.definition,
    required this.stats,
    this.unlockedAt,
  });

  final AchievementDefinition definition;
  final AchievementStats stats;
  final DateTime? unlockedAt;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final unlocked = unlockedAt != null;
    final color = AchievementColors.of(definition.tier);
    final value = definition.currentValue(stats);
    final progress = definition.progressOf(stats);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AchievementBadge(definition: definition, unlocked: unlocked),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          definition.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: unlocked
                                ? palette.textPrimary
                                : palette.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        definition.tier.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10.5,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    definition.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (unlocked)
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Conseguido el '
                            '${Formatters.formatDate(unlockedAt!)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (value == null || progress == null)
                    Text(
                      'Abre ${_sourceName(definition.metric.source)} para '
                      'ver tu avance.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: palette.textSecondary,
                      ),
                    )
                  else
                    // Cifra encima de la barra: "4.060 kg / 1.000.000 kg"
                    // no cabe a su lado en pantallas estrechas.
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${definition.format(value)} / '
                          '${definition.format(definition.target)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 7,
                            color: color,
                            backgroundColor: palette.surfaceMuted,
                          ),
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
  }

  static String _sourceName(AchievementSource source) => switch (source) {
    AchievementSource.training => 'Progreso',
    AchievementSource.schedule => 'el Calendario',
    AchievementSource.nutrition => 'Alimentación',
  };
}

/// Escucha a [AchievementProvider] y muestra un aviso por cada logro nuevo,
/// esté el usuario en la pantalla que esté. Va en el `builder` de
/// `MaterialApp.router`, por encima de toda la navegación: el aviso aparece
/// arriba, por encima incluso de las hojas modales, sin tapar sus botones.
/// Los avisos se encolan y se muestran de uno en uno.
class AchievementAnnouncer extends StatefulWidget {
  const AchievementAnnouncer({super.key, required this.child, this.onOpen});

  final Widget child;

  /// Acción "Ver" del aviso (abre la pantalla de logros).
  final VoidCallback? onOpen;

  /// Tiempo que permanece visible cada aviso.
  static const Duration visibleFor = Duration(seconds: 4);

  @override
  State<AchievementAnnouncer> createState() => _AchievementAnnouncerState();
}

class _AchievementAnnouncerState extends State<AchievementAnnouncer> {
  AchievementProvider? _provider;
  final List<AchievementDefinition> _queue = [];
  AchievementDefinition? _current;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<AchievementProvider>();
    if (identical(provider, _provider)) return;
    _provider?.removeListener(_onChange);
    _provider = provider..addListener(_onChange);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _provider?.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final pending = _provider?.takeAnnouncements() ?? const [];
    if (pending.isEmpty) return;
    _queue.addAll(pending);
    if (_current != null) return;
    // Después del frame: el aviso no interrumpe la construcción en curso.
    WidgetsBinding.instance.addPostFrameCallback((_) => _next());
  }

  /// Muestra el siguiente aviso de la cola (o ninguno si está vacía).
  void _next() {
    if (!mounted) return;
    _timer?.cancel();
    setState(() => _current = _queue.isEmpty ? null : _queue.removeAt(0));
    if (_current != null) {
      _timer = Timer(AchievementAnnouncer.visibleFor, _next);
    }
  }

  void _open() {
    _next();
    widget.onOpen?.call();
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => SlideTransition(
                position: Tween(
                  begin: const Offset(0, -1.2),
                  end: Offset.zero,
                ).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: current == null
                  ? const SizedBox.shrink()
                  : _AchievementToast(
                      key: ValueKey(current.id),
                      definition: current,
                      onOpen: widget.onOpen == null ? null : _open,
                      onClose: _next,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AchievementToast extends StatelessWidget {
  const _AchievementToast({
    super.key,
    required this.definition,
    required this.onClose,
    this.onOpen,
  });

  final AchievementDefinition definition;
  final VoidCallback onClose;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final color = AchievementColors.of(definition.tier);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Dismissible(
            key: ValueKey('dismiss-${definition.id}'),
            direction: DismissDirection.up,
            onDismissed: (_) => onClose(),
            child: Material(
              color: AppColors.navy,
              elevation: 8,
              shadowColor: Colors.black54,
              shape: AppShapes.button,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                child: Row(
                  children: [
                    AchievementBadge(
                      definition: definition,
                      unlocked: true,
                      size: 36,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '¡Logro desbloqueado! ${definition.title}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            definition.tier.label,
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onOpen != null)
                      TextButton(
                        onPressed: onOpen,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.accent,
                          minimumSize: const Size(0, 40),
                        ),
                        child: const Text('Ver'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
