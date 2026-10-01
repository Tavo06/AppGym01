import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/exercise_model.dart';
import '../../models/routine_day_model.dart';
import '../../models/routine_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_dropdown.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/responsive.dart';
import '../../providers/progress_provider.dart';
import '../../widgets/loading_widget.dart';
import '../../services/app_firebase.dart';

/// Editor de rutinas: datos generales y días, cada uno con sus ejercicios y
/// su plan (series, repeticiones, peso, descanso y notas).
class CreateRoutineScreen extends StatefulWidget {
  const CreateRoutineScreen({super.key, this.routine});

  /// Rutina a editar; `null` para crear una nueva. Llega desde el router
  /// (antes se leía con `GoRouterState.of` dentro de `initState`, lo que
  /// lanzaba una excepción en modo debug).
  final WorkoutRoutine? routine;

  @override
  State<CreateRoutineScreen> createState() => _CreateRoutineScreenState();
}

class _CreateRoutineScreenState extends State<CreateRoutineScreen> {
  final FirestoreService _firestore = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  WorkoutRoutine? _existing;
  List<ExerciseModel> _exercises = [];

  /// Días en edición (estado local hasta guardar).
  List<RoutineDay> _days = [];
  int _selectedDay = 0;
  String? _goal;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    final existing = widget.routine;
    if (existing != null) {
      _existing = existing;
      _nameController.text = existing.name;
      _descriptionController.text = existing.description;
      _goal = AppConstants.goals.contains(existing.goal) ? existing.goal : null;
      _days = List.of(existing.days);
    }
    if (_days.isEmpty) _days = [_newDay(1)];
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  RoutineDay _newDay(int number) => RoutineDay(
    id: 'dia-${DateTime.now().microsecondsSinceEpoch}',
    name: 'Día $number',
  );

  RoutineDay get _day => _days[_selectedDay];

  Future<void> _load() async {
    final uid = AppFirebase.auth.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final exercises = await _firestore.getExercises(uid);
      if (!mounted) return;
      setState(() => _exercises = exercises);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = ProgressProvider.describeError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  ExerciseModel? _exerciseById(String id) {
    for (final exercise in _exercises) {
      if (exercise.id == id) return exercise;
    }
    return null;
  }

  // ---------------------------------------------------------------- días

  void _updateDay(RoutineDay day) => setState(() => _days[_selectedDay] = day);

  void _addDay() {
    setState(() {
      _days.add(_newDay(_days.length + 1));
      _selectedDay = _days.length - 1;
    });
  }

  void _duplicateDay() {
    final copy = RoutineDay(
      id: 'dia-${DateTime.now().microsecondsSinceEpoch}',
      name: '${_day.name} (copia)',
      exercises: _day.exercises,
    );
    setState(() {
      _days.insert(_selectedDay + 1, copy);
      _selectedDay++;
    });
  }

  void _moveDay(int delta) {
    final target = _selectedDay + delta;
    if (target < 0 || target >= _days.length) return;
    setState(() {
      final day = _days.removeAt(_selectedDay);
      _days.insert(target, day);
      _selectedDay = target;
    });
  }

  Future<void> _renameDay() async {
    final controller = TextEditingController(text: _day.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nombre del día'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            hintText: 'Ej: Pierna, Empuje, Día 1',
          ),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || !mounted) return;
    _updateDay(_day.copyWith(name: trimmed));
  }

