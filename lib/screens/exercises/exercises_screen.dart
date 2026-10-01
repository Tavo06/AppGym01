import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/exercise_model.dart';
import '../../providers/progress_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/exercise_history_sheet.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/responsive.dart';
import '../../services/app_firebase.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  final FirestoreService _firestore = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  List<ExerciseModel> _exercises = [];
  bool _loading = true;
  String? _error;
  String? _filter;
  String? _uid;
  bool _visible = true;
  Future<void>? _inFlight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      // El uso de cada ejercicio sale del historial del usuario.
      if (!mounted) return;
      final progress = context.read<ProgressProvider>();
      if (!progress.hasData && !progress.loading) progress.refresh();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Al volver a la pestaña se recarga: pudieron crearse ejercicios desde
    // Rutinas o desde el entrenamiento libre.
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_visible) _load();
    _visible = visible;
  }

  /// Evita lecturas duplicadas si se pide recargar mientras ya se carga.
  Future<void> _load() =>
      _inFlight ??= _fetch().whenComplete(() => _inFlight = null);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final uid = AppFirebase.auth.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _uid = uid;
    });
    try {
      final exercises = await _firestore.getExercises(uid);
      if (!mounted) return;
      setState(() => _exercises = exercises);
    } catch (error) {
      // Un fallo de red no debe mostrarse como "no tienes ejercicios".
      if (!mounted) return;
      setState(() => _error = ProgressProvider.describeError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ExerciseModel> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    return _exercises.where((e) {
      if (_filter != null && e.muscleGroup != _filter) return false;
      if (query.isEmpty) return true;
      return e.name.toLowerCase().contains(query) ||
          e.equipment.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openCreate() async {
    await context.push('/ejercicio/crear');
    if (!mounted) return;
    await _load();
  }

  Future<void> _openEdit(ExerciseModel exercise) async {
    await context.push('/ejercicio/crear', extra: exercise);
    if (!mounted) return;
    await _load();
  }

  Future<void> _delete(ExerciseModel exercise) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      icon: Icons.delete_outline_rounded,
      title: '¿Eliminar ejercicio?',
      message:
          'Se eliminará "${exercise.name}". También se quitará de tus '
          'rutinas. Tu historial de entrenamientos se conserva. Esta acción '
          'no se puede deshacer.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (confirmed != true || _uid == null) return;
    try {
      await _firestore.deleteExercise(_uid!, exercise.id);
      if (!mounted) return;
      setState(() => _exercises.removeWhere((e) => e.id == exercise.id));
      showAppMessage(
        context,
        'Ejercicio eliminado.',
        type: FeedbackType.success,
      );
    } catch (error) {
      if (!mounted) return;
      showAppMessage(
        context,
        'No se pudo eliminar el ejercicio. '
        '${ProgressProvider.describeError(error)}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis ejercicios'),
        actions: [
          IconButton(
            tooltip: 'Nuevo ejercicio',
            onPressed: _openCreate,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: _exercises.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _openCreate,
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nuevo'),
            ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _exercises.isEmpty) {
      return const LoadingWidget(message: 'Cargando ejercicios...');
    }
    if (_error != null && _exercises.isEmpty) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    if (_exercises.isEmpty) {
      return EmptyState(
        icon: Icons.fitness_center_rounded,
        title: 'Todavía no tienes ejercicios',
        subtitle:
            'Crea ejercicios y agrúpalos por grupo muscular para '
            'armar tus rutinas.',
        actionLabel: 'Crear ejercicio',
        onAction: _openCreate,
      );
    }

    final filtered = _filtered;
    return MaxWidth(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o equipamiento',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar búsqueda',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () =>
                            setState(() => _searchController.clear()),
                      ),
              ),
            ),
          ),
          _buildFilters(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: filtered.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 60),
                        EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'Sin resultados',
                          subtitle:
                              'Prueba con otra búsqueda o grupo '
                              'muscular.',
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _buildExerciseCard(filtered[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    Widget chip(String label, String? value) {
      final selected = _filter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => setState(() => _filter = value),
          labelStyle: TextStyle(
            color: selected ? AppColors.onPrimary : context.palette.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          chip('Todos', null),
          for (final group in _availableGroups)
            chip('$group (${_countByGroup(group)})', group),
        ],
      ),
    );
  }

  /// Grupos musculares que tienen al menos un ejercicio, sin repetir.
  /// Primero los del catálogo (en su orden) y después cualquier grupo que no
  /// esté en él (por ejemplo, de datos antiguos).
  Set<String> get _availableGroups {
    final used = _exercises.map((e) => e.muscleGroup).toSet();
    return {
      ...AppConstants.muscleGroups.intersection(used),
      ...used.difference(AppConstants.muscleGroups),
    };
  }

  int _countByGroup(String group) =>
      _exercises.where((e) => e.muscleGroup == group).length;

  Widget _buildExerciseCard(ExerciseModel exercise) {
    final palette = context.palette;
    // Uso real del ejercicio en el historial del usuario.
    final stats = context
        .watch<ProgressProvider>()
        .progressByExercise[exercise.id];
    final usage = stats == null
        ? 'Aún sin registros'
        : [
            if (stats.bestWeight > 0)
              'Mejor ${Formatters.formatWeight(stats.bestWeight)} kg × '
                  '${stats.bestReps}',
            if (stats.latestWeight > 0)
              'Último ${Formatters.formatWeight(stats.latestWeight)} kg',
            '${stats.totalSets} series',
            '${stats.workoutCount} '
                '${stats.workoutCount == 1 ? 'sesión' : 'sesiones'}',
          ].join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => _openEdit(exercise),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: palette.primarySoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.fitness_center_rounded,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        title: Text(
          exercise.name,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise.muscleGroup +
                  (exercise.equipment.isNotEmpty
                      ? ' · ${exercise.equipment}'
                      : ''),
              style: TextStyle(fontSize: 13, color: palette.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              usage,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: stats == null
                    ? palette.textSecondary
                    : AppColors.primary,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'Opciones',
          onSelected: (value) {
            if (value == 'history') {
              showExerciseHistorySheet(context, exercise);
            }
            if (value == 'edit') _openEdit(exercise);
            if (value == 'delete') _delete(exercise);
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'history',
              child: ListTile(
                leading: Icon(Icons.history_rounded),
                title: Text('Ver historial'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
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
      ),
    );
  }
}
