import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/validators.dart';
import '../../models/exercise_model.dart';
import '../../providers/progress_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_dropdown.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/responsive.dart';
import '../../services/app_firebase.dart';

class CreateExerciseScreen extends StatefulWidget {
  const CreateExerciseScreen({super.key, this.exercise});

  /// Ejercicio a editar; `null` para crear uno nuevo. Llega desde el router
  /// (antes se leía con `GoRouterState.of` dentro de `initState`, lo que
  /// lanzaba una excepción en modo debug).
  final ExerciseModel? exercise;

  @override
  State<CreateExerciseScreen> createState() => _CreateExerciseScreenState();
}

class _CreateExerciseScreenState extends State<CreateExerciseScreen> {
  final FirestoreService _firestore = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _equipmentController = TextEditingController();

  ExerciseModel? _existing;
  String? _muscleGroup;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.exercise;
    if (existing != null) {
      _existing = existing;
      _nameController.text = existing.name;
      _descriptionController.text = existing.description;
      _equipmentController.text = existing.equipment;
      _muscleGroup = existing.muscleGroup;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _equipmentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uid = AppFirebase.auth.currentUser?.uid;
    if (uid == null) return;
    if (!_formKey.currentState!.validate()) {
      _showMessage('Revisa los campos marcados en rojo.');
      return;
    }

    setState(() => _saving = true);
    try {
      // Se guarda una copia: el original (el de la lista) no se modifica
      // hasta que Firestore confirma el guardado.
      final base =
          _existing ??
          ExerciseModel(
            id: _firestore.newDocId,
            name: _nameController.text.trim(),
            muscleGroup: _muscleGroup ?? AppConstants.muscleGroups.first,
          );
      final exercise = base.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        muscleGroup: _muscleGroup ?? base.muscleGroup,
        equipment: _equipmentController.text.trim(),
      );

      await _firestore.saveExercise(uid, exercise);
      if (!mounted) return;
      await ConfirmationDialog.showInfo(
        context,
        icon: Icons.check_circle_rounded,
        title: _existing == null ? 'Ejercicio creado' : 'Ejercicio actualizado',
        message: '"${exercise.name}" se guardó correctamente.',
      );
      if (!mounted) return;
      context.pop(true);
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'No se pudo guardar el ejercicio. '
        '${ProgressProvider.describeError(error)}',
      );
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
        title: Text(_existing == null ? 'Nuevo ejercicio' : 'Editar ejercicio'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: MaxWidth(
            maxWidth: Breakpoints.form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CustomTextField(
                        controller: _nameController,
                        label: 'Nombre del ejercicio',
                        hint: 'Ej: Press banca',
                        icon: Icons.fitness_center_rounded,
                        validator: (v) => Validators.validateRequired(
                          v,
                          message: 'Ingresa el nombre del ejercicio.',
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomDropdown(
                        items: AppConstants.muscleGroups.toList(),
                        value: _muscleGroup,
                        label: 'Grupo muscular',
                        icon: Icons.accessibility_new_rounded,
                        onChanged: (v) => setState(() => _muscleGroup = v),
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _equipmentController,
                        label: 'Equipamiento (opcional)',
                        hint: 'Ej: Barra, mancuernas, máquina',
                        icon: Icons.sports_gymnastics_outlined,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _descriptionController,
                        label: 'Descripción (opcional)',
                        hint: 'Notas o técnica del ejercicio',
                        icon: Icons.notes_rounded,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                CustomButton(
                  label: _existing == null
                      ? 'Guardar ejercicio'
                      : 'Actualizar ejercicio',
                  icon: Icons.save_outlined,
                  loading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