  Future<void> _deleteDay() async {
    if (_days.length == 1) {
      _showMessage('La rutina necesita al menos un día.');
      return;
    }
    final confirmed = await ConfirmationDialog.show(
      context,
      icon: Icons.delete_outline_rounded,
      title: '¿Eliminar "${_day.name}"?',
      message: 'Se quitarán sus ejercicios de la rutina.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _days.removeAt(_selectedDay);
      if (_selectedDay >= _days.length) _selectedDay = _days.length - 1;
    });
  }

  // ----------------------------------------------------------- ejercicios

  Future<void> _addExercises() async {
    final current = _day.exerciseIds.toSet();
    final chosen = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ExercisePicker(
        exercises: _exercises,
        alreadyAdded: current,
        onCreateExercise: () async {
          await context.push('/ejercicio/crear');
          await _load();
        },
      ),
    );
    if (chosen == null || chosen.isEmpty || !mounted) return;
    _updateDay(
      _day.copyWith(
        exercises: [
          ..._day.exercises,
          for (final id in chosen)
            if (!current.contains(id)) RoutineExercise(exerciseId: id),
        ],
      ),
    );
  }

  void _updateExercise(int index, RoutineExercise exercise) {
    final list = List.of(_day.exercises)..[index] = exercise;
    _updateDay(_day.copyWith(exercises: list));
  }

  void _removeExercise(int index) {
    final list = List.of(_day.exercises)..removeAt(index);
    _updateDay(_day.copyWith(exercises: list));
  }

  void _reorderExercise(int oldIndex, int newIndex) {
    final list = List.of(_day.exercises);
    list.insert(newIndex, list.removeAt(oldIndex));
    _updateDay(_day.copyWith(exercises: list));
  }

  // -------------------------------------------------------------- guardar

  Future<void> _save() async {
    final uid = AppFirebase.auth.currentUser?.uid;
    if (uid == null) return;
    if (!_formKey.currentState!.validate()) return;

    // Solo ejercicios que siguen existiendo, en el orden elegido.
    final validIds = _exercises.map((e) => e.id).toSet();
    final days = [
      for (final day in _days)
        day.copyWith(
          exercises: [
            for (final e in day.exercises)
              if (validIds.contains(e.exerciseId)) e,
          ],
        ),
    ];
    if (days.every((d) => d.exercises.isEmpty)) {
      _showMessage('Selecciona al menos un ejercicio.');
      return;
    }
    for (var i = 0; i < days.length; i++) {
      if (days[i].exercises.isEmpty) {
        setState(() => _selectedDay = i);
        _showMessage('"${days[i].name}" no tiene ejercicios.');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      // Se guarda una copia: el objeto original (el de la lista de rutinas)
      // no se modifica hasta que Firestore confirma el guardado.
      final base =
          _existing ??
          WorkoutRoutine(
            id: _firestore.newDocId,
            userId: uid,
            name: _nameController.text.trim(),
          );
      final routine = base.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        goal: _goal ?? '',
        days: days,
      );
      await _firestore.saveRoutine(uid, routine);
      if (!mounted) return;
      await ConfirmationDialog.showInfo(
        context,
        icon: Icons.check_circle_rounded,
        title: _existing == null ? 'Rutina creada' : 'Rutina actualizada',
        message: '"${routine.name}" se guardó correctamente.',
      );
      if (!mounted) return;
      context.pop(true);
    } catch (_) {
      if (!mounted) return;
      _showMessage('No se pudo guardar la rutina. Intenta nuevamente.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    showAppMessage(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_existing == null ? 'Crear rutina' : 'Editar rutina'),
      ),
      body: _loading
          ? const LoadingWidget(message: 'Cargando ejercicios...')
          : _loadError != null
          ? ErrorState(message: _loadError!, onRetry: _load)
          : _exercises.isEmpty
          ? EmptyState(
              icon: Icons.fitness_center_rounded,
              title: 'Primero crea ejercicios',
              subtitle:
                  'Necesitas al menos un ejercicio para armar una rutina.',
              actionLabel: 'Crear ejercicio',
              onAction: () async {
                await context.push('/ejercicio/crear');
                if (mounted) await _load();
              },
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 900) return _buildWide();
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  child: MaxWidth(
                    maxWidth: Breakpoints.form + 120,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildDetailsForm(),
                        const SizedBox(height: 24),
                        _buildDaysHeader(),
                        const SizedBox(height: 16),
                        _buildDayEditor(),
                        const SizedBox(height: 28),
                        _buildSaveButton(),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  /// Escritorio/tablet: datos y días a la izquierda, ejercicios a la
  /// derecha.
  Widget _buildWide() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1240),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 380,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 12, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDetailsForm(),
                    const SizedBox(height: 24),
                    _buildDaysHeader(vertical: true),
                    const SizedBox(height: 24),
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
            VerticalDivider(width: 1, color: context.palette.border),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 24, 24),
                child: _buildDayEditor(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomTextField(
            controller: _nameController,
            label: 'Nombre de la rutina',
            hint: 'Ej: Pecho y Tríceps',
            icon: Icons.fitness_center_rounded,
            validator: (v) => Validators.validateRequired(
              v,
              message: 'Ingresa el nombre de la rutina.',
            ),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _descriptionController,
            label: 'Descripción (opcional)',
            hint: '¿Para qué sirve esta rutina?',
            icon: Icons.notes_rounded,
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          CustomDropdown(
            items: AppConstants.goals.toList(),
            value: _goal,
            label: 'Objetivo (opcional)',
            icon: Icons.flag_outlined,
            onChanged: (v) => setState(() => _goal = v),
            validator: (_) => null,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: context.palette.textPrimary,
    ),
  );

  /// Selector de días: chips en móvil, lista vertical en escritorio.
  Widget _buildDaysHeader({bool vertical = false}) {
    final palette = context.palette;
    Widget dayChip(int index) {
      final day = _days[index];
      final selected = index == _selectedDay;
      return ChoiceChip(
        label: Text('${day.name} · ${day.exercises.length}'),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => setState(() => _selectedDay = index),
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: selected ? AppColors.onPrimary : palette.textPrimary,
        ),
      );
    }

    final addButton = ActionChip(
      avatar: const Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
      label: const Text('Añadir día'),
      onPressed: _addDay,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Días de la rutina'),
        const SizedBox(height: 4),
        Text(
          'Organiza tu rutina por días y define el plan de cada ejercicio.',
          style: TextStyle(fontSize: 13, color: palette.textSecondary),
        ),
        const SizedBox(height: 12),
        if (vertical)
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < _days.length; i++)
                  ListTile(
                    selected: i == _selectedDay,
                    selectedTileColor: palette.primarySoft,
                    selectedColor: AppColors.primary,
                    leading: CircleAvatar(
                      radius: 15,
                      backgroundColor: i == _selectedDay
                          ? AppColors.primary
                          : palette.surfaceMuted,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: i == _selectedDay
                              ? AppColors.onPrimary
                              : palette.textPrimary,
                        ),
                      ),
                    ),
                    title: Text(
                      _days[i].name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${_days[i].exercises.length} ejercicios · '
                      '${_days[i].totalSets} series',
                    ),
                    onTap: () => setState(() => _selectedDay = i),
                  ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: addButton,
                  ),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _days.length; i++) dayChip(i),
              addButton,
            ],
          ),
      ],
    );
  }

  Widget _buildDayEditor() {
    final palette = context.palette;
    final day = _day;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle(day.name)),
            PopupMenuButton<String>(
              tooltip: 'Opciones del día',
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (value) {
                switch (value) {
                  case 'rename':
                    _renameDay();
                  case 'duplicate':
                    _duplicateDay();
                  case 'left':
                    _moveDay(-1);
                  case 'right':
                    _moveDay(1);
                  case 'delete':
                    _deleteDay();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'rename',
                  child: Text('Cambiar nombre'),
                ),
                const PopupMenuItem(
                  value: 'duplicate',
                  child: Text('Duplicar día'),
                ),
                if (_selectedDay > 0)
                  const PopupMenuItem(
                    value: 'left',
                    child: Text('Mover antes'),
                  ),
                if (_selectedDay < _days.length - 1)
                  const PopupMenuItem(
                    value: 'right',
                    child: Text('Mover después'),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Eliminar día',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ],
        ),
        Text(
          day.exercises.isEmpty
              ? 'Añade los ejercicios de este día.'
              : '${day.exercises.length} ejercicios · ${day.totalSets} '
                    'series planificadas · arrastra para reordenar',
          style: TextStyle(fontSize: 13, color: palette.textSecondary),
        ),
        const SizedBox(height: 12),
        ReorderableListView.builder(
          key: ValueKey('day-${day.id}'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: day.exercises.length,
          onReorderItem: _reorderExercise,
          itemBuilder: (context, index) {
            final plan = day.exercises[index];
            return Padding(
              key: ValueKey('${day.id}-${plan.exerciseId}'),
              padding: const EdgeInsets.only(bottom: 12),
              child: _PlanExerciseCard(
                index: index,
                plan: plan,
                exercise: _exerciseById(plan.exerciseId),
                onChanged: (updated) => _updateExercise(index, updated),
                onRemove: () => _removeExercise(index),
              ),
            );
          },
        ),
        OutlinedButton.icon(
          onPressed: _addExercises,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Añadir ejercicios'),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return CustomButton(
      label: _existing == null ? 'Guardar rutina' : 'Actualizar rutina',
      icon: Icons.save_outlined,
      loading: _saving,
      onPressed: _save,
    );
  }
}

/// Tarjeta con el plan de un ejercicio dentro de un día.
class _PlanExerciseCard extends StatelessWidget {
  const _PlanExerciseCard({
    required this.index,
    required this.plan,
    required this.exercise,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final RoutineExercise plan;
  final ExerciseModel? exercise;
  final ValueChanged<RoutineExercise> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final id = plan.exerciseId;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      color: palette.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise?.name ?? 'Ejercicio eliminado',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: exercise == null
                              ? AppColors.error
                              : palette.textPrimary,
                        ),
                      ),
                      Text(
                        [
                          if (exercise != null) exercise!.muscleGroup,
                          if (plan.weight > 0)
                            'Volumen ${Formatters.formatVolume(plan.plannedVolume)}',
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Quitar ejercicio',
                  onPressed: onRemove,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _NumberField(
                    key: ValueKey('$id-sets'),
                    label: 'Series',
                    value: '${plan.sets}',
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n > 0) {
                        onChanged(plan.copyWith(sets: n));
                      }
                    },
                  ),
                  _NumberField(
                    key: ValueKey('$id-reps'),
                    label: 'Reps',
                    value: '${plan.reps}',
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n > 0) {
                        onChanged(plan.copyWith(reps: n));
                      }
                    },
                  ),
                  _NumberField(
                    key: ValueKey('$id-weight'),
                    label: 'Peso (kg)',
                    value: plan.weight == 0
                        ? ''
                        : Formatters.formatWeight(plan.weight),
                    decimal: true,
                    onChanged: (v) {
                      final n = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                      onChanged(plan.copyWith(weight: n < 0 ? 0 : n));
                    },
                  ),
                  _NumberField(
                    key: ValueKey('$id-rest'),
                    label: 'Descanso (s)',
                    value: '${plan.restSeconds}',
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n >= 0) {
                        onChanged(plan.copyWith(restSeconds: n));
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextFormField(
                key: ValueKey('$id-notes'),
                initialValue: plan.notes,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (v) => onChanged(plan.copyWith(notes: v.trim())),
                decoration: const InputDecoration(
                  labelText: 'Añadir una nota',
                  prefixIcon: Icon(Icons.sticky_note_2_outlined),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.decimal = false,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: TextFormField(
        initialValue: value,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            RegExp(decimal ? r'[0-9.,]' : r'[0-9]'),
          ),
        ],
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, isDense: true),
      ),
    );
  }
}

