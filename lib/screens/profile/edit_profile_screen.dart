import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_dropdown.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/responsive.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const String _noneLabel = 'Sin especificar';

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  /// La fecha se muestra como texto real del campo (no como `hint`, que se
  /// ocultaba al perder el foco). El valor real vive en `_birthDate`.
  final _birthDateController = TextEditingController();

  DateTime? _birthDate;
  String? _goal;
  String? _level;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    final profile = authProvider.profile;
    _nameController = TextEditingController(
      text: profile?.name ?? authProvider.displayName,
    );
    _setBirthDate(DateTime.tryParse(profile?.birthDate ?? ''));
    // Solo se aceptan valores de la lista: uno desconocido se trata como
    // "sin especificar" en vez de dejar el desplegable en un estado inválido.
    _goal = AppConstants.goals.contains(profile?.goal) ? profile?.goal : null;
    _level = AppConstants.levels.contains(profile?.level)
        ? profile?.level
        : null;
  }

  /// Todas las opciones más "Sin especificar", para poder borrar el valor.
  /// Antes se excluía el valor seleccionado de la lista, por lo que el
  /// desplegable no mostraba lo guardado y fallaba al elegir otra opción.
  List<String> get _goalItems => [_noneLabel, ...AppConstants.goals];
  List<String> get _levelItems => [_noneLabel, ...AppConstants.levels];

  void _setBirthDate(DateTime? date) {
    _birthDate = date;
    _birthDateController.text = date == null
        ? ''
        : '${date.day.toString().padLeft(2, '0')}/'
              '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'Fecha de nacimiento',
    );
    if (picked != null && mounted) {
      setState(() => _setBirthDate(picked));
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      showAppMessage(context, 'Revisa los campos marcados en rojo.');
      return;
    }
    setState(() => _saving = true);
    final authProvider = context.read<AuthProvider>();
    try {
      await authProvider.updateProfile(
        name: _nameController.text,
        birthDate: _birthDate?.toIso8601String().split('T').first,
        goal: _goal,
        level: _level,
      );
      if (!mounted) return;
      await ConfirmationDialog.showInfo(
        context,
        icon: Icons.check_circle_rounded,
        title: 'Perfil actualizado',
        message: 'Tus datos se guardaron correctamente.',
      );
      if (!mounted) return;
      context.pop();
    } catch (error) {
      if (!mounted) return;
      showAppMessage(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final email = authProvider.user?.email ?? '';
    final palette = context.palette;
    final name = _nameController.text.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: MaxWidth(
            maxWidth: Breakpoints.form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: palette.primarySoft,
                      child: Text(
                        name.isEmpty ? '?' : name[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: context.palette.primaryText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tu cuenta',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            email,
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
                const SizedBox(height: 24),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CustomTextField(
                        controller: _nameController,
                        label: 'Nombre completo',
                        icon: Icons.person_outline_rounded,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => Validators.validateRequired(
                          v,
                          message: 'Ingresa tu nombre.',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: _birthDateController,
                              label: 'Fecha de nacimiento (opcional)',
                              hint: 'Selecciona una fecha',
                              icon: Icons.cake_outlined,
                              readOnly: true,
                              onTap: _pickBirthDate,
                            ),
                          ),
                          if (_birthDate != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 8, top: 4),
                              child: IconButton(
                                tooltip: 'Borrar fecha',
                                onPressed: () =>
                                    setState(() => _setBirthDate(null)),
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      CustomDropdown(
                        items: _goalItems,
                        value: _goal ?? _noneLabel,
                        label: 'Objetivo principal',
                        icon: Icons.flag_outlined,
                        onChanged: (v) =>
                            setState(() => _goal = v == _noneLabel ? null : v),
                        validator: (_) => null,
                      ),
                      const SizedBox(height: 16),
                      CustomDropdown(
                        items: _levelItems,
                        value: _level ?? _noneLabel,
                        label: 'Nivel',
                        icon: Icons.trending_up_rounded,
                        onChanged: (v) =>
                            setState(() => _level = v == _noneLabel ? null : v),
                        validator: (_) => null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                CustomButton(
                  label: 'Guardar cambios',
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