/// Hoja para elegir ejercicios del catálogo del usuario.
class _ExercisePicker extends StatefulWidget {
  const _ExercisePicker({
    required this.exercises,
    required this.alreadyAdded,
    required this.onCreateExercise,
  });

  final List<ExerciseModel> exercises;
  final Set<String> alreadyAdded;
  final Future<void> Function() onCreateExercise;

  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  final Set<String> _selected = {};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final query = _query.trim().toLowerCase();
    final visible = [
      for (final e in widget.exercises)
        if (query.isEmpty ||
            e.name.toLowerCase().contains(query) ||
            e.muscleGroup.toLowerCase().contains(query))
          e,
    ];
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Añadir ejercicios',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await widget.onCreateExercise();
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Crear ejercicio'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Buscar por nombre o grupo muscular',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final e in visible)
                    CheckboxListTile(
                      value:
                          widget.alreadyAdded.contains(e.id) ||
                          _selected.contains(e.id),
                      onChanged: widget.alreadyAdded.contains(e.id)
                          ? null
                          : (checked) => setState(() {
                              if (checked == true) {
                                _selected.add(e.id);
                              } else {
                                _selected.remove(e.id);
                              }
                            }),
                      title: Text(e.name),
                      subtitle: Text(
                        widget.alreadyAdded.contains(e.id)
                            ? '${e.muscleGroup} · ya está en este día'
                            : e.muscleGroup,
                      ),
                      activeColor: AppColors.primary,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: CustomButton(
                label: _selected.isEmpty
                    ? 'Selecciona ejercicios'
                    : 'Añadir ${_selected.length}',
                icon: Icons.check_rounded,
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.of(context).pop([
                        // En el orden del catálogo.
                        for (final e in widget.exercises)
                          if (_selected.contains(e.id)) e.id,
                      ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
